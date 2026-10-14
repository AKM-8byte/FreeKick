"""Create three original articulated, skinned characters in the installed Blender.

The rest pose matches Godot's analytical IK. No animation clips are exported.
Existing authoring files and football_parts.glb remain untouched.
"""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector, Matrix

OUT = Path(__file__).resolve().parents[1] / 'assets/models'
bpy.ops.wm.open_mainfile(filepath=str(OUT / 'source/football_parts.blend'))
base = {name: bpy.data.objects[name].data.copy() for name in ['Torso','Hips','Head','Thigh','Shin','UpperArm','Forearm','Boot','Sole']}
bpy.ops.object.select_all(action='SELECT')
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)

def cv(p):
    return Vector((p[0], -p[2], p[1]))

def joint(root, target, pole, first=.53, second=.53):
    d=target-root; length=min(d.length,first+second-.001); axis=d.normalized()
    bend=(pole-axis*pole.dot(axis)).normalized()
    along=(first*first-second*second+length*length)/(2*length)
    return root+axis*along+bend*math.sqrt(max(0,first*first-along*along))

def segment(a,b):
    up=(b-a).normalized(); ref=Vector((0,0,-1)) if abs(up.z)<.95 else Vector((1,0,0))
    right=up.cross(ref).normalized(); forward=right.cross(up)
    m=Matrix((right,up*(b-a).length,forward)).transposed().to_4x4()
    m.translation=(a+b)*.5
    return m

# Godot local coordinate basis converted to Blender Z-up.
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
rest={}
for name,pos in [('hips',(0,1.02,0)),('torso',(0,1.32,0)),('head',(0,1.74,0))]:
    rest[name]=Matrix.Translation(Vector(pos))
for side in [0,1]:
    tag='l' if side==0 else 'r'; sign=-1 if side==0 else 1
    hip=Vector((sign*.14,1.02,0)); foot=Vector((sign*.16,.07,0))
    knee=joint(hip,foot,Vector((0,0,-1)))
    shoulder=Vector((sign*.26,1.47,0)); hand=Vector((sign*.38,1,0))
    elbow=joint(shoulder,hand,Vector((sign,0,.4)),.30,.30)
    rest['thigh_'+tag]=segment(hip,knee);rest['shin_'+tag]=segment(knee,foot)
    rest['upper_arm_'+tag]=segment(shoulder,elbow);rest['forearm_'+tag]=segment(elbow,hand)
    rest['boot_'+tag]=Matrix.Translation(foot+Vector((0,-.015,-.025)))
    # Hand local up follows the forearm, as in procedural_player.gd.
    axis=(hand-elbow).normalized(); q=Vector((0,1,0)).rotation_difference(axis)
    rest['hand_'+tag]=q.to_matrix().to_4x4();rest['hand_'+tag].translation=hand

def material(name,color,rough=.65):
    mat=bpy.data.materials.new(name);mat.diffuse_color=(*color,1);mat.use_nodes=True
    # Blender translates display names. Match stable node types, not English names.
    shader=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None) or mat.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
    output=next((n for n in mat.node_tree.nodes if n.type=='OUTPUT_MATERIAL'),None) or mat.node_tree.nodes.new('ShaderNodeOutputMaterial')
    output.is_active_output=True
    mat.node_tree.links.new(shader.outputs['BSDF'],output.inputs['Surface'])
    shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Roughness'].default_value=rough
    return mat

def sphere(name, center, scale, mat, pieces):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,location=cv(center))
    obj=bpy.context.object;obj.name=name;obj.scale=(scale[0],scale[2],scale[1])
    obj.data.materials.append(mat);pieces.append(obj)
    return obj

def polygon(name,verts,faces,mat,pieces):
    data=bpy.data.meshes.new(name);data.from_pydata([cv(v) for v in verts],[],faces);data.update()
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat);pieces.append(obj);return obj

def stripe(name,start,end,radius,mat,pieces):
    a,b=cv(start),cv(end)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=radius,depth=(b-a).length,location=(a+b)*.5)
    obj=bpy.context.object;obj.name=name;obj.rotation_mode='QUATERNION'
    obj.rotation_quaternion=Vector((0,0,1)).rotation_difference((b-a).normalized())
    obj.data.materials.append(mat);pieces.append(obj)

def number(text,loc,scale,mat,pieces,back=False):
    bpy.ops.object.text_add();obj=bpy.context.object;obj.data.body=text
    obj.data.align_x='CENTER';obj.data.size=scale;obj.data.extrude=.0015
    bpy.ops.object.convert(target='MESH')
    for v in obj.data.vertices:
        p=v.co.copy();v.co=cv(((p.x if back else -p.x)+loc[0],p.y+loc[1],loc[2]+(p.z if back else -p.z)))
    obj.data.materials.append(mat);pieces.append(obj)

def attach(bone,pieces,collection):
    transform=C@rest[bone]@C.inverted()
    # Object scale/rotation setters defer matrix evaluation until the depsgraph updates.
    bpy.context.view_layer.update()
    joined=[]
    for obj in pieces:
        local=obj.matrix_world.copy()
        # Bake the analytical part transform into the bind vertices.
        obj.data.transform(transform@local);obj.matrix_world=Matrix.Identity(4)
        group=obj.vertex_groups.new(name=bone);group.add(list(range(len(obj.data.vertices))),1,'REPLACE')
        if bone=='torso':
            for sign,tag in [(-1,'l'),(1,'r')]:
                extra=obj.vertex_groups.new(name='upper_arm_'+tag)
                for v in obj.data.vertices:
                    if v.co.x*sign>.18 and v.co.z>1.36:
                        group.add([v.index],.85,'REPLACE');extra.add([v.index],.15,'REPLACE')
        for poly in obj.data.polygons:poly.use_smooth=True
        # Move into the character's own collection.
        for old in list(obj.users_collection):old.objects.unlink(obj)
        collection.objects.link(obj);joined.append(obj)
    return joined

roles=[('cobalt_striker',(.06,.28,.60),(.12,.14,.22),(.78,.52,.34),9),
       ('amber_keeper',(.90,.30,.035),(.055,.09,.12),(.60,.36,.23),1),
       ('graphite_defender',(.055,.075,.11),(.09,.12,.15),(.42,.23,.16),6)]
exported=[]
for role,shirt_color,hair_color,skin_color,shirt_number in roles:
    collection=bpy.data.collections.new(role);bpy.context.scene.collection.children.link(collection)
    cloth=material(role+'_jersey',shirt_color,.88);skin=material(role+'_skin',skin_color,.66)
    dark=material(role+'_shorts',(.035,.065,.10),.9);trim=material(role+'_trim',(.70,.85,.90),.68)
    gold=material(role+'_crest',(.96,.72,.16),.46);hair=material(role+'_hair',hair_color,.9)
    white=material(role+'_white',(.91,.93,.88));eye=material(role+'_iris',(.11,.20,.16),.35)
    pupil=material(role+'_pupil',(.018,.022,.03),.3);shoe=material(role+'_boot',(.12,.17,.24),.42)
    accent=material(role+'_boot_accent',(.29,.75,.78) if shirt_number!=1 else (.94,.68,.16),.45)
    all_parts=[]
    for bone in rest:
        pieces=[]
        kind={'hips':'Hips','torso':'Torso','head':'Head'}.get(bone)
        if not kind:
            kind=next((v for k,v in [('upper_arm','UpperArm'),('forearm','Forearm'),('thigh','Thigh'),('shin','Shin'),('boot','Boot')] if bone.startswith(k)),None)
        if kind:
            obj=bpy.data.objects.new(role+'_'+bone,base[kind].copy());bpy.context.collection.objects.link(obj)
            obj.data.materials.clear();obj.data.materials.append({'Hips':dark,'Torso':cloth,'Head':skin,'Thigh':skin,'Shin':trim,'UpperArm':cloth,'Forearm':skin,'Boot':shoe}[kind]);pieces.append(obj)
        if bone=='torso':
            # Original diagonal kit stripes, collar, shoulder piping, crest and number.
            for dx in [-.11,.08]:
                stripe('jersey_piping',(dx,-.19,-.105),(dx+.085,.15,-.14),.006,trim,pieces)
            stripe('collar_l',(-.09,.23,-.079),(0,.19,-.112),.011,dark,pieces)
            stripe('collar_r',(0,.19,-.112),(.09,.23,-.079),.011,dark,pieces)
            for sx in [-1,1]:
                stripe('shoulder_seam',(sx*.15,.18,-.08),(sx*.218,.11,-.09),.0045,gold,pieces)
            polygon('original_crest',[(-.11,.075,-.145),(-.085,.095,-.146),(-.06,.075,-.145),(-.066,.035,-.144),(-.085,.02,-.143),(-.104,.035,-.144)],[(0,1,2,3,4,5)],gold,pieces)
            number(str(shirt_number),(.075,-.075,-.142),.09,white,pieces)
            number(str(shirt_number),(0,-.08,.135),.19,white,pieces,back=True)
            sphere('neck',(0,.285,0),(.052,.074,.048),skin,pieces)
        if bone=='hips':
            for sx in [-1,1]:
                stripe('shorts_seam',(sx*.179,-.07,-.09),(sx*.16,.08,-.08),.005,trim,pieces)
        if bone=='head':
            # Distinct jaw widths and hair / beard silhouettes.
            for v in obj.data.vertices:v.co.x*=1.03 if shirt_number==1 else (.97 if shirt_number==9 else 1.08)
            for sx in [-1,1]:
                sphere('ear',(sx*.108,-.005,.006),(.015,.026,.014),skin,pieces)
                sphere('ear_fold',(sx*.120,-.005,-.001),(.003,.014,.008),skin,pieces)
                sphere('eyeball',(sx*.042,.023,-.098),(.018,.011,.014),white,pieces)
                sphere('iris',(sx*.042,.022,-.111),(.008,.008,.004),eye,pieces)
                sphere('pupil',(sx*.042,.022,-.1145),(.004,.005,.0025),pupil,pieces)
                stripe('brow',(sx*.025,.043,-.101),(sx*.061,.045,-.101),.004,hair,pieces)
            polygon('sculpted_nose',[(-.015,.038,-.098),(.015,.038,-.098),(-.016,-.026,-.101),(.016,-.026,-.101),(0,-.015,-.139),(0,.018,-.121)],[(0,1,5),(0,5,4,2),(1,3,4,5),(2,4,3)],skin,pieces)
            stripe('upper_lip',(-.023,-.058,-.104),(.023,-.058,-.104),.0038,hair,pieces)
            sphere('lower_lip',(0,-.064,-.103),(.022,.004,.005),skin,pieces)
            verts=[];faces=[];rings=10;segments=28
            for row in range(rings+1):
                phi=(row/rings)*1.37
                for i in range(segments):
                    a=i/segments*math.tau
                    verts.append((.11*math.sin(phi)*math.cos(a),.046+.104*math.cos(phi),.108*math.sin(phi)*math.sin(a)+.015))
            for row in range(rings):
                for i in range(segments):
                    a=row*segments+i;b=row*segments+(i+1)%segments;faces.append((a,b,b+segments,a+segments))
            polygon('hair_cap',verts,faces,hair,pieces)
            if shirt_number==9:
                for i in range(6):sphere('swept_hair',(-.06+i*.021,.136+math.sin(i*.7)*.008,-.025+i*.009),(.024,.018,.044),hair,pieces)
            elif shirt_number==6:
                for sx in [-1,1]:stripe('beard', (sx*.073,-.035,-.076),(sx*.035,-.103,-.065),.013,hair,pieces)
                sphere('chin_beard',(0,-.105,-.062),(.037,.017,.019),hair,pieces)
        if bone.startswith('thigh'):
            # Fabric around the upper leg and rounded joints prevent detached-looking limbs.
            sphere('shorts_leg',(0,-.34,0),(.108,.31,.090),dark,pieces)
            stripe('shorts_leg_seam',(-.092,-.46,-.034),(-.085,-.13,-.046),.004,trim,pieces)
        if bone.startswith('shin'):
            sphere('kneecap',(0,-.50,-.009),(.069,.13,.061),skin,pieces)
            stripe('sock_emblem',(-.016,-.22,-.061),(.016,-.22,-.061),.005,cloth,pieces)
        if bone.startswith('upper_arm'):
            sphere('shoulder_sleeve',(0,-.45,0),(.090,.24,.078),cloth,pieces)
            stripe('sleeve_trim',(-.052,.42,-.035),(.052,.42,-.035),.0045,trim,pieces)
        if bone.startswith('forearm'):
            sphere('elbow_joint',(0,-.49,0),(.045,.16,.042),skin,pieces)
        if bone.startswith('boot'):
            sole=bpy.data.objects.new('outsole',base['Sole'].copy());bpy.context.collection.objects.link(sole);sole.data.materials.clear();sole.data.materials.append(dark);pieces.append(sole)
            for i in range(5):stripe('laces',(-.030,.046+i*.004,-.027+i*.017),(.030,.046+i*.004,-.027+i*.017),.0025,white,pieces)
            for sx in [-1,1]:
                stripe('boot_trim',(sx*.055,-.020,-.08),(sx*.039,.01,.078),.003,accent,pieces)
                for z in [-.087,-.032,.072]:sphere('stud',(sx*.035,-.055,z),(.010,.012,.010),dark,pieces)
        if bone.startswith('hand'):
            glove=shirt_number==1;mat=white if glove else skin
            sphere('palm',(0,.012,0),(.044,.062,.026),mat,pieces)
            for finger in range(4):
                x=(finger-1.5)*.021;length=[.045,.058,.054,.043][finger]
                sphere('finger',(x,.075+length*.35,-.003),(.009,length*.60,.011),mat,pieces)
                if glove:stripe('glove_ridge',(x,.052,-.025),(x,.090,-.025),.0035,accent,pieces)
            sphere('thumb',(-.042,.027,-.004),(.014,.038,.015),mat,pieces)
            if glove:sphere('wrist_strap',(0,-.045,0),(.047,.013,.030),dark,pieces)
        all_parts.extend(attach(bone,pieces,collection))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in all_parts:obj.select_set(True)
    bpy.context.view_layer.objects.active=all_parts[0];bpy.ops.object.join();body=bpy.context.object
    body.name=role+'_Body'
    arm_data=bpy.data.armatures.new(role+'_Skeleton');rig=bpy.data.objects.new(role+'_Rig',arm_data);collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig;rig.select_set(True);body.select_set(False)
    bpy.ops.object.mode_set(mode='EDIT');root_bone=arm_data.edit_bones.new('root');root_bone.head=(0,0,0);root_bone.tail=(0,0,.2)
    for name,m in rest.items():
        bone=arm_data.edit_bones.new(name);bone.head=cv(m.translation)
        axis=Vector((m[0][1],m[1][1],m[2][1])).normalized()
        bone.tail=bone.head+cv(axis)*.12
        parent='root'
        if name=='torso':parent='hips'
        elif name=='head':parent='torso'
        elif name.startswith('thigh'):parent='hips'
        elif name.startswith('shin'):parent=name.replace('shin','thigh')
        elif name.startswith('boot'):parent=name.replace('boot','shin')
        elif name.startswith('upper_arm'):parent='torso'
        elif name.startswith('forearm'):parent=name.replace('forearm','upper_arm')
        elif name.startswith('hand'):parent=name.replace('hand','forearm')
        bone.parent=arm_data.edit_bones.get(parent)
    bpy.ops.object.mode_set(mode='OBJECT');rig.show_in_front=True
    modifier=body.modifiers.new('Procedural IK deform rig','ARMATURE');modifier.object=rig
    body.parent=rig
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);body.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(OUT/(role+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_all_influences=False)
    verts=len(body.data.vertices);tris=sum(len(p.vertices)-2 for p in body.data.polygons)
    exported.append({'role':role,'vertices':verts,'triangles':tris,'bones':len(arm_data.bones)})
    # Keep all three characters side by side in the editable Blender study.
    rig.location.x={'cobalt_striker':-1.1,'amber_keeper':0,'graphite_defender':1.1}[role]

scene=bpy.context.scene
scene['authoring_notes']='Original Cobalt 9 / Amber 1 / Graphite 6. Game drives this rest rig from analytical IK, not animation clips.'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/original_players.blend'))
(OUT/'original_players_manifest.json').write_text(json.dumps(exported,indent=2))
print('ORIGINAL PLAYER EXPORTS',json.dumps(exported))
