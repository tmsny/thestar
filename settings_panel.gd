class_name SettingsPanel
extends Control

## Einstellungen in kollabierbaren Kategorien (Akkordeon). Emittiert `closed`.

signal closed

const PANEL_WIDTH: float = 660.0

var _sens_slider: HSlider
var _sens_value: Label
var _fov_slider: HSlider
var _fov_value: Label
var _volume_slider: HSlider
var _volume_value: Label
var _difficulty_option: OptionButton
var _invert_toggle: Button
var _fullscreen_toggle: Button
var _binding_buttons: Dictionary = {}
var _listening_action: String = ""

func _ready() -> void:
	GameConfig.ensure_loaded()
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	center.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	column.add_child(header_row)
	var title: Label = Label.new()
	title.text = "EINSTELLUNGEN"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	header_row.add_child(title)
	var badge: Label = Label.new()
	badge.text = "TEST STAR"
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	header_row.add_child(badge)

	column.add_child(_divider(0.35, 2.0))

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 430.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var body: VBoxContainer = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)

	# --- STEUERUNG ---
	var ctl: VBoxContainer = _add_section(body, "STEUERUNG", true)
	_sens_slider = _add_slider(ctl, "Maus-Empfindlichkeit", 0.0005, 0.006, 0.0001, GameConfig.sensitivity)
	_sens_value = _slider_value_label(_sens_slider, "%.4f")
	_sens_slider.value_changed.connect(func(value: float) -> void:
		GameConfig.sensitivity = value
		_sens_value.text = "%.4f" % value
		GameConfig.save_config())
	_invert_toggle = Button.new()
	_invert_toggle.toggle_mode = true
	_invert_toggle.button_pressed = GameConfig.invert_y
	_invert_toggle.focus_mode = Control.FOCUS_NONE
	_invert_toggle.custom_minimum_size = Vector2(96.0, 34.0)
	_invert_toggle.toggled.connect(func(pressed: bool) -> void:
		GameConfig.invert_y = pressed
		_refresh_invert_text()
		GameConfig.save_config())
	_refresh_invert_text()
	_value_row(ctl, "Y-Achse invertieren", _invert_toggle)

	# --- TASTENBELEGUNG ---
	var keys: VBoxContainer = _add_section(body, "TASTENBELEGUNG", false)
	var key_hint: Label = Label.new()
	key_hint.text = "Auf eine Taste klicken, dann die neue Taste drücken."
	key_hint.add_theme_font_size_override("font_size", 13)
	key_hint.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	keys.add_child(key_hint)
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "reload", "grenade", "slot_1", "slot_2", "slot_3", "slot_4", "fullscreen"]:
		_add_binding_row(keys, action)

	# --- BILD ---
	var video: VBoxContainer = _add_section(body, "BILD", false)
	_fov_slider = _add_slider(video, "Sichtfeld (FOV)", 60.0, 110.0, 1.0, GameConfig.fov)
	_fov_value = _slider_value_label(_fov_slider, "%.0f°")
	_fov_slider.value_changed.connect(func(value: float) -> void:
		GameConfig.fov = value
		_fov_value.text = "%.0f°" % value
		GameConfig.save_config())
	_fullscreen_toggle = Button.new()
	_fullscreen_toggle.toggle_mode = true
	_fullscreen_toggle.button_pressed = GameConfig.fullscreen
	_fullscreen_toggle.focus_mode = Control.FOCUS_NONE
	_fullscreen_toggle.custom_minimum_size = Vector2(96.0, 34.0)
	_fullscreen_toggle.toggled.connect(func(pressed: bool) -> void:
		GameConfig.set_fullscreen(pressed)
		_style_toggle(_fullscreen_toggle))
	_style_toggle(_fullscreen_toggle)
	_value_row(video, "Vollbild", _fullscreen_toggle)
	var fs_hint: Label = Label.new()
	fs_hint.text = "Hotkey: %s" % GameConfig.key_name("fullscreen")
	fs_hint.add_theme_font_size_override("font_size", 13)
	fs_hint.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	video.add_child(fs_hint)

	# --- AUDIO ---
	var audio: VBoxContainer = _add_section(body, "AUDIO", false)
	_volume_slider = _add_slider(audio, "Lautstärke", 0.0, 1.0, 0.01, GameConfig.master_volume)
	_volume_value = _slider_value_label(_volume_slider, "%.0f%%")
	_volume_slider.value_changed.connect(func(value: float) -> void:
		GameConfig.master_volume = value
		_volume_value.text = "%d%%" % roundi(value * 100.0)
		GameConfig.apply()
		GameConfig.save_config())

	# --- SPIEL ---
	var game: VBoxContainer = _add_section(body, "SPIEL", false)
	_difficulty_option = OptionButton.new()
	for difficulty_name: String in GameConfig.DIFFICULTY_NAMES:
		_difficulty_option.add_item(difficulty_name)
	_difficulty_option.selected = GameConfig.difficulty
	_difficulty_option.item_selected.connect(func(index: int) -> void:
		GameConfig.difficulty = index
		GameConfig.save_config())
	_value_row(game, "Schwierigkeit", _difficulty_option)

	# --- Fusszeile ---
	column.add_child(_divider(0.2, 1.0))
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	var reset: Button = Button.new()
	reset.text = "ZURÜCKSETZEN"
	reset.custom_minimum_size = Vector2(200.0, 46.0)
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(_on_reset)
	buttons.add_child(reset)
	var back: Button = Button.new()
	back.text = "ZURÜCK"
	back.custom_minimum_size = Vector2(200.0, 46.0)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void: closed.emit())
	buttons.add_child(back)

func _divider(alpha: float, height: float) -> ColorRect:
	var line: ColorRect = ColorRect.new()
	line.color = Color(UiTheme.ACCENT.r, UiTheme.ACCENT.g, UiTheme.ACCENT.b, alpha)
	line.custom_minimum_size = Vector2(0.0, height)
	return line

## Kollabierbare Kategorie. Gibt den Body-Container zum Befuellen zurueck.
func _add_section(parent: VBoxContainer, title: String, expanded: bool) -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	parent.add_child(section)

	var header: Button = Button.new()
	header.text = ("▾   " if expanded else "▸   ") + title
	header.set_meta("section_title", title)
	header.set_meta("open", expanded)
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.custom_minimum_size = Vector2(0.0, 44.0)
	header.focus_mode = Control.FOCUS_NONE
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", UiTheme.ACCENT)
	header.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	header.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL_BG_SOFT, UiTheme.BORDER, 10, 1, 18.0, 10.0))
	header.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.BUTTON_BG_HOVER, UiTheme.ACCENT_SOFT, 10, 1, 18.0, 10.0))
	header.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.BUTTON_BG_HOVER, UiTheme.ACCENT, 10, 1, 18.0, 10.0))
	header.add_theme_stylebox_override("focus", UiTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
	section.add_child(header)

	var inner: MarginContainer = MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 14)
	inner.add_theme_constant_override("margin_right", 8)
	inner.add_theme_constant_override("margin_top", 8)
	section.add_child(inner)

	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	inner.add_child(body)
	inner.visible = expanded
	header.pressed.connect(func() -> void: _toggle_section(header, inner))
	return body

func _toggle_section(header: Button, inner: MarginContainer) -> void:
	var open: bool = not bool(header.get_meta("open", false))
	header.set_meta("open", open)
	var title: String = String(header.get_meta("section_title", ""))
	header.text = ("▾   " if open else "▸   ") + title
	# Laufende Animation abbrechen, sonst ueberschreibt ihr Callback den neuen Zustand.
	if header.has_meta("tw"):
		var running: Tween = header.get_meta("tw")
		if running != null and is_instance_valid(running) and running.is_running():
			running.kill()
	if open:
		inner.visible = true
		inner.modulate.a = 0.0
		var show_tw: Tween = create_tween()
		show_tw.tween_property(inner, "modulate:a", 1.0, 0.18)
		header.set_meta("tw", show_tw)
	else:
		var hide_tw: Tween = create_tween()
		hide_tw.tween_property(inner, "modulate:a", 0.0, 0.12)
		hide_tw.tween_callback(func() -> void: inner.visible = false)
		header.set_meta("tw", hide_tw)

func _on_reset() -> void:
	GameConfig.reset_defaults()
	_sens_slider.value = GameConfig.sensitivity
	_sens_value.text = "%.4f" % GameConfig.sensitivity
	_fov_slider.value = GameConfig.fov
	_fov_value.text = "%.0f°" % GameConfig.fov
	_volume_slider.value = GameConfig.master_volume
	_volume_value.text = "%d%%" % roundi(GameConfig.master_volume * 100.0)
	_difficulty_option.selected = GameConfig.difficulty
	_invert_toggle.button_pressed = GameConfig.invert_y
	_refresh_invert_text()
	_fullscreen_toggle.button_pressed = GameConfig.fullscreen
	_style_toggle(_fullscreen_toggle)
	for action: String in _binding_buttons.keys():
		_refresh_binding_button(action)

func _refresh_invert_text() -> void:
	_style_toggle(_invert_toggle)

func _style_toggle(button: Button) -> void:
	if button == null:
		return
	button.text = "AN" if button.button_pressed else "AUS"
	button.add_theme_color_override("font_color", UiTheme.ACCENT if button.button_pressed else UiTheme.TEXT_MUTED)

func _add_binding_row(parent: VBoxContainer, action: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var label: Label = Label.new()
	label.text = GameConfig.BINDING_LABELS.get(action, action)
	label.custom_minimum_size = Vector2(240.0, 0.0)
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)
	var button: Button = Button.new()
	button.text = GameConfig.key_name(action)
	button.custom_minimum_size = Vector2(180.0, 34.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(func() -> void: _start_listening(action))
	row.add_child(button)
	parent.add_child(row)
	_binding_buttons[action] = button

func _start_listening(action: String) -> void:
	if _listening_action != "":
		_refresh_binding_button(_listening_action)
	_listening_action = action
	var button: Button = _binding_buttons.get(action)
	if button != null:
		button.text = "Taste drücken…"
		button.add_theme_color_override("font_color", UiTheme.WARN)

func _refresh_binding_button(action: String) -> void:
	var button: Button = _binding_buttons.get(action)
	if button != null:
		button.text = GameConfig.key_name(action)
		button.add_theme_color_override("font_color", UiTheme.TEXT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible and _listening_action != "":
		_refresh_binding_button(_listening_action)
		_listening_action = ""

func _input(event: InputEvent) -> void:
	if not visible or _listening_action == "":
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event: InputEventKey = event
	var key: int = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	var action: String = _listening_action
	_listening_action = ""
	if key != KEY_ESCAPE:
		GameConfig.set_binding(action, key)
	_refresh_binding_button(action)
	get_viewport().set_input_as_handled()

func _value_row(parent: VBoxContainer, text: String, control: Control) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var label: Label = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)
	row.add_child(control)
	parent.add_child(row)

func _add_slider(parent: VBoxContainer, text: String, min_value: float, max_value: float, step: float, value: float) -> HSlider:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(190.0, 0.0)
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(240.0, 0.0)
	row.add_child(slider)
	parent.add_child(row)
	return slider

func _slider_value_label(slider: HSlider, format: String) -> Label:
	var label: Label = Label.new()
	label.custom_minimum_size = Vector2(62.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", UiTheme.WARN)
	if format == "%.0f%%":
		label.text = "%d%%" % roundi(slider.value * 100.0)
	else:
		label.text = format % slider.value
	# Wertelabel in die Slider-Zeile einhaengen.
	var row: Node = slider.get_parent()
	var index: int = slider.get_index()
	(row as HBoxContainer).add_child(label)
	(row as HBoxContainer).move_child(label, index + 1)
	return label