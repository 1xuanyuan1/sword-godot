shader_type canvas_item;
render_mode unshaded;

uniform sampler2D palette_texture : filter_nearest, repeat_disable;
uniform float palette_mix : hint_range(0.0, 1.0) = 1.0;
uniform float global_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 encoded = texture(TEXTURE, UV);
	float palette_x = (floor(encoded.r * 255.0 + 0.5) + 0.5) / 256.0;
	vec4 mapped = texture(palette_texture, vec2(palette_x, 0.5));
	vec3 fallback = vec3(encoded.r);
	COLOR = vec4(mix(fallback, mapped.rgb, palette_mix), encoded.g * global_alpha);
}
