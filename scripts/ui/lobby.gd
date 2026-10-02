extends Control

## LAN-1v1-Lobby: Spiel erstellen (Host) oder einem Freund im selben Netzwerk
## beitreten. Server im LAN werden automatisch gefunden, alternativ IP eintippen.

const FRAG_LIMITS: Array[int] = [5, 10, 15, 20]

var _name_edit: LineEdit
var _content: VBoxContainer
var _status: Label
var _server_box: VBoxContainer
var _ip_edit: LineEdit
var _limit_option: OptionButton

func _ready() -> void:
	GameConfig.ensure_loaded()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_frame()
	Net.servers_changed.connect(_refresh_servers)
	Net.connection_failed.connect(_on_connection_failed)
	Net.opponent_left.connect(_on_lost_connection)
	_show_main()

func _exit_tree() -> void:
	Net.stop_discovery()

# --------------------------------------------------------------- Rahmen ----

func _build_frame() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.025, 0.04, 0.06)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	column.custom_minimum_size = Vector2(520.0, 0.0)
	center.add_child(column)

	var title: Label = Label.new()
	title.text = "LAN 1v1"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.47, 0.92, 0.85))
	column.add_child(title)

	var name_label: Label = Label.new()
	name_label.text = "DEIN NAME"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.8))
	column.add_child(name_label)

	_name_edit = LineEdit.new()
	_name_edit.text = GameConfig.player_name
	_name_edit.max_length = 16
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.custom_minimum_size = Vector2(0.0, 44.0)
	_name_edit.add_theme_font_size_override("font_size", 20)
	column.add_child(_name_edit)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 14.0)
	column.add_child(spacer)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	column.add_child(_content)

func _clear() -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_status = null
	_server_box = null
	_ip_edit = null
	_limit_option = null

func _commit_name() -> void:
	var entered: String = _name_edit.text.strip_edges()
	GameConfig.player_name = entered if not entered.is_empty() else "Spieler"
	_name_edit.text = GameConfig.player_name
	GameConfig.save_config()

# --------------------------------------------------------------- Ansichten --

func _show_main() -> void:
	Net.stop_discovery()
	_clear()
	_name_edit.editable = true
	_button("SPIEL ERSTELLEN", _show_host_setup)
	_button("SPIEL BEITRETEN", _show_join)
	_note("Beide Spieler müssen im selben WLAN / LAN sein.")
	_button("ZURÜCK", _back_to_menu)

func _show_host_setup() -> void:
	_commit_name()
	_clear()
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_content.add_child(row)
	var label: Label = Label.new()
	label.text = "ABSCHÜSSE ZUM SIEG"
	label.add_theme_font_size_override("font_size", 18)
	row.add_child(label)
	_limit_option = OptionButton.new()
	for limit: int in FRAG_LIMITS:
		_limit_option.add_item(str(limit))
	_limit_option.select(1)
	_limit_option.custom_minimum_size = Vector2(100.0, 40.0)
	row.add_child(_limit_option)
	_button("LOBBY ÖFFNEN", _open_lobby)
	_button("ZURÜCK", _show_main)

func _open_lobby() -> void:
	var limit: int = FRAG_LIMITS[_limit_option.selected]
	var err: Error = Net.host_game(limit)
	if err != OK:
		_clear()
		_note("Lobby konnte nicht geöffnet werden (Fehler %d). Läuft das Spiel schon auf diesem PC?" % err)
		_button("ZURÜCK", _show_main)
		return
	_clear()
	_name_edit.editable = false
	_status = _note("Warte auf Gegner …")
	_status.add_theme_font_size_override("font_size", 24)
	var ips: PackedStringArray = Net.local_ips()
	if ips.is_empty():
		_note("Dein Freund findet dich automatisch im LAN.")
	else:
		_note("Dein Freund findet dich automatisch.\nFalls nicht, soll er diese IP eingeben:\n%s" % "   ".join(ips))
	_note("Beim ersten Start fragt Windows nach der Firewall: \"Zulassen\" klicken.")
	_button("ABBRECHEN", _cancel_host)

func _cancel_host() -> void:
	Net.close()
	_show_main()

func _show_join() -> void:
	_commit_name()
	_clear()
	var heading: Label = _note("Gefundene Spiele im LAN:")
	heading.add_theme_font_size_override("font_size", 18)
	_server_box = VBoxContainer.new()
	_server_box.add_theme_constant_override("separation", 8)
	_content.add_child(_server_box)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "oder IP eingeben, z. B. 192.168.1.23"
	_ip_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ip_edit.custom_minimum_size = Vector2(0.0, 44.0)
	_ip_edit.add_theme_font_size_override("font_size", 18)
	_ip_edit.text_submitted.connect(func(_text: String) -> void: _join_typed())
	_content.add_child(_ip_edit)
	_button("VERBINDEN", _join_typed)
	_status = _note("")
	_button("ZURÜCK", _show_main)
	Net.start_discovery()

func _refresh_servers() -> void:
	if _server_box == null:
		return
	for child: Node in _server_box.get_children():
		_server_box.remove_child(child)
		child.queue_free()
	if Net.servers.is_empty():
		var searching: Label = Label.new()
		searching.text = "Suche läuft …"
		searching.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		searching.add_theme_color_override("font_color", Color(0.7, 0.78, 0.8, 0.8))
		_server_box.add_child(searching)
		return
	for ip: String in Net.servers.keys():
		var info: Dictionary = Net.servers[ip]
		var button: Button = Button.new()
		button.text = "%s   ·   bis %d   ·   %s" % [str(info["name"]).to_upper(), int(info["limit"]), ip]
		button.custom_minimum_size = Vector2(0.0, 52.0)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_join.bind(ip))
		_server_box.add_child(button)

func _join_typed() -> void:
	var ip: String = _ip_edit.text.strip_edges() if _ip_edit != null else ""
	if ip.is_empty():
		_set_status("Bitte eine IP-Adresse eingeben.")
		return
	_join(ip)

func _join(ip: String) -> void:
	_commit_name()
	var err: Error = Net.join_game(ip)
	if err != OK:
		_set_status("Verbindung nicht möglich (Fehler %d)." % err)
		return
	_set_status("Verbinde mit %s …" % ip)

# ----------------------------------------------------------- Rückmeldungen -

func _on_connection_failed() -> void:
	_set_status("Keine Verbindung. Stimmt die IP? Läuft das Spiel beim Host?")

func _on_lost_connection() -> void:
	_set_status("Verbindung getrennt.")

func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text

func _back_to_menu() -> void:
	_commit_name()
	get_tree().change_scene_to_file(Net.MENU_SCENE)

# --------------------------------------------------------------- Helfer ----

func _button(text: String, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320.0, 54.0)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(handler)
	_content.add_child(button)
	return button

func _note(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(500.0, 0.0)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.8))
	_content.add_child(label)
	return label
