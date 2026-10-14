extends Node3D

const Geo = preload("res://geometry.gd")
const Flight = preload("res://flight_model.gd")
var segments: Array[MeshInstance3D] = []
var arrow: MeshInstance3D
var points := PackedVector3Array()

func _ready() -> void:
	var ink := Geo.material(Color("8de5ef"))
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for _index in range(20):
		var segment := Geo.rod(self, 0.009, ink)
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		segments.append(segment)
	var tip := CylinderMesh.new()
	tip.top_radius = 0
	tip.bottom_radius = 0.065
	tip.height = 1.0
	arrow = Geo.mesh(self, tip, ink)
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func set_shot(origin: Vector3, velocity: Vector3, spin: Vector3) -> void:
	# Only a short departure cue, never a complete predicted route to the goal.
	var step := minf(0.35, 6.8 / maxf(velocity.length(), 1)) / segments.size()
	var radius := preload("res://scripts/physics_settings.gd").current_radius()
	var position := origin + velocity.normalized() * (radius + 0.02)
	points = PackedVector3Array([position])
	for segment in segments:
		var previous := position
		velocity += (Flight.force(velocity, spin) / Flight.effective_mass() + Vector3.DOWN * Flight.gravity()) * step
		spin = Flight.decay_spin(spin, step)
		position += velocity * step
		if position.y < radius:
			position.y = radius
			velocity.y = maxf(0, velocity.y)
		Geo.between(segment, previous, position)
		points.append(position)
	var direction := (points[-1] - points[-2]).normalized()
	Geo.between(arrow, position, position + direction * 0.28)
