shader_type spatial;
render_mode cull_disabled;
uniform vec4 rope_color : source_color = vec4(0.80, 0.82, 0.76, 1.0);
uniform sampler2D particle_displacements : filter_nearest, repeat_disable;
uniform vec4 wrap_balls[4];
uniform vec3 wrap_normals[4];
void vertex() {
 VERTEX += texelFetch(particle_displacements, ivec2(int(UV.x), 0), 0).xyz * COLOR.r;
 VERTEX += texelFetch(particle_displacements, ivec2(int(UV.y), 0), 0).xyz * COLOR.g;
 VERTEX += texelFetch(particle_displacements, ivec2(int(UV2.x), 0), 0).xyz * COLOR.b;
 VERTEX += texelFetch(particle_displacements, ivec2(int(UV2.y), 0), 0).xyz * COLOR.a;
 // Fine rope geometry cannot pass through the actual contacting sphere.
 for (int i = 0; i < 4; i++) {
  float radius = wrap_balls[i].w;
  if (radius > 0.0) {
   vec3 delta = VERTEX - wrap_balls[i].xyz;
   vec3 normal = wrap_normals[i];
   float depth = dot(delta, normal);
   vec3 tangent = delta - normal * depth;
   float radial_sq = dot(tangent, tangent);
   if (radial_sq < radius * radius && depth > -0.8) {
    float shell = sqrt(radius * radius - radial_sq);
    VERTEX += normal * max(0.0, shell - depth);
   }
  }
 }
}
void fragment() {
 ALBEDO = rope_color.rgb;
 ROUGHNESS = 0.92;
}
