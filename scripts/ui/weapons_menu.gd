class_name WeaponsMenu
extends Control

## Waffen-Menue: Liste aller Waffen mit Statistiken und einem selbst rotierenden
## 3D-Modell der ausgewaehlten Waffe. Bietet "TESTEN" (Testwelt) und das
## Ausruesten einer Waffe auf einen der vier Slots.

signal closed

const VIEWMODEL_SCRIPT: Script = preload("res://scripts/weapons/gun_viewmodel.gd")
const TEST_SCENE: String = "res://scenes/gameplay/test_range.tscn"
const PANEL_WIDTH: float = 960.0

var _selected: int = 0
var _weapon_buttons: Array[Button] = []
var _slot_buttons: Array[Button] = []
var _stats_label: Label
var _viewport: SubViewport
var _turntable: Node3D
var _viewmodel: Node3D

func _ready() -> void:
	GameConfig.ensure_loaded()
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if GameConfig.weapon_slots.size() != 4:
		GameConfig.weapon_slots = [0, 1, 2, 3]
	_select_weapon(GameConfig.weapon_slots[0])

func _process(delta: float) -> void:
	if _turntable != null:
		_turntable.rotate_y(delta * 1.1)

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	center.add_child(panel)

	var panel_margin: MarginContainer = MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 26)
	panel_margin.add_theme_constant_override("margin_right", 26)
	panel_margin.add_theme_constant_override("margin_top", 18)
	panel_margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(panel_margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel_margin.add_child(column)

	var title: Label = Label.new()
	title.text = "WAFFEN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	column.add_child(title)

	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	column.add_child(body)

	# --- Linke Seite: Liste aller Waffen ---
	var list_scroll: ScrollContainer = ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(300.0, 472.0)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(list_scroll)

	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	list_scroll.add_child(list)

	for i: int in range(WeaponData.COUNT):
		var button: Button = Button.new()
		button.text = "%d.  %s" % [i + 1, GameConfig.WEAPON_NAMES[i]]
		button.custom_minimum_size = Vector2(272.0, 40.0)
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 17)
		var weapon_id: int = i
		button.pressed.connect(func() -> void: _select_weapon(weapon_id))
		list.add_child(button)
		_weapon_buttons.append(button)

	# --- Rechte Seite: rotierendes Modell + Statistiken ---
	var right: VBoxContainer = VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)

	var preview_frame: PanelContainer = PanelContainer.new()
	var frame_style: StyleBoxFlat = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.05, 0.08, 0.1, 0.95)
	frame_style.border_color = Color(0.2, 0.4, 0.42, 0.9)
	frame_style.set_border_width_all(1)
	frame_style.set_corner_radius_all(10)
	frame_style.content_margin_left = 6.0
	frame_style.content_margin_right = 6.0
	frame_style.content_margin_top = 6.0
	frame_style.content_margin_bottom = 6.0
	preview_frame.add_theme_stylebox_override("panel", frame_style)
	right.add_child(preview_frame)

	var viewport_container: SubViewportContainer = SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(592.0, 322.0)
	viewport_container.stretch = true
	preview_frame.add_child(viewport_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(592, 322)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	viewport_container.add_child(_viewport)

	_setup_preview_world()

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 18)
	_stats_label.add_theme_color_override("font_color", Color(0.9, 0.94, 0.92))
	_stats_label.custom_minimum_size = Vector2(592.0, 0.0)
	right.add_child(_stats_label)

	var slot_row: HBoxContainer = HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 10)
	right.add_child(slot_row)
	for slot: int in range(4):
		var slot_button: Button = Button.new()
		slot_button.custom_minimum_size = Vector2(0.0, 38.0)
		slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_button.focus_mode = Control.FOCUS_NONE
		slot_button.add_theme_font_size_override("font_size", 15)
		var slot_index: int = slot
		slot_button.pressed.connect(func() -> void: _equip_to_slot(slot_index))
		slot_row.add_child(slot_button)
		_slot_buttons.append(slot_button)

	# --- Untere Buttons ---
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	column.add_child(buttons)

	var test: Button = Button.new()
	test.text = "TESTEN"
	test.custom_minimum_size = Vector2(200.0, 46.0)
	test.focus_mode = Control.FOCUS_NONE
	test.add_theme_font_size_override("font_size", 20)
	test.pressed.connect(_on_test)
	buttons.add_child(test)

	var back: Button = Button.new()
	back.text = "ZURÜCK"
	back.custom_minimum_size = Vector2(200.0, 46.0)
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(func() -> void: closed.emit())
	buttons.add_child(back)

func _setup_preview_world() -> void:
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.06, 0.08, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.68, 0.72)
	env.ambient_light_energy = 0.9
	environment_node.environment = env
	_viewport.add_child(environment_node)

	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.light_energy = 1.15
	key_light.rotation_degrees = Vector3(-40.0, 38.0, 0.0)
	_viewport.add_child(key_light)

	var fill_light: DirectionalLight3D = DirectionalLight3D.new()
	fill_light.light_energy = 0.5
	fill_light.rotation_degrees = Vector3(-16.0, -140.0, 0.0)
	_viewport.add_child(fill_light)

	_turntable = Node3D.new()
	_turntable.name = "Turntable"
	_turntable.position = Vector3(0.0, 0.0, 0.0)
	_viewport.add_child(_turntable)

	_viewmodel = Node3D.new()
	_viewmodel.name = "Viewmodel"
	_viewmodel.set_script(VIEWMODEL_SCRIPT)
	_turntable.add_child(_viewmodel)
	# Eigene Bewegung aus, damit die Waffe still steht und nur der Teller dreht.
	_viewmodel.call("build_weapon", 0)
	_viewmodel.set_process(false)
	_viewmodel.position = Vector3(0.0, 0.04, 0.0)
	_viewmodel.rotation = Vector3(0.0, 0.0, 0.0)
	_viewmodel.scale = Vector3(1.25, 1.25, 1.25)

	var camera: Camera3D = Camera3D.new()
	camera.current = true
	camera.position = Vector3(0.0, 0.1, 1.3)
	camera.fov = 48.0
	_viewport.add_child(camera)
	camera.look_at(Vector3(0.0, -0.06, -0.3), Vector3.UP)

func _select_weapon(index: int) -> void:
	_selected = clampi(index, 0, WeaponData.COUNT - 1)
	if _viewmodel != null:
		_viewmodel.call("build_weapon", _selected)
	for i: int in range(_weapon_buttons.size()):
		var active: bool = i == _selected
		_weapon_buttons[i].add_theme_color_override("font_color", Color(0.45, 0.95, 0.86) if active else Color(0.82, 0.88, 0.9))
		_weapon_buttons[i].modulate = Color(1.0, 1.0, 1.0, 1.0) if active else Color(0.82, 0.86, 0.88, 0.8)
	_refresh_stats()
	_refresh_slots()

func _refresh_stats() -> void:
	if _stats_label == null:
		return
	var i: int = _selected
	var shots: float = WeaponData.shots_per_second(i)
	var fire_text: String = "-"
	if shots > 0.0:
		fire_text = "%.2f Schuss/s" % shots
	_stats_label.text = "%s\nSchaden: %d    Kopfschuss: ×%.1f (%d)    Magazin: %s\nFeuerrate: %s    Modus: %s" % [
		GameConfig.WEAPON_NAMES[i],
		WeaponData.damage(i),
		WeaponData.head_mult(i),
		int(round(WeaponData.damage(i) * WeaponData.head_mult(i))),
		WeaponData.ammo_text(i),
		fire_text,
		WeaponData.mode_text(i),
	]

func _refresh_slots() -> void:
	for slot: int in range(_slot_buttons.size()):
		var wid: int = GameConfig.weapon_slots[slot] if slot < GameConfig.weapon_slots.size() else -1
		var weapon_name: String = GameConfig.WEAPON_NAMES[wid] if wid >= 0 else "-"
		_slot_buttons[slot].text = "Slot %d: %s" % [slot + 1, weapon_name]

func _equip_to_slot(slot: int) -> void:
	if slot < 0 or slot >= 4:
		return
	if GameConfig.weapon_slots.size() != 4:
		GameConfig.weapon_slots = [0, 1, 2, 3]
	var existing_slot: int = GameConfig.weapon_slots.find(_selected)
	if existing_slot == slot:
		return
	if existing_slot >= 0:
		# Tauschen, damit keine Waffe doppelt belegt ist.
		GameConfig.weapon_slots[existing_slot] = GameConfig.weapon_slots[slot]
	GameConfig.weapon_slots[slot] = _selected
	GameConfig.save_config()
	_refresh_slots()

func _on_test() -> void:
	GameConfig.pending_weapon = _selected
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().change_scene_to_file(TEST_SCENE)
