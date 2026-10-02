extends Control

## Main menu: play, settings, quit.

var _settings: SettingsPanel
var _weapons: WeaponsMenu
var _buttons: VBoxContainer

func _ready() -> void:
	GameConfig.ensure_loaded()
	GameConfig.apply()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.025, 0.04, 0.06)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var gradient: TextureRect = TextureRect.new()
	var gradient_texture: GradientTexture2D = GradientTexture2D.new()
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.05, 0.13, 0.17, 1.0))
	grad.set_color(1, Color(0.02, 0.03, 0.05, 1.0))
	gradient_texture.gradient = grad
	gradient_texture.fill_from = Vector2(0.5, 0.0)
	gradient_texture.fill_to = Vector2(0.5, 1.0)
	gradient.texture = gradient_texture
	gradient.stretch_mode = TextureRect.STRETCH_SCALE
	gradient.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(gradient)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	var title: Label = Label.new()
	title.text = "TEST STAR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.47, 0.92, 0.85))
	column.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "ARENA-SHOOTER  ·  LAN 1v1 MIT FREUNDEN"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.78, 0.8))
	column.add_child(subtitle)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 34.0)
	column.add_child(spacer)

	_buttons = VBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 12)
	column.add_child(_buttons)

	_add_button("LAN 1v1", _on_lan, true)
	_add_button("SOLO GEGEN BOTS", _on_play)
	_add_button("WAFFENARSENAL", _on_weapons)
	_add_button("EINSTELLUNGEN", _on_settings)
	_add_button("BEENDEN", _on_quit)

	var hint: Label = Label.new()
	hint.text = "WASD laufen · Space springen · LMB schießen · RMB zielen · 1–4 Waffen · R nachladen · G Granate · ESC Menü"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.78, 0.8, 0.8))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -46.0
	hint.offset_bottom = -18.0
	add_child(hint)

	_weapons = WeaponsMenu.new()
	_weapons.visible = false
	_weapons.closed.connect(func() -> void: _weapons.visible = false)
	add_child(_weapons)

	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(func() -> void: _settings.visible = false)
	add_child(_settings)

func _add_button(text: String, handler: Callable, primary: bool = false) -> void:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320.0, 70.0 if primary else 54.0)
	button.add_theme_font_size_override("font_size", 30 if primary else 22)
	if primary:
		button.add_theme_color_override("font_color", Color(0.47, 0.92, 0.85))
		button.add_theme_color_override("font_hover_color", Color(0.7, 1.0, 0.95))
	button.pressed.connect(handler)
	_buttons.add_child(button)

func _on_lan() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/menus/lobby.tscn")

func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/gameplay/main.tscn")

func _on_weapons() -> void:
	_weapons.visible = true

func _on_settings() -> void:
	_settings.visible = true

func _on_quit() -> void:
	get_tree().quit()