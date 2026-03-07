shader_type canvas_item;

// Photorealistic 2D water shader for Alaskan coastal/lake water.
// Combines scrolling wave distortion, foam, reflections, and depth fog.

uniform sampler2D surface_texture : repeat_enable, filter_linear;
uniform sampler2D deep_texture    : repeat_enable, filter_linear;
uniform vec4 shallow_color : source_color = vec4(0.25, 0.55, 0.80, 1.0);
uniform vec4 deep_color    : source_color = vec4(0.10, 0.28, 0.55, 1.0);
uniform vec4 foam_color    : source_color = vec4(0.80, 0.90, 0.96, 0.85);
uniform vec4 sky_reflection : source_color = vec4(0.55, 0.72, 0.88, 1.0);

uniform float wave_speed   = 0.25;
uniform float wave_scale   = 2.5;
uniform float distort_amt  = 0.018;
uniform float foam_thresh  = 0.72;
uniform float depth_fade   = 0.6;   // 0=shallow, 1=deep
uniform float reflection_strength = 0.35;
uniform float time_offset  = 0.0;

float fbm(vec2 uv, int octaves) {
	float val = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < octaves; i++) {
		val += texture(surface_texture, uv * freq).r * amp;
		amp  *= 0.5;
		freq *= 2.1;
	}
	return val;
}

void fragment() {
	float t = TIME * wave_speed + time_offset;

	// Two scrolling layers at slightly different speeds/angles for complex motion
	vec2 uv1 = UV * wave_scale + vec2(t * 0.40,  t * 0.12);
	vec2 uv2 = UV * wave_scale * 0.75 + vec2(-t * 0.18, t * 0.30);

	float wave1 = fbm(uv1, 3);
	float wave2 = fbm(uv2, 3);
	float wave  = mix(wave1, wave2, 0.5);

	// UV distortion for refraction-like wobble
	vec2 distort = vec2(
		sin(UV.y * 18.0 + t * 2.2) * distort_amt,
		cos(UV.x * 14.0 + t * 1.8) * distort_amt * 0.5
	);
	vec2 distorted_uv = UV + distort;

	// Sample deep texture for sub-surface colour
	vec4 deep_sample = texture(deep_texture, distorted_uv * 1.5 + vec2(t * 0.05, 0.0));

	// Mix shallow / deep based on depth_fade and wave height
	float depth_t = clamp(depth_fade + (wave - 0.5) * 0.4, 0.0, 1.0);
	vec4 water_col = mix(shallow_color, deep_color, depth_t);
	water_col = mix(water_col, deep_sample * deep_color * 1.3, 0.25);

	// Sky reflection band (top portion of sprite = water near shore = more sky)
	float refl_mask = clamp(1.0 - UV.y * 2.5, 0.0, 1.0);
	// Animated shimmer in reflection
	float shimmer = sin(UV.x * 30.0 + t * 3.5) * 0.5 + 0.5;
	shimmer *= sin(UV.x * 17.0 - t * 2.1) * 0.5 + 0.5;
	vec4 refl_col = sky_reflection * (0.7 + shimmer * 0.3);
	water_col = mix(water_col, refl_col, refl_mask * reflection_strength);

	// Foam on wave crests
	float foam = smoothstep(foam_thresh, foam_thresh + 0.12, wave);
	// Animated foam edge
	float foam_anim = sin(UV.x * 40.0 + t * 4.0) * 0.5 + 0.5;
	foam *= 0.6 + foam_anim * 0.4;
	water_col = mix(water_col, foam_color, foam);

	// Specular glints: small bright points on wave peaks
	float spec = wave1 * wave2;
	float glint = smoothstep(0.88, 0.96, spec) * (shimmer * 0.5 + 0.5);
	water_col.rgb = mix(water_col.rgb, vec3(0.95, 0.98, 1.0), glint * 0.7);

	// Depth-based alpha (edges of water body fade out)
	float edge_fade = smoothstep(0.0, 0.06, UV.x)
		* smoothstep(1.0, 0.94, UV.x)
		* smoothstep(0.0, 0.04, UV.y)
		* smoothstep(1.0, 0.96, UV.y);

	COLOR = water_col;
	COLOR.a *= edge_fade;
}
