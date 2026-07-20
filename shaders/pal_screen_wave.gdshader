shader_type canvas_item;
render_mode unshaded;

uniform float wave_strength = 0.0;
uniform float phase = 0.0;

void fragment() {
	float slot = mod(floor(UV.y * 200.0) + floor(phase), 32.0);
	float half_slot = mod(slot, 16.0);
	float curve = 256.0 - 4.0 * (half_slot - 7.0) * (half_slot - 7.0);
	float offset_pixels = curve * wave_strength / 256.0;
	if (slot >= 16.0) {
		offset_pixels = -offset_pixels;
	}
	vec2 sample_uv = UV;
	sample_uv.x = fract(sample_uv.x + offset_pixels / 320.0);
	COLOR = texture(TEXTURE, sample_uv);
}
