extends Control

## Hauptmenue: Spielen, Waffen, Einstellungen, Beenden.

const BACKGROUND_SHADER: Shader = preload("res://ui_background.gdshader")

var _settings: SettingsPanel
var _weapons: WeaponsMenu
var _buttons: VBoxContainer

func _ready() -> void:
	GameConfig.ensure_loaded()
	GameConfig.apply()
	theme = UiTheme.get_theme()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var background: ColorRect = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background_material: ShaderMaterial = ShaderMaterial.new()
	background_material.shader = BACKGROUND_SHADER
	background.material = background_material
	add_child(background)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(460.0, 0.0)
	center.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 34)
	panel.add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var eyebrow: Label = Label.new()
	eyebrow.text = "A R E N A   S H O O T E R"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	column.add_child(eyebrow)

	var title: Label = Label.new()
	title.text = "TEST STAR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	column.add_child(title)

	var underline: ColorRect = ColorRect.new()
	underline.color = Color(UiTheme.ACCENT.r, UiTheme.ACCENT.g, UiTheme.ACCENT.b, 0.6)
	underline.custom_minimum_size = Vector2(180.0, 3.0)
	underline.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(underline)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 24.0)
	column.add_child(spacer)

	_buttons = VBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 12)
	column.add_child(_buttons)

	_add_button("SPIELEN", _on_play)
	_add_button("WAFFEN", _on_weapons)
	_add_button("EINSTELLUNGEN", _on_settings)
	_add_button("BEENDEN", _on_quit)

	var hint: Label = Label.new()
	hint.text = "%s/%s/%s/%s laufen · %s springen · %s ducken · LMB schießen · RMB zielen · %s–%s Waffen · %s nachladen · %s Granate · ESC Menü" % [
		GameConfig.key_name("move_forward"), GameConfig.key_name("move_back"),
		GameConfig.key_name("move_left"), GameConfig.key_name("move_right"),
		GameConfig.key_name("jump"), GameConfig.key_name("crouch"),
		GameConfig.key_name("slot_1"), GameConfig.key_name("slot_4"),
		GameConfig.key_name("reload"), GameConfig.key_name("grenade"),
	]
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(UiTheme.TEXT_MUTED.r, UiTheme.TEXT_MUTED.g, UiTheme.TEXT_MUTED.b, 0.75))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -48.0
	hint.offset_bottom = -18.0
	add_child(hint)

	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(func() -> void: _settings.visible = false)
	add_child(_settings)

	_weapons = WeaponsMenu.new()
	_weapons.visible = false
	_weapons.closed.connect(func() -> void: _weapons.visible = false)
	add_child(_weapons)

func _add_button(text: String, handler: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320.0, 56.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 21)
	button.pressed.connect(handler)
	_buttons.add_child(button)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		GameConfig.toggle_fullscreen()
		get_viewport().set_input_as_handled()

func _on_play() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _on_settings() -> void:
	_settings.visible = true

func _on_weapons() -> void:
	_weapons.visible = true

func _on_quit() -> void:
	get_tree().quit()