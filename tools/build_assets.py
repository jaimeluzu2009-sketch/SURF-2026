# Genera el surfista (malla + esqueleto + animaciones) y la tabla de BARRELS
# y los exporta a GLB para Godot.
#
# Uso (desde la carpeta del proyecto):
#   blender -b --factory-startup --python tools/build_assets.py -- assets/models [carpeta_previews]
#
# Ejes de Blender: Z arriba. El surfista se modela de pie mirando a -Y (su
# izquierda es +X). La tabla tiene la punta (nose) en -Y y la cubierta en Z = 0.
# Al exportar a glTF, -Y pasa a +Z, así que en Godot la punta queda en +Z local.

import bpy
import bmesh
import math
import os
import sys
from mathutils import Vector, Quaternion

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(argv[0] if argv else "assets/models")
PREVIEW_DIR = os.path.abspath(argv[1]) if len(argv) > 1 else ""
FPS = 30


# ---------------------------------------------------------------- utilidades

def srgb(r, g, b):
	def lin(c):
		return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
	return (lin(r), lin(g), lin(b))


def make_mat(name, rgb, rough=0.6, metal=0.0):
	m = bpy.data.materials.new(name)
	if m.node_tree is None:
		m.use_nodes = True
	nodes = m.node_tree.nodes
	bsdf = next((n for n in nodes if n.type == 'BSDF_PRINCIPLED'), None)
	if bsdf is None:
		bsdf = nodes.new('ShaderNodeBsdfPrincipled')
		out = next((n for n in nodes if n.type == 'OUTPUT_MATERIAL'), None) or nodes.new('ShaderNodeOutputMaterial')
		m.node_tree.links.new(bsdf.outputs[0], out.inputs[0])
	bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
	bsdf.inputs["Roughness"].default_value = rough
	bsdf.inputs["Metallic"].default_value = metal
	m.diffuse_color = (*rgb, 1.0)
	m.roughness = rough
	return m


def link(ob):
	bpy.context.scene.collection.objects.link(ob)
	return ob


def obj_from_bmesh(name, bm, mat=None):
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	if mat:
		me.materials.append(mat)
	for p in me.polygons:
		p.use_smooth = True
	return link(bpy.data.objects.new(name, me))


def qx(d):
	return Quaternion((1, 0, 0), math.radians(d))


def qy(d):
	return Quaternion((0, 1, 0), math.radians(d))


def qz(d):
	return Quaternion((0, 0, 1), math.radians(d))


def eul(x=0.0, y=0.0, z=0.0):
	# Rotación en ejes del cuerpo erguido: primero X (flexión), luego Y (inclinación lateral), luego Z (giro).
	return qz(z) @ qy(y) @ qx(x)


def V(x, y, z):
	return Vector((x, y, z))


def clear_scene():
	for ob in list(bpy.data.objects):
		bpy.data.objects.remove(ob, do_unlink=True)
	for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures, bpy.data.actions,
			bpy.data.cameras, bpy.data.lights):
		for block in list(coll):
			coll.remove(block)


# ---------------------------------------------------------------- tabla

BOARD_LEN = 1.83  # 6'0"
# Media anchura de la tabla según t (0 = punta, 1 = cola).
PLANFORM = [
	(0.00, 0.004), (0.03, 0.050), (0.08, 0.100), (0.15, 0.150), (0.25, 0.195),
	(0.35, 0.226), (0.48, 0.244), (0.60, 0.240), (0.72, 0.222), (0.82, 0.193),
	(0.90, 0.155), (0.95, 0.120), (1.00, 0.078),
]


def interp_table(table, t):
	if t <= table[0][0]:
		return table[0][1]
	for (t0, v0), (t1, v1) in zip(table, table[1:]):
		if t <= t1:
			k = (t - t0) / (t1 - t0)
			k = k * k * (3 - 2 * k)
			return v0 + (v1 - v0) * k
	return table[-1][1]


def board_half_width(t):
	return interp_table(PLANFORM, t)


def board_bottom(t):
	if t < 0.45:
		return 0.125 * (1 - t / 0.45) ** 2.2
	if t > 0.55:
		return 0.045 * ((t - 0.55) / 0.45) ** 2.0
	return 0.0


def board_thickness(t):
	return 0.062 * (0.32 + 0.68 * math.sin(math.pi * min(max(t, 0.0), 1.0)) ** 0.6)


def board_y(t):
	return -BOARD_LEN / 2 + t * BOARD_LEN


def board_t(y):
	return (y + BOARD_LEN / 2) / BOARD_LEN


_DECK_RAW_CENTER = board_bottom(0.5) + board_thickness(0.5)


def deck_top(y):
	# Altura de la cubierta en el eje central, con la tabla ya desplazada (cubierta central en Z = 0).
	t = board_t(y)
	return board_bottom(t) + board_thickness(t) - _DECK_RAW_CENTER


def board_section_point(t, a):
	# a recorre el contorno de la sección: 0 = canto derecho, pi/2 = cubierta, pi = canto izquierdo.
	hw = board_half_width(t)
	th = board_thickness(t)
	zb = board_bottom(t)
	c, s = math.cos(a), math.sin(a)
	x = hw * math.copysign(abs(c) ** (2 / 2.8), c)
	if s >= 0:
		z = zb + th * 0.42 + th * 0.58 * abs(s) ** (2 / 2.2)  # cubierta abombada
	else:
		z = zb + th * 0.42 - th * 0.42 * abs(s) ** (2 / 5.0)  # fondo casi plano
	return V(-x, board_y(t), z - _DECK_RAW_CENTER)


def build_board(mats):
	bm = bmesh.new()
	stations = [0.004 + 0.992 * (i / 33) ** 1.0 for i in range(34)]
	seg = 18
	rings = []
	for t in stations:
		ring = [bm.verts.new(board_section_point(t, 2 * math.pi * j / seg)) for j in range(seg)]
		rings.append(ring)
	for r0, r1 in zip(rings, rings[1:]):
		for j in range(seg):
			bm.faces.new((r0[j], r0[(j + 1) % seg], r1[(j + 1) % seg], r1[j]))
	nose = bm.verts.new(V(0, board_y(0.0) - 0.004, board_bottom(0.0) + 0.012 - _DECK_RAW_CENTER))
	for j in range(seg):
		bm.faces.new((rings[0][(j + 1) % seg], rings[0][j], nose))
	bm.faces.new(list(reversed(rings[-1])))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	for f in bm.faces:
		f.material_index = 0 if f.normal.z > -0.25 else 1
	board = obj_from_bmesh("Board", bm)
	board.data.materials.append(mats["deck"])
	board.data.materials.append(mats["bottom"])

	parts = [board]

	# Larguero (stringer): tira fina de madera sobre la cubierta.
	bm = bmesh.new()
	prev = None
	for i in range(40):
		t = 0.03 + 0.95 * i / 39
		y = board_y(t)
		z = deck_top(y) + 0.0015
		pair = (bm.verts.new(V(-0.0025, y, z)), bm.verts.new(V(0.0025, y, z)))
		if prev:
			bm.faces.new((prev[0], prev[1], pair[1], pair[0]))
		prev = pair
	parts.append(obj_from_bmesh("Stringer", bm, mats["stringer"]))

	# Grip (pad de cola) con kick.
	bm = bmesh.new()
	rows = []
	cols = 9
	for i in range(10):
		t = 0.80 + 0.17 * i / 9
		hw = board_half_width(t) * 0.86
		kick = 0.02 * max(0.0, (t - 0.94) / 0.03) ** 1.5
		row = []
		for j in range(cols):
			u = -1 + 2 * j / (cols - 1)
			a = math.pi / 2 - u * 1.15
			p = board_section_point(t, a)
			p.x = -u * hw
			p.z += 0.004 + kick
			row.append(bm.verts.new(p))
		rows.append(row)
	for r0, r1 in zip(rows, rows[1:]):
		for j in range(cols - 1):
			bm.faces.new((r0[j], r1[j], r1[j + 1], r0[j + 1]))
	bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.004)
	parts.append(obj_from_bmesh("TailPad", bm, mats["pad"]))

	# Quillas (thruster): dos laterales con cant y una central.
	def fin(t, x, cant, toe, scale):
		bm = bmesh.new()
		base_y = board_y(t)
		outline = [(0.0, 0.0), (0.105, 0.0), (0.098, -0.02), (0.085, -0.06), (0.075, -0.1), (0.07, -0.115),
			(0.05, -0.105), (0.03, -0.075), (0.012, -0.035)]
		front, back = [], []
		for (dy, dz) in outline:
			thick = 0.0045 * (1 - 0.7 * (-dz / 0.115))
			for side, lst in ((1, front), (-1, back)):
				p = V(side * thick, (dy - 0.06) * scale, dz * scale)
				lst.append(p)
		zb = board_bottom(t) - _DECK_RAW_CENTER + 0.002
		vf = [bm.verts.new(p) for p in front]
		vb = [bm.verts.new(p) for p in back]
		bm.faces.new(vf)
		bm.faces.new(list(reversed(vb)))
		n = len(vf)
		for j in range(n):
			bm.faces.new((vf[j], vb[j], vb[(j + 1) % n], vf[(j + 1) % n]))
		rot = (qz(toe) @ qy(cant)).to_matrix().to_4x4()
		bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
		bmesh.ops.translate(bm, vec=V(x, base_y, zb), verts=bm.verts)
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
		ob = obj_from_bmesh("Fin", bm, mats["fin"])
		for p in ob.data.polygons:
			p.use_smooth = False
		return ob

	parts.append(fin(0.835, -0.155, -6, 3, 1.0))
	parts.append(fin(0.835, 0.155, 6, -3, 1.0))
	parts.append(fin(0.95, 0.0, 0, 0, 0.92))

	# Tapón del leash en la cola.
	bm = bmesh.new()
	bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.012, radius2=0.012, depth=0.012)
	bmesh.ops.translate(bm, vec=V(0, board_y(0.975), deck_top(board_y(0.975)) + 0.004), verts=bm.verts)
	parts.append(obj_from_bmesh("LeashPlug", bm, mats["plug"]))

	return join(parts, "Board")


def add_uvs(ob):
	# Proyección automática y escala uniforme: 1 unidad de UV = 1 metro en todas las piezas,
	# para que las texturas de detalle tengan la misma densidad y no se estiren.
	bpy.ops.object.select_all(action='DESELECT')
	ob.select_set(True)
	bpy.context.view_layer.objects.active = ob
	bpy.ops.object.mode_set(mode='EDIT')
	bpy.ops.mesh.select_all(action='SELECT')
	bpy.ops.uv.smart_project(angle_limit=math.radians(60.0), island_margin=0.01, scale_to_bounds=False)
	bpy.ops.object.mode_set(mode='OBJECT')
	me = ob.data
	uv = me.uv_layers.active.data
	area3d = 0.0
	area_uv = 0.0
	for p in me.polygons:
		area3d += p.area
		pts = [uv[li].uv for li in p.loop_indices]
		a = 0.0
		for i in range(1, len(pts) - 1):
			e1 = pts[i] - pts[0]
			e2 = pts[i + 1] - pts[0]
			a += abs(e1.x * e2.y - e1.y * e2.x) * 0.5
		area_uv += a
	s = math.sqrt(area3d / max(area_uv, 1e-9))
	for d in uv:
		d.uv = d.uv * s


def join(parts, name):
	for p in parts:
		add_uvs(p)
	bpy.ops.object.select_all(action='DESELECT')
	for p in parts:
		p.select_set(True)
	bpy.context.view_layer.objects.active = parts[0]
	bpy.ops.object.join()
	ob = bpy.context.view_layer.objects.active
	ob.name = name
	ob.data.name = name
	return ob


# ---------------------------------------------------------------- esqueleto

# (cabeza, cola, padre, conectado)
BONES = [
	("hips", V(0, 0.01, 0.96), V(0, 0.0, 1.10), None, False),
	("spine", V(0, 0.0, 1.10), V(0, -0.005, 1.28), "hips", True),
	("chest", V(0, -0.005, 1.28), V(0, 0.0, 1.50), "spine", True),
	("neck", V(0, 0.0, 1.50), V(0, -0.005, 1.60), "chest", True),
	("head", V(0, -0.005, 1.60), V(0, -0.01, 1.80), "neck", True),
]
for side, sx in (("L", 1), ("R", -1)):
	BONES += [
		(f"shoulder_{side}", V(0.03 * sx, 0.0, 1.45), V(0.175 * sx, 0.005, 1.43), "chest", False),
		(f"upper_arm_{side}", V(0.175 * sx, 0.005, 1.43), V(0.415 * sx, 0.005, 1.27), f"shoulder_{side}", True),
		(f"forearm_{side}", V(0.415 * sx, 0.005, 1.27), V(0.62 * sx, 0.0, 1.14), f"upper_arm_{side}", True),
		(f"hand_{side}", V(0.62 * sx, 0.0, 1.14), V(0.78 * sx, 0.0, 1.035), f"forearm_{side}", True),
		(f"thigh_{side}", V(0.09 * sx, 0.01, 0.92), V(0.10 * sx, -0.01, 0.50), "hips", False),
		(f"shin_{side}", V(0.10 * sx, -0.01, 0.50), V(0.10 * sx, 0.02, 0.09), f"thigh_{side}", True),
		(f"foot_{side}", V(0.10 * sx, 0.02, 0.09), V(0.11 * sx, -0.19, 0.025), f"shin_{side}", True),
	]
LOWER = {}
for side in ("L", "R"):
	LOWER[f"thigh_{side}"] = f"shin_{side}"
	LOWER[f"upper_arm_{side}"] = f"forearm_{side}"


def build_armature():
	arm_data = bpy.data.armatures.new("SurferRig")
	arm = link(bpy.data.objects.new("SurferRig", arm_data))
	bpy.ops.object.select_all(action='DESELECT')
	arm.select_set(True)
	bpy.context.view_layer.objects.active = arm
	bpy.ops.object.mode_set(mode='EDIT')
	for name, head, tail, parent, connected in BONES:
		eb = arm_data.edit_bones.new(name)
		eb.head = head
		eb.tail = tail
		eb.roll = 0.0
		if parent:
			eb.parent = arm_data.edit_bones[parent]
			eb.use_connect = connected
	bpy.ops.object.mode_set(mode='OBJECT')
	return arm


# ---------------------------------------------------------------- cuerpo

JOINTS = {
	"pelvis": ((0, 0.012, 0.96), (0.150, 0.108)),
	"waist": ((0, 0.0, 1.10), (0.128, 0.094)),
	"chest": ((0, -0.006, 1.27), (0.158, 0.112)),
	"upper": ((0, 0.004, 1.41), (0.148, 0.098)),
	"neck": ((0, 0.008, 1.53), (0.054, 0.058)),
	"headbase": ((0, 0.0, 1.60), (0.056, 0.058)),
}
SKIN_EDGES = [("pelvis", "waist"), ("waist", "chest"), ("chest", "upper"), ("upper", "neck"), ("neck", "headbase")]
for side, sx in (("L", 1), ("R", -1)):
	def j(name, p, r):
		JOINTS[f"{name}_{side}"] = ((p[0] * sx, p[1], p[2]), r)
	j("shoulder", (0.178, 0.006, 1.43), (0.058, 0.060))
	j("arm", (0.30, 0.006, 1.348), (0.048, 0.050))
	j("elbow", (0.415, 0.006, 1.27), (0.040, 0.041))
	j("forearm", (0.52, 0.002, 1.205), (0.042, 0.038))
	j("wrist", (0.62, 0.0, 1.14), (0.030, 0.022))
	j("palm", (0.695, 0.0, 1.09), (0.042, 0.017))
	j("fingers", (0.775, 0.0, 1.038), (0.036, 0.013))
	j("thumb", (0.665, -0.032, 1.10), (0.014, 0.014))
	j("hip", (0.092, 0.012, 0.91), (0.084, 0.090))
	j("thigh", (0.100, 0.002, 0.72), (0.072, 0.076))
	j("knee", (0.100, -0.010, 0.50), (0.050, 0.054))
	j("calf", (0.100, 0.016, 0.34), (0.054, 0.058))
	j("ankle", (0.100, 0.022, 0.10), (0.033, 0.036))
	j("ball", (0.106, -0.115, 0.032), (0.043, 0.020))
	j("toe", (0.110, -0.185, 0.026), (0.036, 0.016))
	SKIN_EDGES.extend([
		("upper", f"shoulder_{side}"), (f"shoulder_{side}", f"arm_{side}"), (f"arm_{side}", f"elbow_{side}"),
		(f"elbow_{side}", f"forearm_{side}"), (f"forearm_{side}", f"wrist_{side}"), (f"wrist_{side}", f"palm_{side}"),
		(f"palm_{side}", f"fingers_{side}"), (f"wrist_{side}", f"thumb_{side}"),
		("pelvis", f"hip_{side}"), (f"hip_{side}", f"thigh_{side}"), (f"thigh_{side}", f"knee_{side}"),
		(f"knee_{side}", f"calf_{side}"), (f"calf_{side}", f"ankle_{side}"), (f"ankle_{side}", f"ball_{side}"),
		(f"ball_{side}", f"toe_{side}"),
	])


def build_body(mats):
	names = list(JOINTS)
	idx = {n: i for i, n in enumerate(names)}
	me = bpy.data.meshes.new("BodySkin")
	me.from_pydata([JOINTS[n][0] for n in names], [(idx[a], idx[b]) for a, b in SKIN_EDGES], [])
	ob = link(bpy.data.objects.new("BodySkin", me))
	skin = ob.modifiers.new("Skin", 'SKIN')
	skin.use_smooth_shade = True
	layer = me.skin_vertices[0]
	for n, i in idx.items():
		layer.data[i].radius = JOINTS[n][1]
	layer.data[idx["pelvis"]].use_root = True
	sub = ob.modifiers.new("Sub", 'SUBSURF')
	sub.levels = 1
	sub.render_levels = 1
	dg = bpy.context.evaluated_depsgraph_get()
	me2 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
	bpy.data.objects.remove(ob, do_unlink=True)
	body = link(bpy.data.objects.new("Body", me2))
	for key in ("wetsuit", "skin", "accent", "pads"):
		me2.materials.append(mats[key])
	for p in me2.polygons:
		c = p.center
		ax = abs(c.x)
		if c.z > 1.525 or ax > 0.612 or c.z < 0.118:
			p.material_index = 1
		elif ax < 0.2 and 1.315 < c.z < 1.365:
			p.material_index = 2
		elif 0.05 < ax < 0.16 and 0.455 < c.z < 0.545 and c.y < 0.0:
			p.material_index = 3
		else:
			p.material_index = 0
		p.use_smooth = True
	return body


def build_head(mats):
	center = V(0, -0.012, 1.685)
	scale = V(0.080, 0.100, 0.116)

	def shape(v):
		v = v.copy()
		if v.z < 0:
			v.x *= 1 + 0.22 * v.z
		if v.y < 0:
			nose = 0.16 * math.exp(-((v.x / 0.16) ** 2 + ((v.z + 0.02) / 0.22) ** 2))
			v.y -= nose * (-v.y)
			if v.z < -0.35:
				v.y -= 0.05 * (-v.y)
		for sx in (1, -1):
			d = (v - V(0.36 * sx, -0.88, 0.14)).length_squared
			v *= 1 - 0.05 * math.exp(-d / 0.02)
		return v

	def sphere(radius, keep=None):
		bm = bmesh.new()
		bmesh.ops.create_uvsphere(bm, u_segments=22, v_segments=14, radius=radius)
		for v in bm.verts:
			v.co = shape(v.co)
		if keep:
			bmesh.ops.delete(bm, geom=[v for v in bm.verts if not keep(v.co / radius)], context='VERTS')
		for v in bm.verts:
			v.co = center + V(v.co.x * scale.x, v.co.y * scale.y, v.co.z * scale.z)
		return bm

	head = obj_from_bmesh("Head", sphere(1.0), mats["skin"])

	def hair_keep(u):
		zt = 0.05 - 0.5 * max(0.0, u.y) + 0.32 * max(0.0, -u.y)
		return u.z > zt
	hair = obj_from_bmesh("Hair", sphere(1.07, hair_keep), mats["hair"])

	parts = [head, hair]
	for sx in (1, -1):
		bm = bmesh.new()
		bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=0.011)
		u = V(0.37 * sx, -0.86, 0.13).normalized() * 0.93
		bmesh.ops.translate(bm, vec=center + V(u.x * scale.x, u.y * scale.y, u.z * scale.z), verts=bm.verts)
		parts.append(obj_from_bmesh("Eye", bm, mats["eye"]))
		bm = bmesh.new()
		bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=1.0)
		bmesh.ops.scale(bm, vec=V(0.012, 0.022, 0.031), verts=bm.verts)
		bmesh.ops.translate(bm, vec=V(0.079 * sx, 0.002, 1.68), verts=bm.verts)
		parts.append(obj_from_bmesh("Ear", bm, mats["skin"]))
	for p in parts:
		vg = p.vertex_groups.new(name="head")
		vg.add(list(range(len(p.data.vertices))), 1.0, 'REPLACE')
	return parts


def build_cuff(mats):
	bm = bmesh.new()
	bmesh.ops.create_cone(bm, cap_ends=False, segments=12, radius1=0.046, radius2=0.044, depth=0.04)
	bmesh.ops.translate(bm, vec=V(-0.10, 0.02, 0.135), verts=bm.verts)
	ob = obj_from_bmesh("LeashCuff", bm, mats["cuff"])
	vg = ob.vertex_groups.new(name="shin_R")
	vg.add(list(range(len(ob.data.vertices))), 1.0, 'REPLACE')
	return ob


def seg_dist(p, a, b):
	ab = b - a
	t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
	return (p - (a + ab * t)).length


def skin_weights(body, arm):
	bones = [(b.name, b.head_local.copy(), b.tail_local.copy()) for b in arm.data.bones]
	groups = {name: body.vertex_groups.new(name=name) for name, _, _ in bones}
	for v in body.data.vertices:
		p = v.co
		cands = []
		for name, a, b in bones:
			if name.endswith("_R") and p.x > 0.03:
				continue
			if name.endswith("_L") and p.x < -0.03:
				continue
			if name in ("neck", "head") and p.z < 1.44:
				continue
			if name.startswith("shoulder") and p.z < 1.25:
				continue
			cands.append((seg_dist(p, a, b), name))
		cands.sort()
		best = cands[:3]
		ws = [(1.0 / (d * d + 2e-4) ** 2, n) for d, n in best]
		total = sum(w for w, _ in ws)
		for w, n in ws:
			w /= total
			if w > 0.02:
				groups[n].add([v.index], w, 'REPLACE')


# ---------------------------------------------------------------- poses

def solve_pose(arm, spec):
	# spec: root_q (Quaternion), root_p (Vector, posición de la cabeza de 'hips'),
	# bones: {nombre: ('e', Quaternion) | ('d', dir en marco del cuerpo) | ('w', dir en marco de la tabla)
	#                 | ('ik', objetivo, polo)}
	bones = arm.data.bones
	D, P, out, pending = {}, {}, {}, {}
	root_q = spec["root_q"]
	for b in bones:
		name = b.name
		rest_q = b.matrix_local.to_quaternion()
		rest_dir = (b.tail_local - b.head_local).normalized()
		if b.parent is None:
			Dp = Quaternion()
			P[name] = spec["root_p"]
			D[name] = root_q
		else:
			pn = b.parent.name
			Dp = D[pn]
			P[name] = P[pn] + Dp @ (b.head_local - b.parent.head_local)
			s = pending.pop(name) if name in pending else spec["bones"].get(name, ("e", Quaternion()))
			if s[0] == "e":
				D[name] = Dp @ s[1]
			else:
				if s[0] == "ik":
					target, pole = s[1], s[2]
					child = LOWER[name]
					l1, l2 = b.length, bones[child].length
					knee = ik_two_bone(P[name], target, l1, l2, pole)
					tdir = (knee - P[name]).normalized()
					pending[child] = ("w", (target - knee).normalized())
				elif s[0] == "d":
					tdir = root_q @ s[1].normalized()
				else:
					tdir = s[1].normalized()
				D[name] = (Dp @ rest_dir).rotation_difference(tdir) @ Dp
		L = Dp.inverted() @ D[name]
		out[name] = rest_q.inverted() @ L @ rest_q
	root = bones[0]
	loc = root.matrix_local.to_quaternion().inverted() @ (spec["root_p"] - root.head_local)
	return out, loc


def ik_two_bone(start, target, l1, l2, pole):
	d_vec = target - start
	d = min(max(d_vec.length, 1e-4), (l1 + l2) * 0.999)
	u = d_vec.normalized()
	cos_a = max(-1.0, min(1.0, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)))
	sin_a = math.sqrt(max(0.0, 1 - cos_a * cos_a))
	pp = pole - u * pole.dot(u)
	pp.normalize()
	return start + u * (l1 * cos_a) + pp * (l1 * sin_a)


def mirror(spec_l):
	# Copia los huesos _L a _R reflejando el plano X.
	out = dict(spec_l)
	for name, s in spec_l.items():
		if not name.endswith("_L"):
			continue
		r = name[:-2] + "_R"
		if r in out:
			continue
		if s[0] == "e":
			q = s[1]
			out[r] = ("e", Quaternion((q.w, q.x, -q.y, -q.z)))
		elif s[0] in ("d", "w"):
			out[r] = (s[0], V(-s[1].x, s[1].y, s[1].z))
		else:
			out[r] = ("ik", V(-s[1].x, s[1].y, s[1].z), V(-s[2].x, s[2].y, s[2].z))
	return out


def foot_dir(hx, hy):
	h = V(hx, hy, 0).normalized() * 0.955
	return V(h.x, h.y, -0.296)


# Posición de los tobillos sobre la cubierta en postura regular (pie izquierdo delante, hacia la punta).
FRONT_Y, BACK_Y = -0.285, 0.300
ANKLE_H = 0.083


def stance(hips=V(0.06, 0.01, 0.80), lean=18.0, roll=0.0, twist=0.0, arms=None, spine=None, fy=FRONT_Y, by=BACK_Y,
		fx=0.035, bx=0.05, head_yaw=25.0):
	root_q = qz(-90) @ qy(roll) @ qx(lean)
	b = {
		"spine": ("e", eul(8, 0, 12 + twist)),
		"chest": ("e", eul(6, 0, 10 + twist)),
		"neck": ("e", eul(-6, 0, 20)),
		"head": ("e", eul(-8 - lean * 0.4, 0, head_yaw)),
		"thigh_L": ("ik", V(fx, fy, deck_top(fy) + ANKLE_H), V(-1, -0.6, 0.2)),
		"foot_L": ("w", foot_dir(-0.85, -0.5)),
		"thigh_R": ("ik", V(bx, by, deck_top(by) + ANKLE_H), V(-1, -0.9, 0.1)),
		"foot_R": ("w", foot_dir(-0.97, 0.2)),
		"upper_arm_L": ("w", V(-0.30, -0.82, -0.48)),
		"forearm_L": ("w", V(-0.42, -0.74, -0.52)),
		"hand_L": ("w", V(-0.40, -0.70, -0.60)),
		"upper_arm_R": ("w", V(-0.22, 0.74, -0.62)),
		"forearm_R": ("w", V(-0.34, 0.62, -0.70)),
		"hand_R": ("w", V(-0.30, 0.55, -0.78)),
	}
	if spine:
		b.update(spine)
	if arms:
		b.update(arms)
	return {"root_q": root_q, "root_p": hips, "bones": b}


PRONE_HIPS = V(0.0, 0.16, 0.125)


def prone(breath=0.0, arms=None, chest_roll=0.0, head_up=0.0):
	b = {
		"spine": ("e", eul(-6 - breath, 0, 0)),
		"chest": ("e", eul(-14 - breath, chest_roll, 0)),
		"neck": ("e", eul(-34 - head_up, 0, 0)),
		"head": ("e", eul(-22 - head_up, 0, 0)),
		"thigh_L": ("d", V(0.05, 0.04, -1.0)),
		"shin_L": ("d", V(0.03, 0.22, -0.97)),
		"foot_L": ("d", V(0.02, 0.32, -0.95)),
		"upper_arm_L": ("ik", V(0.265, 0.05, 0.03), V(1.0, 0.2, 1.0)),
		"hand_L": ("w", V(0.1, -0.2, -0.97)),
	}
	if arms:
		b.update(arms)
	return {"root_q": qx(90), "root_p": PRONE_HIPS, "bones": mirror(b)}


def paddle_arm(phase):
	# Dirección del brazo (marco del cuerpo tumbado: +Z hacia la punta, -Y hacia el agua, +X hacia fuera).
	keys = [
		(0.00, V(0.34, -0.22, 0.91), V(0.30, -0.30, 0.90), V(0.25, -0.45, 0.85)),   # entrada delante
		(0.25, V(0.40, -0.88, 0.25), V(0.26, -0.96, -0.05), V(0.2, -0.95, -0.25)),  # tracción bajo el agua
		(0.50, V(0.42, -0.35, -0.84), V(0.30, -0.20, -0.93), V(0.25, 0.1, -0.96)),  # salida junto a la cadera
		(0.75, V(0.62, 0.62, 0.30), V(0.40, -0.10, 0.91), V(0.3, -0.4, 0.86)),      # recobro por el aire
		(1.00, V(0.34, -0.22, 0.91), V(0.30, -0.30, 0.90), V(0.25, -0.45, 0.85)),
	]
	phase %= 1.0
	for (p0, u0, f0, h0), (p1, u1, f1, h1) in zip(keys, keys[1:]):
		if phase <= p1:
			k = (phase - p0) / (p1 - p0)
			return (u0.lerp(u1, k), f0.lerp(f1, k), h0.lerp(h1, k))
	return keys[0][1:]


def paddle(phase):
	ul, fl, hl = paddle_arm(phase)
	ur, fr, hr = paddle_arm(phase + 0.5)
	arms = {
		"upper_arm_L": ("d", ul), "forearm_L": ("d", fl), "hand_L": ("d", hl),
		"upper_arm_R": ("d", V(-ur.x, ur.y, ur.z)), "forearm_R": ("d", V(-fr.x, fr.y, fr.z)),
		"hand_R": ("d", V(-hr.x, hr.y, hr.z)),
	}
	roll = 6 * math.sin(phase * 2 * math.pi)
	spec = prone(arms=arms, chest_roll=roll, head_up=4)
	spec["bones"].update(arms)
	return spec


def lerp_spec_root(spec, q, p):
	spec["root_q"] = q
	spec["root_p"] = p
	return spec


def build_actions(arm):
	actions = {}

	def make(name, keys, loop):
		act = bpy.data.actions.new(name)
		act.use_fake_user = True
		arm.animation_data_create()
		arm.animation_data.action = act
		prev = {}
		for frame, spec in keys:
			rots, loc = solve_pose(arm, spec)
			for pb in arm.pose.bones:
				q = rots[pb.name].normalized()
				if pb.name in prev and prev[pb.name].dot(q) < 0:
					q.negate()
				prev[pb.name] = q
				pb.rotation_mode = 'QUATERNION'
				pb.rotation_quaternion = q
				pb.keyframe_insert("rotation_quaternion", frame=frame, group=pb.name)
				pb.location = loc if pb.parent is None else V(0, 0, 0)
				pb.keyframe_insert("location", frame=frame, group=pb.name)
		act.frame_range = (keys[0][0], keys[-1][0])
		actions[name] = (act, loop)

	make("prone_idle", [(0, prone()), (30, prone(breath=3, head_up=-3)), (60, prone())], True)
	make("paddle", [(round(30 * i / 8), paddle(i / 8)) for i in range(9)], True)

	ride0 = stance()
	ride1 = stance(hips=V(0.06, 0.01, 0.785), arms={
		"upper_arm_L": ("w", V(-0.32, -0.80, -0.50)), "upper_arm_R": ("w", V(-0.24, 0.72, -0.64))})
	make("ride", [(0, ride0), (30, ride1), (60, stance())], True)

	carve_r = stance(hips=V(-0.02, 0.0, 0.70), lean=36, twist=6, head_yaw=30, arms={
		"upper_arm_L": ("w", V(-0.62, -0.62, -0.48)), "forearm_L": ("w", V(-0.60, -0.55, -0.58)),
		"hand_L": ("w", V(-0.5, -0.5, -0.7)),
		"upper_arm_R": ("w", V(-0.55, 0.42, -0.72)), "forearm_R": ("w", V(-0.55, 0.25, -0.80)),
		"hand_R": ("w", V(-0.5, 0.2, -0.84))})
	carve_l = stance(hips=V(0.15, 0.02, 0.68), lean=-10, twist=-12, head_yaw=20, arms={
		"upper_arm_L": ("w", V(-0.55, -0.72, -0.30)), "forearm_L": ("w", V(-0.70, -0.60, -0.30)),
		"hand_L": ("w", V(-0.70, -0.55, -0.45)),
		"upper_arm_R": ("w", V(-0.75, 0.05, -0.62)), "forearm_R": ("w", V(-0.85, -0.25, -0.45)),
		"hand_R": ("w", V(-0.8, -0.3, -0.5))})
	lean_f = stance(hips=V(0.05, -0.08, 0.76), roll=8, lean=24)
	lean_b = stance(hips=V(0.07, 0.09, 0.79), roll=-8, lean=10)
	for name, spec in (("carve_right", carve_r), ("carve_left", carve_l), ("lean_fwd", lean_f), ("lean_back", lean_b)):
		make(name, [(0, spec), (30, spec)], True)

	# Ponerse de pie (pop-up): empuje, cobra, piernas debajo, postura.
	push = prone(arms={"upper_arm_L": ("ik", V(0.20, -0.20, 0.03), V(0.6, 0.6, 1.0)),
		"hand_L": ("w", V(0.05, -0.3, -0.95))})
	cobra = prone(arms={"upper_arm_L": ("ik", V(0.21, -0.22, 0.03), V(0.4, 0.9, 0.4)),
		"hand_L": ("w", V(0.05, -0.3, -0.95))})
	cobra["root_q"] = qx(52)
	cobra["root_p"] = V(0.0, 0.14, 0.24)
	cobra["bones"]["thigh_L"] = ("d", V(0.05, 0.30, -0.95))
	cobra["bones"]["thigh_R"] = ("d", V(-0.05, 0.30, -0.95))
	cobra["bones"]["shin_L"] = ("d", V(0.03, 0.45, -0.89))
	cobra["bones"]["shin_R"] = ("d", V(-0.03, 0.45, -0.89))
	crouch = stance(hips=V(0.02, 0.03, 0.52), lean=55, twist=-10, arms={
		"upper_arm_L": ("w", V(-0.35, -0.45, -0.82)), "forearm_L": ("w", V(-0.2, -0.5, -0.84)),
		"hand_L": ("w", V(-0.1, -0.5, -0.86)),
		"upper_arm_R": ("w", V(-0.35, 0.05, -0.93)), "forearm_R": ("w", V(-0.3, -0.2, -0.93)),
		"hand_R": ("w", V(-0.2, -0.3, -0.93))})
	make("popup", [(0, push), (6, cobra), (13, crouch), (21, stance())], False)

	# Caída al agua por el lado de los talones.
	f1 = stance(hips=V(0.14, 0.0, 0.76), lean=-24, arms={
		"upper_arm_L": ("d", V(0.7, 0.0, 0.7)), "forearm_L": ("d", V(0.5, -0.3, 0.8)),
		"upper_arm_R": ("d", V(-0.7, 0.0, 0.7)), "forearm_R": ("d", V(-0.5, -0.3, 0.8))})
	f2 = stance(hips=V(0.55, 0.0, 0.18), lean=-72, arms={
		"upper_arm_L": ("d", V(0.9, 0.1, 0.4)), "forearm_L": ("d", V(0.7, -0.4, 0.6)),
		"upper_arm_R": ("d", V(-0.9, 0.1, 0.4)), "forearm_R": ("d", V(-0.7, -0.4, 0.6))})
	f2["bones"]["thigh_L"] = ("d", V(0.12, -0.75, -0.65))
	f2["bones"]["thigh_R"] = ("d", V(-0.12, -0.55, -0.83))
	f2["bones"]["shin_L"] = ("d", V(0.08, -0.25, -0.96))
	f2["bones"]["shin_R"] = ("d", V(-0.08, 0.1, -0.99))
	f2["bones"]["foot_L"] = ("d", V(0.0, -0.9, -0.4))
	f2["bones"]["foot_R"] = ("d", V(0.0, -0.9, -0.4))
	f3 = stance(hips=V(0.95, 0.10, -0.32), lean=-96, arms={
		"upper_arm_L": ("d", V(0.92, 0.1, 0.3)), "forearm_L": ("d", V(0.8, -0.2, 0.55)),
		"upper_arm_R": ("d", V(-0.92, 0.1, 0.3)), "forearm_R": ("d", V(-0.8, -0.2, 0.55))})
	for k in ("thigh_L", "thigh_R"):
		sx = 1 if k.endswith("L") else -1
		f3["bones"][k] = ("d", V(0.16 * sx, -0.30, -0.94))
		f3["bones"]["shin" + k[5:]] = ("d", V(0.1 * sx, 0.05, -0.99))
		f3["bones"]["foot" + k[5:]] = ("d", V(0.0, -0.95, -0.3))
	f3["bones"]["head"] = ("e", eul(18, 0, 0))
	make("fall", [(0, stance()), (7, f1), (18, f2), (36, f3)], False)

	arm.animation_data.action = actions["ride"][0]
	return actions


# ---------------------------------------------------------------- export y previews

def export_glb(objs, path, animations):
	bpy.ops.object.select_all(action='DESELECT')
	for o in objs:
		o.select_set(True)
	bpy.context.view_layer.objects.active = objs[0]
	kwargs = dict(filepath=path, export_format='GLB', use_selection=True, export_apply=False,
		export_animations=animations, export_yup=True)
	if animations:
		kwargs.update(export_animation_mode='ACTIONS', export_force_sampling=True, export_frame_step=1,
			export_optimize_animation_size=True)
	bpy.ops.export_scene.gltf(**kwargs)


def render_previews(arm, actions, out_dir):
	os.makedirs(out_dir, exist_ok=True)
	scene = bpy.context.scene
	scene.render.engine = 'BLENDER_WORKBENCH'
	scene.display.shading.light = 'STUDIO'
	scene.display.shading.color_type = 'MATERIAL'
	scene.display.shading.show_shadows = False
	scene.render.resolution_x = 640
	scene.render.resolution_y = 480
	scene.render.film_transparent = False
	cam_data = bpy.data.cameras.new("Cam")
	cam_data.lens = 45
	cam = link(bpy.data.objects.new("Cam", cam_data))
	scene.camera = cam
	views = {
		"front": (V(-3.2, -1.4, 1.4), V(0, -0.05, 0.6)),
		"side": (V(-0.2, -3.6, 1.0), V(0, 0, 0.55)),
	}
	shots = [("prone_idle", 0), ("paddle", 0), ("paddle", 8), ("popup", 6), ("popup", 13), ("ride", 0),
		("carve_right", 0), ("carve_left", 0), ("lean_fwd", 0), ("fall", 18), ("fall", 36)]
	for act_name, frame in shots:
		arm.animation_data.action = actions[act_name][0]
		scene.frame_set(frame)
		for vname, (pos, target) in views.items():
			cam.location = pos
			cam.rotation_euler = (target - pos).to_track_quat('-Z', 'Y').to_euler()
			scene.render.filepath = os.path.join(out_dir, f"{act_name}_{frame:02d}_{vname}.png")
			bpy.ops.render.render(write_still=True)
	# Vista de reposo (A-pose) para revisar la malla.
	arm.animation_data.action = None
	for pb in arm.pose.bones:
		pb.rotation_quaternion = Quaternion()
		pb.location = V(0, 0, 0)
	for vname, pos in (("rest_front", V(0.6, -3.4, 1.1)), ("rest_back", V(-0.4, 3.4, 1.2))):
		cam.location = pos
		cam.rotation_euler = (V(0, 0, 0.95) - pos).to_track_quat('-Z', 'Y').to_euler()
		scene.render.filepath = os.path.join(out_dir, f"{vname}.png")
		bpy.ops.render.render(write_still=True)


def main():
	clear_scene()
	bpy.context.scene.render.fps = FPS
	mats = {
		"wetsuit": make_mat("Neopreno", srgb(0.09, 0.095, 0.105), 0.55),
		"skin": make_mat("Piel", srgb(0.72, 0.50, 0.36), 0.62),
		"accent": make_mat("Franja", srgb(0.98, 0.80, 0.10), 0.5),
		"pads": make_mat("Rodilleras", srgb(0.22, 0.23, 0.25), 0.7),
		"hair": make_mat("Pelo", srgb(0.10, 0.07, 0.05), 0.75),
		"eye": make_mat("Ojos", srgb(0.04, 0.03, 0.03), 0.25),
		"cuff": make_mat("Leash", srgb(0.05, 0.05, 0.06), 0.6),
		"deck": make_mat("Cubierta", srgb(0.95, 0.94, 0.90), 0.35),
		"bottom": make_mat("Fondo", srgb(0.30, 0.72, 0.76), 0.3),
		"stringer": make_mat("Larguero", srgb(0.55, 0.38, 0.22), 0.5),
		"pad": make_mat("Grip", srgb(0.10, 0.10, 0.11), 0.95),
		"fin": make_mat("Quillas", srgb(0.14, 0.15, 0.17), 0.35),
		"plug": make_mat("Tapon", srgb(0.35, 0.36, 0.38), 0.5),
	}
	arm = build_armature()
	body = build_body(mats)
	skin_weights(body, arm)
	parts = [body] + build_head(mats) + [build_cuff(mats)]
	surfer = join(parts, "Surfer")
	surfer.parent = arm
	mod = surfer.modifiers.new("Armature", 'ARMATURE')
	mod.object = arm
	actions = build_actions(arm)
	board = build_board(mats)

	os.makedirs(OUT_DIR, exist_ok=True)
	tris = sum(len(p.vertices) - 2 for p in surfer.data.polygons)
	btris = sum(len(p.vertices) - 2 for p in board.data.polygons)
	print(f"[barrels] surfista: {len(surfer.data.vertices)} vertices, {tris} triangulos, {len(arm.data.bones)} huesos")
	print(f"[barrels] tabla: {len(board.data.vertices)} vertices, {btris} triangulos")
	print(f"[barrels] animaciones: {', '.join(actions)}")
	export_glb([arm, surfer], os.path.join(OUT_DIR, "surfer.glb"), True)
	export_glb([board], os.path.join(OUT_DIR, "board.glb"), False)
	if PREVIEW_DIR:
		render_previews(arm, actions, PREVIEW_DIR)
	print("[barrels] listo")


main()
