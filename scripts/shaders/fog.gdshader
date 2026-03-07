shader_type canvas_item;

// Volumetric-style 2D fog / atmosphere shader.
// Creates layered mist bands that drift horizontally with gentle variation.

uniform sampler2D fog_texture : repeat_enable, filter_linear;
uniform vec4 fog_color : source_color = vec4(0.82, 0.88, 0.95, 1.0);
uniform float fog_speed    = 0.04;
uniform float fog_density  = 0.65;
uniform float fog_height   = 0.5;    // fraction of sprite height covered
uniform float noise_scale  = 1.8;
uniform float vertical_fade = 1.5;   // how quickly fog fades upward

void fragment() {
	// Two scrolling layers at different speeds for parallax depth
	vec2 uv1 = UV * vec2(noise_scale, noise_scale * 0.5)
			   + vec2(TIME * fog_speed, TIME * fog_speed * 0.12);
	vec2 uv2 = UV * vec2(noise_scale * 0.65, noise_scale * 0.4)
			   + vec2(-TIME * fog_speed * 0.55, TIME * fog_speed * 0.08);

	float n1 = texture(fog_texture, uv1).r;
	float n2 = texture(fog_texture, uv2).r;
	float fog_n = (n1 * 0.6 + n2 * 0.4);

	// Vertical mask: dense at bottom, fades upward
	float vert_mask = pow(clamp(1.0 - UV.y / fog_height, 0.0, 1.0), vertical_fade);

	// Combined alpha
	float alpha = fog_n * vert_mask * fog_density;

	// Slight colour variation — cooler in shadows, warmer near ground
	vec3 col = fog_color.rgb;
	col = mix(col, col * vec3(0.88, 0.92, 1.05), 1.0 - vert_mask);

	COLOR = vec4(col, clamp(alpha, 0.0, 0.88));
}
