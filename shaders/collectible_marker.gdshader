shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 encoded = texture(TEXTURE, UV);
	float intensity = floor(encoded.r * 255.0 + 0.5) / 255.0;
	vec3 amber = vec3(0.96, 0.50, 0.08);
	vec3 gold = vec3(1.0, 0.82, 0.24);
	vec3 white = vec3(1.0, 0.98, 0.82);
	vec3 color = mix(amber, gold, smoothstep(0.20, 0.70, intensity));
	color = mix(color, white, smoothstep(0.72, 0.98, intensity));
	float wave = 0.5 + 0.5 * sin(TIME * 5.23598776);
	float pulse = mix(0.65, 1.0, wave);
	float core = smoothstep(0.85, 1.0, intensity);
	COLOR = vec4(color, encoded.g * mix(pulse, 1.0, core));
}
