extends CanvasLayer

## In-game overlay: ESC pause menu, settings and game-over screen.
## Runs while the scene tree is paused (PROCESS_MODE_ALWAYS).

const MENU_SCENE: String = "res://scenes/ui/menus/main_menu.tscn"

var _dim: ColorRect
var _pause_center: CenterContainer
var _over_center: CenterContainer
var _settings: SettingsPanel
var _game_over: bool = false
var _paused: bool = false

## LAN-Match: Spiel läuft beim Pausemenü weiter (kein tree.paused), kein Game-Over-Bildschirm.
var versus_mode: bool = false
## Wird vom Match gesetzt, solange der End-Bildschirm offen ist (ESC tut dann nichts).
var blocked: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build()
	_hide_all()

func _process(_delta: float) -> void:
	if _game_over or versus_mode:
		return
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and int(player.get("health")) <= 0 and not _paused:
		_show_game_over()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	if blocked:
		return
	if _game_over:
		return
	if _settings.visible:
		_settings.visible = false
		_pause_center.visible = true
		get_viewport().set_input_as_handled()
		return
	_toggle_pause()
	get_viewport().set_input_as_handled()

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.62)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_pause_center = _new_center()
	var pause_column: VBoxContainer = _panel_inside(_pause_center, "PAUSE")
	_button(pause_column, "FORTSETZEN", _resume)
	_button(pause_column, "EINSTELLUNGEN", _open_settings)
	_button(pause_column, "MATCH VERLASSEN" if versus_mode else "HAUPTMENÜ", _go_menu)
	_button(pause_column, "BEENDEN", _quit)

	_over_center = _new_center()
	var over_column: VBoxContainer = _panel_inside(_over_center, "AUSGESCHALTET")
	var sub: Label = Label.new()
	sub.text = "Du wurdest erledigt."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.9, 0.6, 0.6))
	sub.add_theme_font_size_override("font_size", 16)
	over_column.add_child(sub)
	_button(over_column, "NEUSTART", _restart)
	_button(over_column, "HAUPTMENÜ", _go_menu)

	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(_on_settings_closed)
	add_child(_settings)

func _new_center() -> CenterContainer:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	return center

func _panel_inside(center: CenterContainer, title_text: String) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.07, 0.97)
	style.border_color = Color(0.15, 0.72, 0.68, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 40.0
	style.content_margin_right = 40.0
	style.content_margin_top = 26.0
	style.content_margin_bottom = 26.0
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var title: Label = Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.47, 0.92, 0.85))
	column.add_child(title)
	return column

func _button(column: VBoxContainer, text: String, handler: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300.0, 48.0)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(handler)
	column.add_child(button)

func _hide_all() -> void:
	_dim.visible = false
	_pause_center.visible = false
	_over_center.visible = false
	if _settings != null:
		_settings.visible = false

func _toggle_pause() -> void:
	if _paused:
		_resume()
	else:
		_pause()

func _pause() -> void:
	_paused = true
	if not versus_mode:
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hide_all()
	_dim.visible = true
	_pause_center.visible = true

func _resume() -> void:
	_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_hide_all()

func _show_game_over() -> void:
	_game_over = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hide_all()
	_dim.visible = true
	_over_center.visible = true

func _open_settings() -> void:
	_pause_center.visible = false
	_settings.visible = true

func _on_settings_closed() -> void:
	_settings.visible = false
	if _paused:
		_pause_center.visible = true

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _go_menu() -> void:
	if versus_mode:
		Net.leave()
		return
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)

func _quit() -> void:
	get_tree().quit()