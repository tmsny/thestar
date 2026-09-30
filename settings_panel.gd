class_name SettingsPanel
extends Control

## Reusable settings UI. Emits `closed` when the player goes back.

signal closed

const PANEL_WIDTH: float = 620.0

var _sens_slider: HSlider
var _sens_value: Label
var _fov_slider: HSlider
var _fov_value: Label
var _volume_slider: HSlider
var _volume_value: Label
var _difficulty_option: OptionButton
var _invert_check: CheckBox
var _slot_options: Array[OptionButton] = []

func _ready() -> void:
	GameConfig.ensure_loaded()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

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
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.07, 0.96)
	style.border_color = Color(0.15, 0.72, 0.68, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 30.0
	style.content_margin_right = 30.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var title: Label = Label.new()
	title.text = "EINSTELLUNGEN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.47, 0.9, 0.83))
	column.add_child(title)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 360.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var body: VBoxContainer = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)

	body.add_child(_section("STEUERUNG"))
	_sens_slider = _add_slider(body, "Maus-Empfindlichkeit", 0.0005, 0.006, 0.0001, GameConfig.sensitivity)
	_sens_value = _slider_value_label(_sens_slider, body, "%.4f")
	_sens_slider.value_changed.connect(func(value: float) -> void:
		GameConfig.sensitivity = value
		_sens_value.text = "%.4f" % value
		GameConfig.save_config())

	_invert_check = CheckBox.new()
	_invert_check.text = "Y-Achse invertieren"
	_invert_check.button_pressed = GameConfig.invert_y
	_invert_check.add_theme_font_size_override("font_size", 16)
	_invert_check.toggled.connect(func(pressed: bool) -> void:
		GameConfig.invert_y = pressed
		GameConfig.save_config())
	body.add_child(_labelled(body, "Y-Achse", _invert_check))

	body.add_child(_section("BILD"))
	_fov_slider = _add_slider(body, "Sichtfeld (FOV)", 60.0, 110.0, 1.0, GameConfig.fov)
	_fov_value = _slider_value_label(_fov_slider, body, "%.0f°")
	_fov_slider.value_changed.connect(func(value: float) -> void:
		GameConfig.fov = value
		_fov_value.text = "%.0f°" % value
		GameConfig.save_config())

	body.add_child(_section("AUDIO"))
	_volume_slider = _add_slider(body, "Lautstärke", 0.0, 1.0, 0.01, GameConfig.master_volume)
	_volume_value = _slider_value_label(_volume_slider, body, "%.0f%%")
	_volume_slider.value_changed.connect(func(value: float) -> void:
		GameConfig.master_volume = value
		_volume_value.text = "%d%%" % roundi(value * 100.0)
		GameConfig.apply()
		GameConfig.save_config())

	body.add_child(_section("SPIEL"))
	_difficulty_option = OptionButton.new()
	for difficulty_name: String in GameConfig.DIFFICULTY_NAMES:
		_difficulty_option.add_item(difficulty_name)
	_difficulty_option.selected = GameConfig.difficulty
	_difficulty_option.item_selected.connect(func(index: int) -> void:
		GameConfig.difficulty = index
		GameConfig.save_config())
	body.add_child(_labelled(body, "Schwierigkeit", _difficulty_option))

	body.add_child(_section("WAFFEN-SLOTS  (welche Waffe auf Taste 1–4)"))
	var slot_grid: GridContainer = GridContainer.new()
	slot_grid.columns = 2
	slot_grid.add_theme_constant_override("h_separation", 22)
	slot_grid.add_theme_constant_override("v_separation", 8)
	body.add_child(slot_grid)
	for slot: int in range(4):
		var label: Label = Label.new()
		label.text = "Taste %d" % (slot + 1)
		label.add_theme_font_size_override("font_size", 16)
		slot_grid.add_child(label)
		var option: OptionButton = OptionButton.new()
		for weapon_name: String in GameConfig.WEAPON_NAMES:
			option.add_item(weapon_name)
		option.selected = GameConfig.weapon_slots[slot]
		option.item_selected.connect(func(index: int) -> void:
			GameConfig.weapon_slots[slot] = index
			GameConfig.save_config())
		slot_grid.add_child(option)
		_slot_options.append(option)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	column.add_child(buttons)

	var reset: Button = Button.new()
	reset.text = "ZURÜCKSETZEN"
	reset.custom_minimum_size = Vector2(180.0, 44.0)
	reset.pressed.connect(_on_reset)
	buttons.add_child(reset)

	var back: Button = Button.new()
	back.text = "ZURÜCK"
	back.custom_minimum_size = Vector2(180.0, 44.0)
	back.pressed.connect(func() -> void: closed.emit())
	buttons.add_child(back)

func _on_reset() -> void:
	GameConfig.reset_defaults()
	_sens_slider.value = GameConfig.sensitivity
	_sens_value.text = "%.4f" % GameConfig.sensitivity
	_fov_slider.value = GameConfig.fov
	_fov_value.text = "%.0f°" % GameConfig.fov
	_volume_slider.value = GameConfig.master_volume
	_volume_value.text = "%d%%" % roundi(GameConfig.master_volume * 100.0)
	_difficulty_option.selected = GameConfig.difficulty
	_invert_check.button_pressed = GameConfig.invert_y
	for slot: int in range(_slot_options.size()):
		_slot_options[slot].selected = GameConfig.weapon_slots[slot]

func _section(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.55, 0.8, 0.85))
	return label

func _labelled(_column: VBoxContainer, text: String, control: Control = null) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(240.0, 0.0)
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)
	if control != null:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(control)
	return row

func _add_slider(parent: VBoxContainer, text: String, min_value: float, max_value: float, step: float, value: float) -> HSlider:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(180.0, 0.0)
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(260.0, 0.0)
	row.add_child(slider)
	parent.add_child(row)
	return slider

func _slider_value_label(slider: HSlider, _parent: VBoxContainer, format: String) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	if format == "%.0f%%":
		label.text = "%d%%" % roundi(slider.value * 100.0)
	else:
		label.text = format % slider.value
	# Attach the value label into the slider's row.
	var row: Node = slider.get_parent()
	var index: int = slider.get_index()
	(row as HBoxContainer).add_child(label)
	(row as HBoxContainer).move_child(label, index + 1)
	return label