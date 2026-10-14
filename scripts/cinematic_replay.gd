extends Node3D

const ANGLES := ["SAHA KENARI", "KALE ARKASI", "ÜST AÇI", "TERS ÇAPRAZ", "ÇİM SEVİYESİ", "KALECİ YAKINI", "FİLE YAKINI"]
var frames: Array[Dictionary] = []
var recording := false
var playing := false
var elapsed := 0.0
var record_accumulator := 0.0
var strike_time := 0.0
var goal_time := -1.0
var play_time := 0.0
var angle_index := 0
var sample_index := 0
var cut_elapsed := 0.0
var playback_speed := 0.25
var launch_spin := Vector3.ZERO
var launch_velocity := Vector3.ZERO
var shot_power := 0.0
var shot_contact := Vector2.ZERO
var shot_knuckle := 0.0
var sound_events: Array[Dictionary] = []
var sound_index := 0
var saved: Dictionary = {}
var visual_ball: Node3D

func reset() -> void:
	frames.clear()
	recording = false
	playing = false
	elapsed = 0
	record_accumulator = 0
	strike_time = 0
	goal_time = -1
	launch_spin = Vector3.ZERO
	launch_velocity = Vector3.ZERO
	sound_events.clear()
	saved.clear()
	if visual_ball != null:
		visual_ball.visible = false

func begin(game: Node3D) -> void:
	reset()
	recording = true
	shot_power = game.power
	shot_contact = game.hud.picker.point
	frames.append(capture(game))

func mark_strike(impact: Dictionary, mass: float) -> void:
	strike_time = elapsed
	launch_velocity = impact.impulse / mass
	launch_spin = impact.spin
	shot_knuckle = impact.knuckle

func record_sound(kind: String, location: Vector3, pitch: float) -> void:
	if recording:
		sound_events.append({"time": elapsed, "kind": kind, "location": location, "pitch": pitch})

func actor_pose(actor: Node3D) -> Dictionary:
	return {"transform": actor.global_transform, "pelvis": actor.pelvis, "feet": actor.feet.duplicate(), "hands": actor.hand_targets.duplicate(), "lean": actor.lean, "twist": actor.twist, "support_shoe": actor.boots[0].quaternion, "shoe": actor.boots[1].quaternion, "head": actor.head.quaternion, "visible": actor.visible}

func capture(game: Node3D) -> Dictionary:
	var wall := []
	for actor in game.defenders.wall:
		wall.append(actor_pose(actor))
	return {"time": elapsed, "ball": game.ball.global_transform, "velocity": game.ball.linear_velocity, "spin": game.ball.angular_velocity, "player": actor_pose(game.player), "keeper": actor_pose(game.defenders.keeper), "wall": wall, "net_time": game.goal_net.clock, "cloth": game.goal_net.cloth.positions.duplicate(), "wraps": game.goal_net.wrap_balls.duplicate(), "normals": game.goal_net.wrap_normals.duplicate()}

func record(delta: float, game: Node3D, final: bool) -> void:
	if not recording:
		return
	elapsed += delta
	record_accumulator += delta
	if record_accumulator >= 1.0 / 60.0 or final:
		record_accumulator = fmod(record_accumulator, 1.0 / 60.0)
		frames.append(capture(game))
	if final or elapsed > 10:
		recording = false

func available() -> bool:
	return frames.size() > 2 and goal_time >= 0 and not recording

func start(game: Node3D) -> bool:
	if not available() or playing:
		return false
	saved = capture(game)
	saved["cloth_previous"] = game.goal_net.cloth.previous.duplicate()
	saved["camera"] = game.camera.global_transform
	saved["fov"] = game.camera.fov
	saved["ball_visible"] = game.ball.visible
	saved["trace_visible"] = game.trace_root.visible
	if visual_ball == null:
		visual_ball = Node3D.new()
		add_child(visual_ball)
		for child in game.ball.get_children():
			if child is MeshInstance3D:
				visual_ball.add_child(child.duplicate())
	game.ball.replay_mode = true
	game.ball.visible = false
	game.trace_root.visible = false
	visual_ball.visible = true
	playing = true
	game.sound.stop_effects()
	angle_index = 0
	reset_cut()
	apply_frame(game)
	return true

func clip_start() -> float:
	if angle_index >= 5:
		return maxf(strike_time, goal_time - 0.55)
	return maxf(0, strike_time - 0.45)

func change_angle(direction: int, game: Node3D) -> void:
	if not playing:
		return
	game.sound.stop_effects()
	angle_index = posmod(angle_index + direction, ANGLES.size())
	reset_cut()
	apply_frame(game)

func reset_cut() -> void:
	play_time = clip_start()
	sample_index = 0
	cut_elapsed = 0
	sound_index = 0
	while sound_index < sound_events.size() and sound_events[sound_index].time < play_time:
		sound_index += 1

func advance(delta: float, game: Node3D) -> bool:
	if not playing:
		return false
	play_time += delta * playback_speed
	while sound_index < sound_events.size() and sound_events[sound_index].time <= play_time:
		var event := sound_events[sound_index]
		game.sound.play_effect(event.kind, event.location, event.pitch * 0.65)
		sound_index += 1
	cut_elapsed += delta
	if play_time >= frames[-1].time:
		game.sound.stop_effects()
		angle_index += 1
		if angle_index >= ANGLES.size():
			return false
		reset_cut()
	apply_frame(game)
	return true

func blend_actor(actor: Node3D, a: Dictionary, b: Dictionary, weight: float) -> void:
	actor.global_transform = a.transform.interpolate_with(b.transform, weight)
	actor.pelvis = a.pelvis.lerp(b.pelvis, weight)
	for side in range(2):
		actor.feet[side] = a.feet[side].lerp(b.feet[side], weight)
		actor.hand_targets[side] = a.hands[side].lerp(b.hands[side], weight)
	actor.lean = lerpf(a.lean, b.lean, weight)
	actor.twist = lerpf(a.twist, b.twist, weight)
	actor.boots[1].quaternion = a.shoe.slerp(b.shoe, weight)
	actor.boots[0].quaternion = a.support_shoe.slerp(b.support_shoe, weight)
	actor.visible = a.visible
	actor.update_pose()
	actor.head.quaternion = a.head.slerp(b.head, weight)

func apply_pose(game: Node3D, a: Dictionary, b: Dictionary, weight: float) -> void:
	blend_actor(game.player, a.player, b.player, weight)
	blend_actor(game.defenders.keeper, a.keeper, b.keeper, weight)
	for index in range(game.defenders.wall.size()):
		blend_actor(game.defenders.wall[index], a.wall[index], b.wall[index], weight)
	game.defenders.sync_collision_pose()
	game.goal_net.clock = lerpf(a.net_time, b.net_time, weight)
	for index in range(a.cloth.size()):
		game.goal_net.cloth.positions[index] = a.cloth[index].lerp(b.cloth[index], weight)
	for index in range(4):
		game.goal_net.wrap_balls[index] = a.wraps[index].lerp(b.wraps[index], weight)
		game.goal_net.wrap_balls[index].x = visual_ball.position.x if playing else game.ball.position.x
		game.goal_net.wrap_balls[index].y = visual_ball.position.y if playing else game.ball.position.y
		game.goal_net.wrap_balls[index].z = visual_ball.position.z if playing else game.ball.position.z
		game.goal_net.wrap_normals[index] = a.normals[index]
	game.goal_net.visual_dirty = true
	game.goal_net.update_visual()

func apply_frame(game: Node3D) -> void:
	while sample_index < frames.size() - 2 and frames[sample_index + 1].time < play_time:
		sample_index += 1
	var a := frames[sample_index]
	var b := frames[sample_index + 1]
	var weight := clampf((play_time - a.time) / maxf(b.time - a.time, 0.0001), 0, 1)
	visual_ball.global_transform = a.ball.interpolate_with(b.ball, weight)
	apply_pose(game, a, b, weight)
	var progress := clampf((play_time - clip_start()) / maxf(frames[-1].time - clip_start(), 0.1), 0, 1)
	var focus := visual_ball.position.lerp(Vector3(0, 1, -0.3), 0.12)
	match angle_index:
		0:
			game.camera.position = Vector3(-8.0 + progress * 1.2, 3.2, game.origin.z * 0.58 + 1)
			game.camera.fov = lerpf(48, 40, progress)
		1:
			game.camera.position = Vector3(5.3 - progress * 0.7, 1.4 + progress * 0.3, -3.8)
			game.camera.fov = lerpf(56, 45, progress)
		2:
			game.camera.position = Vector3(-6.5 + progress * 3, 5.8, 6.5)
			game.camera.fov = lerpf(52, 42, progress)
		3:
			game.camera.position = Vector3(8.5 - progress, 2.7, 8.0)
			game.camera.fov = lerpf(48, 38, progress)
		4:
			game.camera.position = Vector3(-4.7, 0.28 + progress * 0.25, 5.2)
			game.camera.fov = 58
		5:
			game.camera.position = Vector3(4.8, 1.7, 1.9 + progress * 0.6)
			game.camera.fov = 60
		6:
			game.camera.position = Vector3(-4.8 + progress * 0.3, 1.25, -3.7)
			game.camera.fov = 62
	game.camera.look_at(focus)
	game.hud.cinema_label.text = tr("GOL TEKRARI · %d/7 · %s · AĞIR ÇEKİM ×0,25 · ← →") % [angle_index + 1, tr(ANGLES[angle_index])]
	var speed: float = a.velocity.lerp(b.velocity, weight).length() * 3.6
	var spin: float = a.spin.lerp(b.spin, weight).length() / TAU
	var curl := tr("SAĞA") if launch_spin.y < -1 else (tr("SOLA") if launch_spin.y > 1 else tr("DÜZ"))
	if shot_knuckle > 0.5:
		curl = tr("ÖLÜ YAPRAK")
	game.hud.cinema_stats.text = tr("ÇIKIŞ %.1f km/sa  ·  ANLIK %.1f km/sa  ·  FALSO %s  ·  DÖNÜŞ %.1f tur/sn  ·  GÜÇ %%%d") % [launch_velocity.length() * 3.6, speed, curl, spin, roundi(shot_power * 100)]
	game.hud.cinema_fade.color.a = clampf(1 - cut_elapsed / 0.16, 0, 1)

func stop(game: Node3D) -> void:
	if not playing:
		return
	playing = false
	game.sound.stop_effects()
	apply_pose(game, saved, saved, 0)
	game.goal_net.cloth.previous = saved.cloth_previous.duplicate()
	game.goal_net.cloth.update_deformation_extent()
	game.camera.global_transform = saved.camera
	game.camera.fov = saved.fov
	game.ball.visible = saved.ball_visible
	game.ball.replay_mode = false
	game.trace_root.visible = saved.trace_visible
	visual_ball.visible = false
	saved.clear()
