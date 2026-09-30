shader_type canvas_item;

// Sniper scope overlay: a round vignette around the screen centre with a
// crosshair reticle in the middle. The centre stays fully transparent.

uniform float radius_frac : hint_range(0.1, 0.49) = 0.42;
uniform vec4 ring_color : source_color = vec4(0.0, 0.0, 0.0, 0.86);
uniform vec4 reticle_color : source_color = vec4(0.85, 0.98, 0.9, 0.9);

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = (UV - vec2(0.5)) * res;
	float radius = min(res.x, res.y) * radius_frac;
	float d = length(p);
	float edge = smoothstep(radius - 1.5, radius + 1.5, d);

	vec3 col = ring_color.rgb;
	float alpha = ring_color.a * edge;

	float inside = 1.0 - edge;
	float arm = 1.5;
	float vline = step(abs(p.x), arm);
	float hline = step(abs(p.y), arm);
	float gap = step(12.0, max(abs(p.x), abs(p.y)));
	float ret = clamp(vline + hline, 0.0, 1.0) * gap * inside;

	col = mix(col, reticle_color.rgb, ret * reticle_color.a);
	alpha = max(alpha, ret * reticle_color.a);
	COLOR = vec4(col, alpha);
}