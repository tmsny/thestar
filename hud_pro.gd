extends Control

@onready var health_bar: ProgressBar = $Vitals/VitalsMargin/VitalsColumn/HealthBar
@onready var health_number: Label = $Vitals/VitalsMargin/VitalsColumn/HealthNumber
@onready var weapon_label: Label = $WeaponPanel/WeaponMargin/WeaponColumn/WeaponName
@onready var ammo_label: Label = $WeaponPanel/WeaponMargin/WeaponColumn/AmmoNumber
@onready var score_label: Label = $ScorePanel/ScoreMargin/ScoreColumn/ScoreNumber
@onready var reload_label: Label = $WeaponPanel/WeaponMargin/WeaponColumn/ReloadLabel

var hit_flash: float = 0.0

func update_hud(health: int, weapon: String, ammo: int, capacity: int, score: int, reloading: bool) -> void:
	health_bar.value = health
	health_number.text = "%03d" % health
	weapon_label.text = weapon
	ammo_label.text = "%02d  /  %02d" % [ammo, capacity]
	score_label.text = "%03d" % score
	reload_label.visible = reloading
	queue_redraw()

func set_hit(active: bool) -> void:
	hit_flash = 0.24 if active else 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta)
		queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var aim_color: Color = Color(0.95, 0.98, 0.93, 0.9)
	var g: float = 6.0
	var l: float = 8.0
	if hit_flash > 0.0:
		aim_color = Color(1.0, 0.36, 0.18, 1.0)
		g = 2.0
		l = 13.0
	draw_line(center + Vector2(-g-l, 0), center + Vector2(-g, 0), aim_color, 2.0, true)
	draw_line(center + Vector2(g, 0), center + Vector2(g+l, 0), aim_color, 2.0, true)
	draw_line(center + Vector2(0, -g-l), center + Vector2(0, -g), aim_color, 2.0, true)
	draw_line(center + Vector2(0, g), center + Vector2(0, g+l), aim_color, 2.0, true)
	draw_circle(center, 1.5, Color(0.98, 0.6, 0.18))
