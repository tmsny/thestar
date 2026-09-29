extends Control

@onready var health_value: ProgressBar = $TopPanel/Margin/TopRow/HealthRow/HealthBar
@onready var health_text: Label = $TopPanel/Margin/TopRow/HealthRow/HealthText
@onready var weapon_name: Label = $AmmoPanel/AmmoMargin/AmmoColumn/WeaponName
@onready var ammo_text: Label = $AmmoPanel/AmmoMargin/AmmoColumn/AmmoText
@onready var score_text: Label = $TopPanel/Margin/TopRow/ScoreText
@onready var status_text: Label = $StatusText

func set_status(text: String) -> void:
	status_text.text = text

func update_hud(health: int, weapon: String, ammo: int, clip: int, score: int, reloading: bool) -> void:
	health_value.value = health
	health_text.text = "%d  /  100" % health
	weapon_name.text = weapon
	ammo_text.text = "NACHLADEN" if reloading else "%02d  /  %02d" % [ammo, clip]
	score_text.text = "TREFFER   %03d" % score

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var c: Color = Color(0.95, 0.98, 0.88, 0.95)
	var gap: float = 7.0
	var arm: float = 9.0
	draw_line(center + Vector2(-gap - arm, 0), center + Vector2(-gap, 0), c, 2.0, true)
	draw_line(center + Vector2(gap, 0), center + Vector2(gap + arm, 0), c, 2.0, true)
	draw_line(center + Vector2(0, -gap - arm), center + Vector2(0, -gap), c, 2.0, true)
	draw_line(center + Vector2(0, gap), center + Vector2(0, gap + arm), c, 2.0, true)
	draw_circle(center, 1.8, Color(1.0, 0.38, 0.12))
