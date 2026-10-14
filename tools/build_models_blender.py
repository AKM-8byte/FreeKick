"""Build smooth, IK-compatible character parts using the installed Blender."""
import bpy
import math
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'assets' / 'models'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'source').mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def mesh(name, vertices, faces):
    data = bpy.data.meshes.new(name)
    # Author in Godot coordinates; Blender's glTF exporter restores Y-up.
    data.from_pydata([(x, -z, y) for x, y, z in vertices], [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    for polygon in data.polygons:
        polygon.use_smooth = True
    return obj

def loft(name, profiles, axis='y', segments=32):
    vertices, faces = [], []
    for height, width, depth, offset in profiles:
        for index in range(segments):
            angle = index * math.tau / segments
            if axis == 'y':
                vertices.append((width * math.cos(angle), height, offset + depth * math.sin(angle)))
            else:
                vertices.append((offset + width * math.cos(angle), depth * math.sin(angle), height))
    for row in range(len(profiles) - 1):
        for index in range(segments):
            a = row * segments + index
            b = row * segments + (index + 1) % segments
            faces.append((a, b, b + segments, a + segments))
    faces.append(tuple(reversed(range(segments))))
    faces.append(tuple((len(profiles) - 1) * segments + index for index in range(segments)))
    return mesh(name, vertices, faces)

loft('Torso', [(-.24,.16,.095,0),(-.19,.175,.105,0),(-.10,.185,.115,0),(0,.21,.13,-.006),(.10,.23,.14,-.008),(.18,.235,.12,0),(.24,.175,.095,0)])
loft('Hips', [(-.11,.17,.105,0),(-.07,.20,.13,0),(0,.20,.13,0),(.07,.185,.115,0),(.11,.175,.10,0)])
loft('Head', [(-.13,.025,.035,-.015),(-.11,.06,.065,-.015),(-.075,.091,.086,-.008),(-.025,.105,.102,0),(.035,.108,.105,0),(.085,.095,.090,0),(.115,.065,.060,0),(.132,.006,.006,0)])
loft('Thigh', [(-.5,.086,.092,0),(-.35,.098,.098,0),(-.10,.092,.088,-.005),(.15,.075,.074,0),(.35,.064,.064,0),(.5,.059,.060,0)])
loft('Shin', [(-.5,.060,.062,0),(-.28,.070,.079,.004),(-.08,.065,.072,.008),(.15,.052,.056,.005),(.35,.042,.045,0),(.5,.038,.040,0)])
loft('UpperArm', [(-.5,.061,.065,0),(-.32,.070,.069,0),(0,.063,.060,0),(.30,.049,.048,0),(.5,.045,.045,0)])
loft('Forearm', [(-.5,.045,.048,0),(-.27,.052,.050,0),(0,.043,.044,0),(.30,.035,.036,0),(.5,.030,.033,0)])

# A fitted shoe upper: narrow heel, raised instep, wide metatarsal and rounded toe.
vertices, faces = [], []
sections = [(-.13,.012,.006,-.021),(-.12,.046,.020,-.013),(-.09,.063,.033,-.004),(-.04,.066,.037,.0),(.02,.056,.045,.004),(.07,.045,.065,.019),(.115,.038,.053,.014),(.13,.025,.036,.004)]
N = 32
for z, width, height, center in sections:
    for index in range(N):
        a = index * math.tau / N
        vertices.append((width*math.cos(a), center + height*math.sin(a), z))
for row in range(len(sections)-1):
    for i in range(N):
        a, b = row*N+i, row*N+(i+1)%N
        faces.append((a,a+N,b+N,b))
faces.extend([tuple(reversed(range(N))),tuple((len(sections)-1)*N+i for i in range(N))])
mesh('Boot', vertices, faces)

# Rounded sole outline, repeated at its lower and upper rim.
outline = [(-.035,.12),(.035,.12),(.048,.07),(.058,.015),(.068,-.05),(.063,-.10),(.04,-.13),(0,-.137),(-.04,-.13),(-.059,-.10),(-.062,-.05),(-.055,.015),(-.045,.07)]
vertices = [(x,y,z) for y in [-.049,-.035] for x,z in outline]
n = len(outline)
faces = [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
faces.extend([tuple(reversed(range(n))),tuple(n+i for i in range(n))])
mesh('Sole',vertices,faces)

# Recalculate face normals after coordinate conversion.
for obj in list(bpy.context.scene.objects):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.select_set(False)
bpy.ops.export_scene.gltf(filepath=str(OUT / 'football_parts.glb'), export_format='GLB', export_yup=True)

# Save an assembled study alongside editable original parts for Blender review.
from mathutils import Vector
originals = {obj.name: obj for obj in bpy.context.scene.objects}
for obj in originals.values():
    obj.hide_set(True)
palette = {}
for name, color in [('shirt',(.10,.42,.80,1)),('skin',(.70,.40,.25,1)),('shorts',(.04,.07,.12,1)),('socks',(.80,.85,.90,1)),('shoe',(.65,.10,.18,1))]:
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    palette[name] = material
def coord(p):
    return Vector((p[0],-p[2],p[1]))
def display(part, name, material, location, start=None, end=None):
    obj = originals[part].copy()
    obj.data = originals[part].data.copy()
    obj.name = name
    bpy.context.collection.objects.link(obj)
    obj.hide_set(False)
    obj.data.materials.clear()
    obj.data.materials.append(palette[material])
    obj.location = coord(location)
    if start is not None:
        a,b=coord(start),coord(end)
        obj.location=(a+b)*.5
        obj.rotation_mode='QUATERNION'
        obj.rotation_quaternion=Vector((0,0,1)).rotation_difference((b-a).normalized())
        obj.scale.z=(b-a).length
display('Torso','Preview_Shirt','shirt',(0,1.32,0))
display('Hips','Preview_Shorts','shorts',(0,1.02,0))
display('Head','Preview_Head','skin',(0,1.74,0))
for side in [-1,1]:
    hip=(side*.14,1.02,0); knee=(side*.16,.51,-.06); ankle=(side*.16,.07,0)
    display('Thigh',f'Preview_Thigh_{side}','skin',(0,0,0),hip,knee)
    display('Shin',f'Preview_Shin_{side}','socks',(0,0,0),knee,ankle)
    display('Boot',f'Preview_Boot_{side}','shoe',(side*.16,.055,-.025))
    display('Sole',f'Preview_Sole_{side}','shorts',(side*.16,.055,-.025))
    shoulder=(side*.25,1.47,0); elbow=(side*.45,1.28,0); wrist=(side*.52,1.00,-.08)
    display('UpperArm',f'Preview_Sleeve_{side}','shirt',(0,0,0),shoulder,elbow)
    display('Forearm',f'Preview_Forearm_{side}','skin',(0,0,0),elbow,wrist)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'source' / 'football_parts.blend'))
print('BLENDER MODEL PARTS EXPORTED:', OUT)
