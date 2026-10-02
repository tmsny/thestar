extends Control

const WEAPON_ICONS: Array[String] = [
	"res://assets/generated/weapon_icon_pistol.png",
	"res://assets/generated/weapon_icon_rifle.png",
	"res://assets/generated/weapon_icon_sniper.png",
	"res://assets/generated/weapon_icon_shotgun.png",
	"res://assets/generated/weapon_icon_energy_flat.png",
	"res://assets/generated/weapon_icon_knife_flat.png",
	"res://assets/generated/weapon_icon_burst_smg_flat.png",
	"res://assets/generated/weapon_icon_hand_cannon_flat.png",
	"res://assets/generated/weapon_icon_hammer_flat.png",
	"res://assets/generated/weapon_icon_grenade_launcher_flat.png",
]
const ICON_ACTIVE_BG: Color = Color(0.05, 0.15, 0.16, 0.92)
const ICON_IDLE_BG: Color = Color(0.02, 0.04, 0.05, 0.72)
const ICON_ACTIVE_BORDER: Color = Color(0.35, 0.95, 0.85, 0.95)
const ICON_IDLE_BORDER: Color = Color(0.2, 0.3, 0.34, 0.7)
const SCOPE_SHADER: Shader = preload("res://shaders/ui/scope.gdshader")

@onready var health_bar: ProgressBar = $Vitals/VitalsMargin/VitalsColumn/HealthBar
@onready var health_number: Label = $Vitals/VitalsMargin/VitalsColumn/HealthNumber
@onready var weapon_label: Label = $WeaponPanel/WeaponMargin/WeaponColumn/WeaponName
@onready var ammo_label: Label = $WeaponPanel/WeaponMargin/WeaponColumn/AmmoNumber
@onready var score_label: Label = $ScorePanel/ScoreMargin/ScoreColumn/ScoreNumber
@onready var reload_label: Label = $WeaponPanel/WeaponMargin/WeaponColumn/ReloadLabel
@onready var status_text: Label = $StatusText
@onready var controls_label: Label = $Controls

var hit_flash: float = 0.0
var aiming: bool = false
var scoped: bool = false
var scope_rect: ColorRect
var grenade_label: Label
var damage_label: Label

var weapon_slot: int = 0
var weapon_frames: Array[PanelContainer] = []
var weapon_icons: Array[TextureRect] = []
var weapon_styles: Array[StyleBoxFlat] = []

func _ready() -> void:
	theme = UiTheme.get_theme()
	_build_scope()
	_build_weapon_bar()
	_build_grenades()
	set_weapon_slot(0)
	_update_controls_hint()
	_build_damage_readout()

func _update_controls_hint() -> void:
	if controls_label == null:
		return
	controls_label.text = "%s/%s/%s/%s BEWEGEN · %s SPRUNG · %s DUCKEN · %s LEITER (halten) · LMB FEUERN · RMB ZIELEN · %s–%s WAFFEN · %s NACHLADEN · %s GRANATE" % [
		GameConfig.key_name("move_forward"), GameConfig.key_name("move_back"),
		GameConfig.key_name("move_left"), GameConfig.key_name("move_right"),
		GameConfig.key_name("jump"), GameConfig.key_name("crouch"),
		GameConfig.key_name("jump"),
		GameConfig.key_name("slot_1"), GameConfig.key_name("slot_4"),
		GameConfig.key_name("reload"), GameConfig.key_name("grenade"),
	]

func _build_weapon_bar() -> void:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.name = "WeaponBar"
	bar.anchor_left = 1.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -float(GameConfig.weapon_slots.size()) * 72.0 - 22.0
	bar.offset_right = -22.0
	bar.offset_top = -82.0
	bar.offset_bottom = -18.0
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", 10)
	add_child(bar)
	for i: int in range(GameConfig.weapon_slots.size()):
		var frame: PanelContainer = PanelContainer.new()
		frame.custom_minimum_size = Vector2(66.0, 58.0)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		style.content_margin_left = 8.0
		style.content_margin_right = 8.0
		style.content_margin_top = 5.0
		style.content_margin_bottom = 5.0
		frame.add_theme_stylebox_override("panel", style)
		var column: VBoxContainer = VBoxContainer.new()
		column.add_theme_constant_override("separation", 1)
		var icon: TextureRect = TextureRect.new()
		var weapon_id: int = GameConfig.weapon_slots[i]
		icon.texture = load(WEAPON_ICONS[weapon_id])
		icon.custom_minimum_size = Vector2(48.0, 34.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(icon)
		var key: Label = Label.new()
		key.text = GameConfig.key_name("slot_%d" % (i + 1))
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.add_theme_font_size_override("font_size", 13)
		key.add_theme_color_override("font_color", Color(0.72, 0.86, 0.86, 0.9))
		column.add_child(key)
		frame.add_child(column)
		bar.add_child(frame)
		weapon_frames.append(frame)
		weapon_icons.append(icon)
		weapon_styles.append(style)

func set_weapon_slot(index: int) -> void:
	weapon_slot = index
	for i: int in range(weapon_frames.size()):
		var active: bool = i == index
		weapon_styles[i].bg_color = ICON_ACTIVE_BG if active else ICON_IDLE_BG
		weapon_styles[i].border_color = ICON_ACTIVE_BORDER if active else ICON_IDLE_BORDER
		weapon_icons[i].modulate = Color(1.0, 1.0, 1.0, 1.0) if active else Color(0.72, 0.82, 0.82, 0.5)

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

func set_aim(active: bool) -> void:
	if aiming != active:
		aiming = active
		queue_redraw()

func set_status(text: String) -> void:
	status_text.text = text

func _build_scope() -> void:
	scope_rect = ColorRect.new()
	scope_rect.name = "Scope"
	scope_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SCOPE_SHADER
	scope_rect.material = mat
	scope_rect.visible = false
	add_child(scope_rect)
	# Keep the scope overlay behind every other HUD element so the health bar,
	# ammo panel and weapon icons stay readable while aiming down the scope.
	move_child(scope_rect, 0)

func set_scope(active: bool) -> void:
	if scope_rect == null:
		return
	if scoped != active:
		scoped = active
		scope_rect.visible = active
		queue_redraw()

func _build_grenades() -> void:
	grenade_label = Label.new()
	grenade_label.name = "Grenades"
	grenade_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	grenade_label.offset_left = 24.0
	grenade_label.offset_top = -46.0
	grenade_label.offset_right = 340.0
	grenade_label.offset_bottom = -20.0
	grenade_label.add_theme_font_size_override("font_size", 19)
	grenade_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.85, 0.92))
	grenade_label.text = "GRANATEN (%s)  ×3" % GameConfig.key_name("grenade")
	add_child(grenade_label)

func set_grenades(count: int) -> void:
	if grenade_label != null:
		grenade_label.text = "GRANATEN (%s)  ×%d" % [GameConfig.key_name("grenade"), count]

## Schadensanzeige unten am Bildschirm (z. B. "-72"), bleibt stehen.
func _build_damage_readout() -> void:
	damage_label = Label.new()
	damage_label.name = "DamageReadout"
	damage_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	damage_label.offset_left = -160.0
	damage_label.offset_right = 160.0
	damage_label.offset_top = -150.0
	damage_label.offset_bottom = -100.0
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	damage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_label.add_theme_font_size_override("font_size", 44)
	damage_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	damage_label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.03, 0.95))
	damage_label.add_theme_constant_override("outline_size", 7)
	damage_label.text = ""
	add_child(damage_label)

func show_damage(amount: int) -> void:
	if damage_label == null:
		return
	damage_label.text = "-%d" % amount

func _process(delta: float) -> void:
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta)
		queue_redraw()

func _draw() -> void:
	if scoped:
		return
	var center: Vector2 = size * 0.5
	var aim_color: Color = Color(0.95, 0.98, 0.93, 0.9)
	var g: float = 6.0
	var l: float = 8.0
	if hit_flash > 0.0:
		aim_color = Color(1.0, 0.36, 0.18, 1.0)
		g = 2.0
		l = 13.0
	elif aiming:
		aim_color = Color(0.55, 1.0, 0.75, 0.95)
		g = 2.5
		l = 5.5
	draw_line(center + Vector2(-g-l, 0), center + Vector2(-g, 0), aim_color, 2.0, true)
	draw_line(center + Vector2(g, 0), center + Vector2(g+l, 0), aim_color, 2.0, true)
	draw_line(center + Vector2(0, -g-l), center + Vector2(0, -g), aim_color, 2.0, true)
	draw_line(center + Vector2(0, g), center + Vector2(0, g+l), aim_color, 2.0, true)
	draw_circle(center, 1.5, Color(0.98, 0.6, 0.18))
