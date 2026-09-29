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
	# Dunkle Outline sorgt fuer Kontrast auf jedem Hintergrund.
	var outline: Color = Color(0.02, 0.03, 0.05, 0.55)
	# Helles, leicht ins Teal getoentes Kreuz passend zum HUD.
	var aim_color: Color = Color(0.94, 0.99, 0.96, 0.95)
	var accent: Color = Color(0.34, 0.9, 0.82, 1.0)
	var g: float = 6.0
	var l: float = 9.0
	var w: float = 2.0
	if hit_flash > 0.0:
		aim_color = Color(1.0, 0.42, 0.22, 1.0)
		accent = Color(1.0, 0.72, 0.32, 1.0)
		outline = Color(0.25, 0.06, 0.02, 0.6)
		g = 3.0
		l = 13.0
		w = 2.5
	var arms: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	# Erste Schicht: Outline, damit die Arme auch auf hellen Flaechen lesbar sind.
	for dir: Vector2 in arms:
		draw_line(center + dir * g, center + dir * (g + l), outline, w + 2.0, true)
	# Zweite Schicht: leuchtende Arme.
	for dir: Vector2 in arms:
		draw_line(center + dir * g, center + dir * (g + l), aim_color, w, true)
	# Akzentpunkte an den Armspitzen.
	for dir: Vector2 in arms:
		draw_circle(center + dir * (g + l + 1.5), 1.1, accent)
	# Zentrum: Ring + Punkt.
	draw_circle(center, 2.7, outline)
	draw_arc(center, 2.0, 0.0, TAU, 24, aim_color, 1.2, true)
	draw_circle(center, 1.3, accent)
