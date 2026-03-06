shader_type canvas_item;

// Dynamic sky shader for Alaskan environment.
// Blends time-of-day gradient with animated cloud wisps and subtle noise.

uniform sampler2D sky_texture    : repeat_enable, filter_linear;
uniform sampler2D cloud_texture  : repeat_enable, filter_linear;
uniform sampler2D aurora_texture : repeat_enable, filter_linear;

// Time-of-day colors — driven by environment controller via uniform
uniform vec4 zenith_color  : source_color = vec4(0.16, 0.32, 0.58, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.67, 0.78, 0.88, 1.0);
uniform vec4 glow_color    : source_color = vec4(0.86, 0.82, 0.74, 1.0);  // horizon warmth
uniform float glow_strength = 0.4;  // 0=no warmth, 1=vivid sunset/sunrise

uniform float cloud_speed   = 0.018;
uniform float cloud_opacity = 0.55;
uniform float aurora_opacity = 0.0;   // 0=day, 0..1 at night

void fragment() {
	// Vertical gradient: zenith → horizon → glow
	float t = UV.y;                          // 0=top, 1=bottom
	vec4 sky_grad;
	if (t < 0.55) {
		sky_grad = mix(zenith_color, horizon_color, t / 0.55);
	} else {
		float glow_t = (t - 0.55) / 0.45;
		sky_grad = mix(horizon_color, glow_color, glow_t * glow_strength);
	}

	// Subtle procedural texture variation
	vec4 tex_sample = texture(sky_texture, UV * vec2(2.0, 1.0) + vec2(TIME * 0.005, 0.0));
	sky_grad.rgb += (tex_sample.rgb - 0.5) * 0.04;

	// Cloud layer — two scrolling offsets for parallax
	vec2 cloud_uv1 = UV * vec2(1.8, 1.2) + vec2(TIME * cloud_speed, 0.0);
	vec2 cloud_uv2 = UV * vec2(1.1, 0.9) + vec2(-TIME * cloud_speed * 0.6, TIME * cloud_speed * 0.15);
	vec4 cloud1 = texture(cloud_texture, cloud_uv1);
	vec4 cloud2 = texture(cloud_texture, cloud_uv2);
	float cloud_mask = max(cloud1.a, cloud2.a) * cloud_opacity;
	// Clouds are lighter near horizon
	float cloud_brightness = 0.88 + UV.y * 0.12;
	vec3 cloud_col = vec3(cloud_brightness);
	sky_grad.rgb = mix(sky_grad.rgb, cloud_col, cloud_mask * (1.0 - UV.y * 0.4));

	// Aurora (visible at night near top of sky)
	if (aurora_opacity > 0.01) {
		vec2 aurora_uv = UV * vec2(1.0, 2.5) + vec2(TIME * 0.008, 0.0);
		vec4 aurora = texture(aurora_texture, aurora_uv);
		float aurora_mask = aurora.a * aurora_opacity * (1.0 - UV.y * 1.5);
		sky_grad.rgb = mix(sky_grad.rgb, aurora.rgb * 1.4, clamp(aurora_mask, 0.0, 1.0));
	}

	COLOR = sky_grad;
}
