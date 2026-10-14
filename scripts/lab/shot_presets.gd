extends RefCounted

# SI initial conditions. These are experiments, not measured trajectory data.
const PRESETS := {
	"İdeal atış / vakum": {"start_position": Vector3(0, 1, 25), "elevation_degrees": 30.0, "launch_speed": 20.0, "spin_speed": 0.0, "air_drag": 0.0},
	"Spinsiz şut": {"elevation_degrees": 18.0, "launch_speed": 27.0, "spin_speed": 0.0},
	"Yüksek hızlı düz şut": {"elevation_degrees": 8.0, "launch_speed": 35.0, "spin_speed": 0.0},
	"Sağ falso": {"spin_axis": Vector3.UP, "spin_speed": 40.0},
	"Sol falso": {"spin_axis": Vector3.DOWN, "spin_speed": 40.0},
	"Düşük spin / knuckle": {"launch_speed": 24.0, "spin_speed": 1.0, "knuckle_requested": true},
	"Yüksek açılı şut": {"elevation_degrees": 55.0, "launch_speed": 24.0, "spin_speed": 0.0},
	"Yerden şut / kayma": {"start_position": Vector3(0, 0.1105, 25), "elevation_degrees": 0.0, "launch_speed": 12.0, "spin_speed": 0.0},
	"Düşme / sekme": {"start_position": Vector3(0, 3, 25), "launch_speed": 0.0, "spin_speed": 0.0, "air_drag": 0.0},
	"Saf yuvarlanma": {"start_position": Vector3(0, 0.1105, 25), "launch_speed": 4.0, "elevation_degrees": 0.0, "spin_axis": Vector3.LEFT, "spin_speed": 4.0 / 0.11, "air_drag": 0.0}
}

static func values(name: String) -> Dictionary:
	var baseline := {"start_position": Vector3(0, 0.12, 25), "yaw_degrees": 0.0, "elevation_degrees": 18.0, "launch_speed": 27.0, "spin_axis": Vector3.UP, "spin_speed": 35.0, "air_drag": 1.10, "magnus_scale": 0.80, "include_goal_collisions": false, "ground_bounce": 0.55, "ground_friction": 0.55, "knuckle_requested": false, "shot_seed": 12345}
	baseline.merge(PRESETS.get(name, {}), true)
	return baseline
