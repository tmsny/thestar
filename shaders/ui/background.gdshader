shader_type canvas_item;

// Hintergrund fuer die Menues: Farbverlauf + zwei weiche Tuerkis-Glows,
// feine Scanlines und eine Vignette. Bewusst kein flacher Godot-Standardlook.

uniform vec4 col_top : source_color = vec4(0.03, 0.062, 0.092, 1.0);
uniform vec4 col_bottom : source_color = vec4(0.006, 0.012, 0.026, 1.0);
uniform vec4 accent : source_color = vec4(0.24, 0.9, 0.8, 1.0);
uniform float glow_amount = 0.16;

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(col_top.rgb, col_bottom.rgb, smoothstep(0.0, 1.0, uv.y));
	col += accent.rgb * smoothstep(0.9, 0.0, distance(uv, vec2(0.16, 0.08))) * glow_amount;
	col += accent.rgb * smoothstep(0.8, 0.0, distance(uv, vec2(0.92, 1.02))) * (glow_amount * 0.6);
	col += vec3(0.012) * step(0.5, fract(FRAGCOORD.y * 0.5));
	float vig = smoothstep(1.4, 0.35, distance(uv, vec2(0.5)));
	col *= mix(0.7, 1.05, vig);
	COLOR = vec4(col, 1.0);
}