shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D grass_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_roughness : filter_linear_mipmap, repeat_enable;
uniform bool detail_enabled = true;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world_position.xz;
	float stripe = mod(floor(p.y / 3.6), 2.0);
	float patch = noise(p * 1.6);
	float grain = hash(floor(p * 180.0));
	vec2 grass_uv = p / 1.8;
	ALBEDO = texture(grass_color, grass_uv).rgb * vec3(0.55, 0.72, 0.46) * (0.86 + stripe * 0.14 + patch * 0.06);
	if (detail_enabled) {
		NORMAL_MAP = texture(grass_normal, grass_uv).rgb;
		NORMAL_MAP_DEPTH = 0.65;
		ROUGHNESS = max(0.75, texture(grass_roughness, grass_uv).r);
	} else {
		ROUGHNESS = 0.95;
	}
}
