extends Control

func _draw() -> void:
	var center: Vector2 = get_viewport_rect().size * 0.5
	var color: Color = Color(1.0, 0.88, 0.2, 0.95)
	var gap: float = 7.0
	var length: float = 9.0
	draw_line(center + Vector2(-gap - length, 0), center + Vector2(-gap, 0), color, 2.0, true)
	draw_line(center + Vector2(gap, 0), center + Vector2(gap + length, 0), color, 2.0, true)
	draw_line(center + Vector2(0, -gap - length), center + Vector2(0, -gap), color, 2.0, true)
	draw_line(center + Vector2(0, gap), center + Vector2(0, gap + length), color, 2.0, true)
	draw_circle(center, 1.8, color)
