extends RefCounted

static var active_profile: Resource
static var authored_shadows: Dictionary = {}
static var authored_detail_visibility: Dictionary = {}

static func auto_level() -> int:
	if not OS.has_feature("web"): return 2
	var touch := DisplayServer.is_touchscreen_available()
	if OS.has_feature("web"):
		var mobile = JavaScriptBridge.eval("/Android|iPhone|iPad|iPod/i.test(navigator.userAgent) || (navigator.maxTouchPoints > 1 && /Macintosh/.test(navigator.userAgent))")
		touch = touch or bool(mobile)
	return 0 if touch else 1

static func factory_profile(level: int) -> Resource:
	return load(["res://settings/web_low.tres", "res://settings/web_medium.tres", "res://settings/web_high.tres"][clampi(level, 0, 2)])

static func current() -> Resource:
	if active_profile == null: active_profile = factory_profile(auto_level()).duplicate(true)
	return active_profile

static func apply(game: Node3D, profile: Resource = null) -> PackedStringArray:
	var selected := profile if profile != null else current()
	var errors: PackedStringArray = selected.validate()
	if not errors.is_empty(): return errors
	active_profile = selected.duplicate(true)
	var viewport := game.get_viewport()
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = active_profile.render_scale
	viewport.msaa_3d = active_profile.msaa
	var world := game.get_node_or_null("World")
	if world == null: world = game
	for light in world.find_children("*", "Light3D", true, false):
		var id := light.get_instance_id()
		if not authored_shadows.has(id): authored_shadows[id] = light.shadow_enabled
		light.shadow_enabled = authored_shadows[id] and active_profile.shadows
	var details := world.get_node_or_null("StadiumDetails")
	var decorations: Array = game.get_tree().get_nodes_in_group("quality_decoration")
	if details != null and details not in decorations: decorations.append(details)
	for decoration in decorations:
		if not world.is_ancestor_of(decoration): continue
		var id: int = decoration.get_instance_id()
		if not authored_detail_visibility.has(id): authored_detail_visibility[id] = decoration.visible
		decoration.visible = authored_detail_visibility[id] and active_profile.stadium_details
	for mesh in world.find_children("*", "MeshInstance3D", true, false):
		var material = mesh.material_override
		if material is ShaderMaterial and material.shader.resource_path == "res://grass.gdshader":
			material.set_shader_parameter("detail_enabled", active_profile.grass_details)
	var actors: Array = [game.player, game.defenders.keeper] + game.defenders.wall_pool
	for actor in actors:
		if actor: actor.visual_update_hz = active_profile.skeleton_rate
	if game.goal_net.has_method("set_visual_quality"):
		game.goal_net.set_visual_quality(active_profile.net_visual_density)
	game.trace_root.visible = active_profile.flight_trail and game.hud.trace_toggle.button_pressed
	if game.hud.quality_select != null: game.hud.quality_select.select(active_profile.level)
	return errors
