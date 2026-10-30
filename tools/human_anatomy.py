# BARRELS adapter for CC0 MakeHuman graphical data. Original integration code.
import math
from pathlib import Path
from collections import defaultdict
import bpy, bmesh
from mathutils import Vector as V

_cache = None
def anatomy():
 global _cache
 if _cache is not None: return _cache
 folder=Path(__file__).resolve().parents[1]/'assets/sources/makehuman'
 verts=[];faces=[];groups=defaultdict(set);group=''
 for line in (folder/'base.obj').read_text(encoding='utf-8').splitlines():
  if line.startswith('v '): verts.append(V(tuple(map(float,line.split()[1:4]))))
  elif line.startswith('g '): group=line[2:]
  elif line.startswith('f '):
   f=tuple(int(c.split('/')[0])-1 for c in line.split()[1:])
   groups[group].update(f)
   if group=='body': faces.append(f)
 for name,weight in [('african-male-young.target',1/3),('asian-male-young.target',1/3),('caucasian-male-young.target',1/3),('universal-male-young-averagemuscle-averageweight.target',.72),('universal-male-young-maxmuscle-averageweight.target',.28)]:
  for line in (folder/name).read_text(encoding='utf-8').splitlines():
   if not line or line.startswith('#'): continue
   row=line.split()
   if len(row)==4: verts[int(row[0])]+=V(tuple(map(float,row[1:])))*weight
 def joint(name): return sum((verts[i] for i in groups[name]),V())/len(groups[name])
 floor=min(verts[i].y for i in groups['body']);top=max(verts[i].y for i in groups['body'])
 scale=1.788/(top-floor)
 knots=sorted([(floor,.012),(joint('joint-l-ankle').y,.09),(joint('joint-l-knee').y,.50),(joint('joint-pelvis').y,.96),(joint('joint-l-shoulder').y,1.43),(joint('joint-neck').y,1.53),(joint('joint-l-eye').y,1.70),(top,1.80)])
 def height(y):
  for (a,za),(b,zb) in zip(knots,knots[1:]):
   if y<=b:return za+(zb-za)*(y-a)/(b-a)
  return knots[-1][1]+(y-top)*scale
 def base(p):return V((p.x*scale,-p.z*scale+.015,height(p.y)))
 joints={k:base(joint(k)) for k in groups if k.startswith('joint-')}
 def segment_distance(p,a,b):
  t=max(0,min(1,(p-a).dot(b-a)/max((b-a).length_squared,1e-8)))
  return (p-a-(b-a)*t).length
 def mapped(p,a,b,c,d):
  source=b-a;target=d-c
  axis=source.normalized()
  q=axis.rotation_difference(target.normalized())
  rel=p-a
  return c+q@(rel+axis*rel.dot(axis)*(target.length/source.length-1))
 def warp_segments(p,segments):
  weights=[1/(segment_distance(p,a,b)+.025)**4 for a,b,c,d in segments]
  return sum((mapped(p,*seg)*w for seg,w in zip(segments,weights)),V())/sum(weights)
 arms={};legs={}
 for side,sign in [('l',1),('r',-1)]:
  shoulder=joints['joint-'+side+'-shoulder'];elbow=joints['joint-'+side+'-elbow'];hand=joints['joint-'+side+'-hand'];finger=joints['joint-'+side+'-finger-3-4']
  arms[sign]=[(shoulder,elbow,V((.175*sign,.005,1.43)),V((.415*sign,.005,1.27))),
   (elbow,hand,V((.415*sign,.005,1.27)),V((.62*sign,0,1.14))),
   (hand,finger,V((.62*sign,0,1.14)),V((.78*sign,0,1.035)))]
  hip=joints['joint-'+side+'-upper-leg'];knee=joints['joint-'+side+'-knee'];ankle=joints['joint-'+side+'-ankle'];toe=joints['joint-'+side+'-toe-3-4']
  legs[sign]=[(hip,knee,V((.09*sign,.01,.92)),V((.10*sign,-.01,.50))),
   (knee,ankle,V((.10*sign,-.01,.50)),V((.10*sign,.02,.09))),
   (ankle,toe,V((.10*sign,.02,.09)),V((.11*sign,-.19,.025)))]
 def transform(raw):
  p=base(raw);sign=1 if p.x>=0 else -1
  if p.z<.94 and abs(p.x)>.025:
   mix=max(0,min(1,(.96-p.z)/.10))
   p=p.lerp(warp_segments(p,legs[sign]),mix)
   p.z=max(.009,p.z)
  elif p.z>.94 and abs(p.x)>.145:
   dist=min(segment_distance(p,a,b) for a,b,c,d in arms[sign])
   mix=max(0,min(1,(abs(p.x)-.145)/.065))*max(0,min(1,(.18-dist)/.065))
   if mix>0:p=p.lerp(warp_segments(p,arms[sign]),mix)
  return p
 mapped_verts=[transform(p) for p in verts]
 used=sorted(groups['body']);remap={j:i for i,j in enumerate(used)}
 points=[mapped_verts[i] for i in used];polygons=[tuple(remap[i] for i in f) for f in faces]
 _cache={'verts':points,'faces':polygons,'eyes':[transform(joint('joint-'+side+'-eye')) for side in ['l','r']]}
 print('[anatomy] CC0 body:',len(points),'vertices',len(polygons),'faces; eyes',_cache['eyes'])
 return _cache

def detailed_body(ns,mats):
 data=anatomy();me=bpy.data.meshes.new('AnatomicalBody')
 me.from_pydata(data['verts'],[],data['faces']);me.update()
 # Precise clothing boundaries; face and fingers keep their original anatomical loops.
 bm=bmesh.new();bm.from_mesh(me)
 for z in [.118,.62,.69,1.02,1.315,1.365,1.525]:
  bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=V((0,0,z)),plane_no=V((0,0,1)),clear_inner=False,clear_outer=False)
 for x in [-.612,-.40,.40,.612]:
  bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=V((x,0,0)),plane_no=V((1,0,0)),clear_inner=False,clear_outer=False)
 bm.to_mesh(me);bm.free();me.update()
 for key in ['wetsuit','skin','accent','pads']:me.materials.append(mats[key])
 for p in me.polygons:
  c=p.center;ax=abs(c.x)
  p.material_index=1 if c.z>1.525 or ax>.612 or c.z<.118 else (2 if ax<.2 and 1.315<c.z<1.365 else 0)
  p.use_smooth=True
 return ns['link'](bpy.data.objects.new('Body',me))

def ellipsoid(ns,name,center,scale,mat,segments=16,rings=10):
 bm=bmesh.new();bmesh.ops.create_uvsphere(bm,u_segments=segments,v_segments=rings,radius=1)
 for v in bm.verts:v.co=V((v.co.x*scale[0],v.co.y*scale[1],v.co.z*scale[2]))+center
 return ns['obj_from_bmesh'](name,bm,mat)

def strand(ns,name,points,radius,mat,sides=6):
 verts=[];faces=[]
 for i,p in enumerate(points):
  tangent=(points[min(i+1,len(points)-1)]-points[max(i-1,0)]).normalized()
  side=tangent.cross(V((0,0,1))).normalized()
  if side.length<.1:side=V((1,0,0))
  up=tangent.cross(side).normalized();r=radius*(1-.85*(i/(len(points)-1))**3)
  for j in range(sides):verts.append(p+(side*math.cos(j*math.tau/sides)+up*math.sin(j*math.tau/sides))*r)
 for i in range(len(points)-1):
  for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.materials.append(mat)
 ob=ns['link'](bpy.data.objects.new(name,me))
 for p in me.polygons:p.use_smooth=True
 return ob

def head_bind(parts):
 for p in parts:
  vg=p.vertex_groups.get('head') or p.vertex_groups.new(name='head');vg.add(list(range(len(p.data.vertices))),1,'REPLACE')
 return parts

def detailed_head(ns,mats):
 data=anatomy();points=data['verts'];faces=data['faces']
 hair_faces=[];scalp=[]
 def field(p):return p.z-(1.708+.023*max(-p.y,0)/.13-.075*max(p.y,0)/.10)
 for f in faces:
  polygon=[points[i] for i in f];out=[]
  for a,b in zip(polygon,polygon[1:]+polygon[:1]):
   fa,fb=field(a),field(b)
   if fa>=0:out.append(a.copy())
   if (fa>=0)!=(fb>=0):out.append(a.lerp(b,fa/(fa-fb)))
  if len(out)<3:continue
  index=len(scalp)
  scalp.extend(V((v.x*1.025,v.y*1.025,v.z+.004)) for v in out)
  hair_faces.append(tuple(range(index,index+len(out))))
 me=bpy.data.meshes.new('FittedHairCap');me.from_pydata(scalp,[],hair_faces);me.materials.append(mats['hair'])
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bm.to_mesh(me);bm.free()
 cap=ns['link'](bpy.data.objects.new('FittedHairCap',me))
 for p in me.polygons:p.use_smooth=True
 parts=[cap]
 sclera=ns['make_mat']('Esclerotica',ns['srgb'](.69,.70,.65),.35)
 iris=ns['make_mat']('Iris',ns['srgb'](.19,.10,.055),.4)
 for eye in data['eyes']:
  parts.append(ellipsoid(ns,'EyeWhite',eye,(.0115,.0105,.0107),sclera))
  parts.append(ellipsoid(ns,'Iris',eye+V((0,-.0101,0)),(.0055,.0014,.0055),iris,14,8))
  parts.append(ellipsoid(ns,'Pupil',eye+V((0,-.0114,0)),(.0027,.0005,.0027),mats['eye'],12,8))
  sign=1 if eye.x>0 else -1
  brow=[eye+V((sign*(-.014+.028*i/6),-.004, .017+.004*math.sin(math.pi*i/6))) for i in range(7)]
  parts.append(strand(ns,'Eyebrow',brow,.0022,mats['hair'],5))
 parts+=hair_strands(ns,1,mats['hair'])
 return head_bind(parts)

def hair_strands(ns,kind,mat):
 data=anatomy();scalp=[v for v in data['verts'] if v.z>1.72]
 def top(x,y):
  nearest=sorted(scalp,key=lambda p:(p.x-x)**2+(p.y-y)**2)[:8]
  weights=[1/max((p.x-x)**2+(p.y-y)**2,.00001) for p in nearest]
  return sum(p.z*w for p,w in zip(nearest,weights))/sum(weights)
 parts=[];count=[14,10,16][kind]
 for j in range(count):
  x=-.055+.11*j/(count-1);points=[]
  for i in range(9):
   t=i/8;y=-.055+.105*t
   xx=x+(.008 if kind!=1 else .014)*math.sin(math.pi*t)
   lift=[.002,.001,.004][kind]*math.sin(math.pi*t)
   points.append(V((xx,y,top(xx,y)+.007+lift)))
  parts.append(strand(ns,'WetHairStrand',points,[.0018,.0012,.0022][kind],mat,7))
 return head_bind(parts)

def detail_colors(ob):
 me=ob.data
 if ob.type!='MESH' or ob.name!='Surfer':return
 attr=me.color_attributes.new(name='DetailColor',type='BYTE_COLOR',domain='CORNER')
 me.color_attributes.active_color=attr
 for poly in me.polygons:
  role=me.materials[poly.material_index].name.split('.')[0]
  for li in poly.loop_indices:
   p=me.vertices[me.loops[li].vertex_index].co;col=V((1,1,1))
   if role=='Piel':
    # Low-amplitude anatomical tint; chosen skin tone remains the base material.
    if p.z>1.58:
     mouth=math.exp(-((p.x/.029)**2+((p.z-1.646)/.009)**2+((p.y+.12)/.05)**2))
     cheek=math.exp(-(((abs(p.x)-.047)/.023)**2+((p.z-1.671)/.026)**2))*max(0,min(1,-p.y*10))
     col=V((1-.12*mouth,1-.32*mouth-.045*cheek,1-.30*mouth-.06*cheek))
    # Nail beds read as flesh rather than painted white dots.
   elif role in ['Neopreno','Licra','Bermuda','Franja']:
    seam=0.0
    if .99<p.z<1.50 and p.y>0:seam=math.exp(-((abs(p.x)-.10)/.0028)**2)
    if abs(p.x)<.15:seam=max(seam,math.exp(-((p.z-1.515)/.003)**2))
    weave=.985+.015*math.sin(p.x*280+p.z*170)
    col=V((1,1,1))*(weave-.24*seam)
   elif role=='Pelo':col=V((1,1,1))*(.88+.12*math.sin(p.x*380+p.y*180)**2)
   attr.data[li].color=(*col,1)
