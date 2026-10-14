extends RefCounted
const Geo = preload("res://geometry.gd")

static func build(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "StadiumDetails"
	root.add_to_group("quality_decoration")
	parent.add_child(root)
	var metal := Geo.material(Color("778997"), 0.45)
	var dark := Geo.material(Color("1b2933"))
	var roof := Geo.material(Color("647989"))
	Geo.box(root, Vector3(52, 0.22, 9), roof, Vector3(0, 7.0, -11.7))
	for x in [-25.0, -15.0, -5.0, 5.0, 15.0, 25.0]:
		Geo.between(Geo.rod(root, 0.095, metal), Vector3(x, 0, -15), Vector3(x, 7, -15))
		Geo.between(Geo.rod(root, 0.075, metal), Vector3(x, 5.2, -15), Vector3(x, 6.9, -7.5))
		Geo.between(Geo.rod(root, 0.065, metal), Vector3(x, 6.9, -15), Vector3(x, 6.9, -7.5))
	for x in [-36.0, 36.0]:
		for z in [-18.0, 45.0]:
			Geo.between(Geo.rod(root, 0.18, metal), Vector3(x, 0, z), Vector3(x, 17, z))
			Geo.box(root, Vector3(3.8, 1.8, 0.20), dark, Vector3(x, 17, z))
			var light := Geo.material(Color("eef5e4"))
			light.emission_enabled = true
			light.emission = Color("f5f8db")
			light.emission_energy_multiplier = 2
			for index in range(8):
				Geo.box(root, Vector3(0.65, 0.55, 0.06), light, Vector3(x - 1.25 + (index % 4) * 0.83, 16.60 + (index / 4) * 0.8, z + 0.14))
		# Open player benches along the touchline.
		Geo.box(root, Vector3(2.6, 0.15, 7), roof, Vector3(x, 2.6, 18))
		Geo.box(root, Vector3(1.2, 0.12, 6), dark, Vector3(x, 0.55, 18))
		for z in [15.0, 21.0]:
			Geo.between(Geo.rod(root, 0.045, metal), Vector3(x, 0, z), Vector3(x, 2.6, z))
	for x in [-34.0, 34.0]:
		for z in [0.0, 62.0]:
			Geo.between(Geo.rod(root, 0.023, metal), Vector3(x, 0, z), Vector3(x, 1.5, z))
			Geo.box(root, Vector3(0.36, 0.27, 0.025), Geo.material(Color("e2c54b")), Vector3(x + 0.18, 1.30, z))
	var sign := Label3D.new()
	sign.text = parent.tr("SERBEST VURUŞ ARENASI")
	sign.position = Vector3(0, 5.65, -7.3)
	sign.font_size = 64
	sign.pixel_size = 0.0035
	sign.modulate = Color("e0ecdf")
	root.add_child(sign)
	# Repeated seat backs are batched in one draw rather than hundreds of nodes.
	var seats := MultiMesh.new()
	seats.transform_format = MultiMesh.TRANSFORM_3D
	var shape := BoxMesh.new()
	shape.size = Vector3(0.48, 0.38, 0.08)
	seats.mesh = shape
	seats.instance_count = 384
	for row in range(8):
		for column in range(48):
			seats.set_instance_transform(row * 48 + column, Transform3D(Basis.IDENTITY, Vector3(-22 + column * 0.94, 1.8 + row * 0.48, -8.2 - row * 0.95)))
	var seat_mesh := MultiMeshInstance3D.new()
	seat_mesh.multimesh = seats
	seat_mesh.material_override = Geo.material(Color("2c6582"))
	root.add_child(seat_mesh)
