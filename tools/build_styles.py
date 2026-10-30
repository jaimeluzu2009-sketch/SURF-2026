# blender -b --factory-startup --python tools/build_styles.py -- assets/models
# Original procedural assets. Shares build_assets.py rig, weights and all clips, including surf tricks.
from pathlib import Path
ns={"__file__":str(Path(__file__).with_name("build_assets.py"))}
src=Path(ns["__file__"]).read_text(encoding="utf-8")
exec(compile(src.rsplit("\nmain()",1)[0],ns["__file__"],"exec"),ns)
globals().update({k:v for k,v in ns.items() if not k.startswith('__')})

def make_hair(kind, mat):
 parts=[]
 count=[28,9,18][kind]
 for i in range(count):
  a=i*2.399963
  z=0.18+0.78*(i+0.5)/count
  ring=math.sqrt(1-z*z)
  center=V(0.087*ring*math.cos(a),-0.012+0.108*ring*math.sin(a),1.685+0.119*z)
  bm=bmesh.new()
  bmesh.ops.create_uvsphere(bm,u_segments=7,v_segments=5,radius=1.0)
  scale=V(0.022,0.023,0.020) if kind==0 else (V(0.015,0.041,0.009) if kind==1 else V(0.022,0.038,0.014))
  for v in bm.verts:
   v.co=V(v.co.x*scale.x,v.co.y*scale.y,v.co.z*scale.z)+center
   if kind>0:
    v.co.y+=0.018*(v.co.z-center.z)/scale.z
  ob=obj_from_bmesh('HairClump',bm,mat)
  vg=ob.vertex_groups.new(name='head');vg.add(list(range(len(ob.data.vertices))),1.0,'REPLACE')
  parts.append(ob)
 return parts

def build_variant(kind, sid, outfit=None):
 summer=(kind!=1) if outfit is None else outfit==1
 clear_scene()
 bpy.context.scene.render.fps=FPS
 # Common names are used by SurfMaterials and the existing customization slots.
 mats={
  'wetsuit':make_mat('Neopreno',srgb(.08,.09,.11),.72),
  'skin':make_mat('Piel',srgb(.72,.50,.36),.55),
  'accent':make_mat('Franja',srgb(.95,.4,.3),.74),
  'pads':make_mat('Rodilleras',srgb(.12,.13,.15),.83),
  'hair':make_mat('Pelo',srgb(.09,.055,.035),.8),
  'eye':make_mat('Ojos',srgb(.045,.03,.025),.3),
  'cuff':make_mat('Leash',srgb(.05,.05,.05),.7),
  'deck':make_mat('Cubierta',srgb(.95,.94,.90),.3),
  'bottom':make_mat('Fondo',srgb(.3,.72,.76),.3),
  'stringer':make_mat('Larguero',srgb(.55,.38,.22),.5),
  'pad':make_mat('Grip',srgb(.1,.1,.11),.95),
  'fin':make_mat('Quillas',srgb(.08,.15,.17),.3),
  'plug':make_mat('Tapon',srgb(.3,.3,.3),.6),
 }
 arm=build_armature()
 body=build_body(mats)
 extras=[make_mat('Licra',srgb(.1,.6,.64),.8),make_mat('Bermuda',srgb(.05,.13,.22),.87),
  make_mat('Costura',srgb(.94,.77,.2) if kind==0 else srgb(.08,.35,.55),.8),
  make_mat('Grafica',srgb(.1,.61,.62),.8)]
 for m in extras: body.data.materials.append(m)
 # Full wetsuit uses coral shoulder panels; summer variants expose their legs.
 for face in body.data.polygons:
  c=face.center;ax=abs(c.x)
  if not summer:
   if face.material_index==2: face.material_index=0
   if 1.34<c.z<1.49 and .10<ax<.37: face.material_index=2
   elif .16<ax<.195 and .72<c.z<1.31: face.material_index=6
  else:
   if c.z<.62 or (kind==0 and ax>.40 and c.z<1.45): face.material_index=1
   elif .62<c.z<1.02 and ax<.28:
    face.material_index=5
    if kind==2 and .62<c.z<.69+(.02 if int(ax*65)%2 else 0): face.material_index=7
   elif face.material_index in [0,2,3]: face.material_index=4
 for v in body.data.vertices:
  if summer and .61999<v.co.z<1.02001 and abs(v.co.x)<.28:
   v.co.x*=1.04;v.co.y*=1.10
 skin_weights(body,arm)
 head=build_head(mats)
 parts=[body]+head+make_hair(kind,mats['hair'])+[build_cuff(mats)]
 if kind==0:
  # A small original golden chest badge, rather than ragged material bands.
  bm=bmesh.new()
  bmesh.ops.create_uvsphere(bm,u_segments=8,v_segments=4,radius=1)
  for v in bm.verts:
   v.co=V(-.065+v.co.x*.013,-.113+v.co.y*.003,1.36+v.co.z*.009)
  badge=obj_from_bmesh('ChestBadge',bm,extras[2])
  group=badge.vertex_groups.new(name='chest');group.add(list(range(len(badge.data.vertices))),1.0,'REPLACE')
  parts.append(badge)
 surfer=join(parts,'Surfer');surfer.parent=arm
 mod=surfer.modifiers.new('Armature','ARMATURE');mod.object=arm
 actions=build_actions(arm)
 board=build_board(mats)
 rail=make_mat('Cantos',srgb(.08,.63,.65) if kind==0 else (srgb(.94,.39,.29) if kind==1 else srgb(.91,.86,.73)),.28)
 nose=make_mat('Punta',srgb(.96,.43,.32) if kind==0 else (srgb(.94,.39,.29) if kind==1 else srgb(.75,.30,.17)),.3)
 board.data.materials.append(rail);ri=len(board.data.materials)-1
 board.data.materials.append(nose);ni=len(board.data.materials)-1
 for face in board.data.polygons:
  if face.material_index not in [0,1]: continue
  c=face.center;hw=board_half_width(board_t(c.y))
  if abs(c.x)>hw*.87: face.material_index=ri
  elif kind==0 and c.y<-.68: face.material_index=ni
  elif kind==2 and abs(c.x)<.009: face.material_index=ni
 os.makedirs(OUT_DIR,exist_ok=True)
 suffix='' if outfit is None else ('_beach' if summer else '_wetsuit')
 export_glb([arm,surfer],os.path.join(OUT_DIR,'surfer_'+sid+suffix+'.glb'),True)
 if outfit is None: export_glb([board],os.path.join(OUT_DIR,'board_'+sid+'.glb'),False)
 print('[styles]',sid,'triangles',sum(len(f.vertices)-2 for f in surfer.data.polygons),'bones',len(arm.data.bones))

for i,sid in enumerate(['local','pro','retro']):
 build_variant(i,sid,1 if i==1 else 0) if "--outfit-variants" in sys.argv else build_variant(i,sid)
