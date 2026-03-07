shader_type canvas_item;

// Snow ground surface shader.
// Adds sparkle, blue-shadow depth, and drift shading to the snow ground texture.

uniform sampler2D snow_texture : repeat_enable, filter_linear;
uniform vec4 snow_tint   : source_color = vec4(0.93, 0.96, 1.00, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.62, 0.74, 0.90, 1.0);
uniform float sparkle_density = 0.92;   // threshold for glint (higher = fewer)
uniform float shadow_depth    = 0.45;   // blue-shadow amount in hollows
uniform float snow_scale      = 3.5;

void fragment() {
	vec2 scaled_uv = UV * snow_scale;
	vec4 tex = texture(snow_texture, scaled_uv);

	// Interpret red channel as height/drift map
	float height = tex.r;

	// Remap to snow colour range
	vec3 snow_col = mix(shadow_tint.rgb, snow_tint.rgb, height);

	// Specular sparkle: rare very bright points
	// Use two noise layers at different frequencies for natural distribution
	vec2 glint_uv1 = UV * 80.0 + vec2(0.13, 0.27);
	vec2 glint_uv2 = UV * 45.0 + vec2(0.71, 0.44);
	float g1 = texture(snow_texture, glint_uv1).g;
	float g2 = texture(snow_texture, glint_uv2).b;
	float sparkle = g1 * g2;
	float glint = step(sparkle_density, sparkle);
	// Animate sparkle subtly
	glint *= step(0.5, sin(TIME * 3.0 + UV.x * 120.0 + UV.y * 80.0) * 0.5 + 0.5);
	snow_col = mix(snow_col, vec3(1.0, 1.0, 1.0), glint * 0.8);

	// Drift shadow in hollows
	float hollow = 1.0 - smoothstep(0.25, 0.6, height);
	snow_col = mix(snow_col, shadow_tint.rgb, hollow * shadow_depth);

	// Edge fade so tiles blend
	float edge = smoothstep(0.0, 0.04, UV.x)
			   * smoothstep(1.0, 0.96, UV.x)
			   * smoothstep(0.0, 0.04, UV.y)
			   * smoothstep(1.0, 0.96, UV.y);

	COLOR = vec4(snow_col, TEXTURE.a * edge);
}
