extends Node3D

## LAN-1v1-Match: Arena + lokaler Spieler + Gegner (RemotePlayer).
## Jeder Rechner steuert seinen eigenen Spieler. Der Schütze meldet Treffer,
## das Opfer rechnet den Schaden selbst und meldet seinen Tod an beide Seiten.

const ARENA_SCENE: PackedScene = preload("res://arena.tscn")
const PLAYER_SCENE: PackedScene = preload("res://player_3d.tscn")
const PAUSE_SCENE: PackedScene = preload("res://pause_menu.tscn")
const TRACER_SCRIPT: Script = preload("res://weapon_tracer.gd")
const IMPACT_SCRIPT: Script = preload("res://weapon_impact.gd")
const GRENADE_SCRIPT: Script = preload("res://grenade.gd")

const RESPAWN_TIME: float = 3.0
const SPAWN_PROTECTION: float = 1.5
const SEND_INTERVAL: float = 1.0 / 30.0
const FAR_SPAWN_DISTANCE: float = 22.0

var player: CharacterBody3D
var opponent: RemotePlayer
var my_id: int = 0
var scores: Dictionary = {}

var _opp_id: int = 0
var _send_timer: float = 0.0
var _dying: bool = false
var _respawn_left: float = 0.0
var _protect_left: float = 0.0
var _match_over: bool = false
var _pause_menu: Node

var _score_label: Label
var _sub_label: Label
var _banner: Label
var _feed: Label
var _feed_tween: Tween
var _hurt: ColorRect
var _hurt_tween: Tween
var _end_layer: CanvasLayer
var _end_title: Label
var _end_detail: Label
var _end_wait: Label
var _rematch_button: Button

func _ready() -> void:
	GameConfig.ensure_loaded()
	my_id = multiplayer.get_unique_id()
	_opp_id = Net.opponent_id
	scores = {my_id: 0, _opp_id: 0}

	# Arena ohne Bots: den Spawner entfernen, bevor er in den Baum kommt.
	var arena: Node = ARENA_SCENE.instantiate()
	var spawner: Node = arena.get_node_or_null("EnemySpawner")
	if spawner != null:
		arena.remove_child(spawner)
		spawner.free()
	add_child(arena)

	var my_start: Vector3 = EnemySpawner.SPAWN_POINTS[0 if Net.is_host else 1]
	var their_start: Vector3 = EnemySpawner.SPAWN_POINTS[1 if Net.is_host else 0]

	player = PLAYER_SCENE.instantiate() as CharacterBody3D
	add_child(player)
	player.call("respawn_at", my_start, _yaw_to_center(my_start))

	opponent = RemotePlayer.new()
	opponent.peer_id = _opp_id
	opponent.display_name = Net.opponent_name
	opponent.position = their_start
	opponent.rotation.y = _yaw_to_center(their_start)
	add_child(opponent)

	_pause_menu = PAUSE_SCENE.instantiate()
	_pause_menu.set("versus_mode", true)
	add_child(_pause_menu)

	_build_hud()
	_build_end_screen()
	_refresh_score()
	_protect_left = SPAWN_PROTECTION

	Net.opponent_left.connect(_on_opponent_left)
	Net.opponent_name_changed.connect(_on_name_changed)
	Net.versus = self

func _exit_tree() -> void:
	if Net.versus == self:
		Net.versus = null

func _physics_process(delta: float) -> void:
	if player == null:
		return
	_protect_left = maxf(_protect_left - delta, 0.0)
	var hp: int = int(player.get("health"))

	_send_timer -= delta
	if _send_timer <= 0.0:
		_send_timer = SEND_INTERVAL
		Net.send_state(player.global_position, player.rotation.y, maxi(hp, 0), not _dying)

	if hp <= 0 and not _dying:
		_dying = true
		_respawn_left = RESPAWN_TIME
		Net.report_death()

	if _dying and not _match_over:
		_respawn_left -= delta
		_banner.text = "AUSGESCHALTET\nRespawn in %d" % ceili(maxf(_respawn_left, 0.0))
		if _respawn_left <= 0.0:
			_respawn()

# ------------------------------------------------------- Netzwerk-Events ---

func net_state(pos: Vector3, yaw: float, hp: int, alive: bool) -> void:
	if opponent != null and is_instance_valid(opponent):
		opponent.apply_state(pos, yaw, hp, alive)

func net_tracer(origin: Vector3, endpoint: Vector3) -> void:
	var tracer: MeshInstance3D = MeshInstance3D.new()
	tracer.set_script(TRACER_SCRIPT)
	add_child(tracer)
	tracer.call("set_line", origin, endpoint)
	if opponent != null and is_instance_valid(opponent):
		opponent.flash_muzzle()

func net_impact(pos: Vector3, normal: Vector3) -> void:
	var impact: Node3D = Node3D.new()
	impact.set_script(IMPACT_SCRIPT)
	add_child(impact)
	impact.global_position = pos + normal * 0.035
	var up: Vector3 = Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	impact.look_at(pos + normal, up)

func net_grenade(pos: Vector3, vel: Vector3, radius: float, damage: int, fuse: float) -> void:
	# Nur zur Anzeige: der Werfer berechnet den Schaden auf seinem Rechner.
	var grenade: RigidBody3D = RigidBody3D.new()
	grenade.set_script(GRENADE_SCRIPT)
	grenade.set("visual_only", true)
	grenade.set("blast_radius", radius)
	grenade.set("max_damage", damage)
	grenade.set("fuse", fuse)
	add_child(grenade)
	grenade.global_position = pos
	if opponent != null and is_instance_valid(opponent):
		grenade.add_collision_exception_with(opponent)
	grenade.call("launch", vel)

func net_damage(amount: int) -> void:
	if _dying or _match_over or _protect_left > 0.0:
		return
	player.call("apply_damage", amount)
	_flash_hurt()

func net_death(victim_id: int) -> void:
	var killer_id: int = _opp_id if victim_id == my_id else my_id
	scores[killer_id] = int(scores.get(killer_id, 0)) + 1
	if killer_id == my_id:
		player.call("add_kill")
		_say("Du hast %s erledigt" % Net.opponent_name)
	else:
		_say("%s hat dich erledigt" % Net.opponent_name)
	_refresh_score()
	if int(scores[killer_id]) >= Net.frag_limit and not _match_over:
		_end_match(killer_id)

func net_rematch() -> void:
	scores = {my_id: 0, _opp_id: 0}
	_match_over = false
	_dying = false
	_banner.text = ""
	_end_layer.visible = false
	player.set("score", 0)
	var start: Vector3 = EnemySpawner.SPAWN_POINTS[0 if Net.is_host else 1]
	player.call("respawn_at", start, _yaw_to_center(start))
	_protect_left = SPAWN_PROTECTION
	_pause_menu.set("blocked", false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_refresh_score()

func _on_opponent_left() -> void:
	if Net.versus != self:
		return
	_match_over = true
	_banner.text = ""
	if opponent != null and is_instance_valid(opponent):
		opponent.visible = false
		opponent.collision_layer = 0
	_show_end("GEGNER WEG", Color(1.0, 0.7, 0.3), "Dein Gegner hat das Match verlassen.", false)

func _on_name_changed() -> void:
	if opponent != null and is_instance_valid(opponent):
		opponent.set_display_name(Net.opponent_name)
	_refresh_score()

# ------------------------------------------------------------- Ablauf -----

func _respawn() -> void:
	var point: Vector3 = _pick_spawn()
	player.call("respawn_at", point, _yaw_to_center(point))
	_dying = false
	_protect_left = SPAWN_PROTECTION
	_banner.text = ""

func _pick_spawn() -> Vector3:
	var far: Array[Vector3] = []
	var best: Vector3 = EnemySpawner.SPAWN_POINTS[0]
	var best_distance: float = -1.0
	for point: Vector3 in EnemySpawner.SPAWN_POINTS:
		var distance: float = point.distance_to(opponent.global_position)
		if distance > best_distance:
			best_distance = distance
			best = point
		if distance >= FAR_SPAWN_DISTANCE:
			far.append(point)
	if far.is_empty():
		return best
	return far[randi() % far.size()]

func _yaw_to_center(point: Vector3) -> float:
	var to_center: Vector3 = -point
	to_center.y = 0.0
	if to_center.length() < 0.05:
		return 0.0
	return atan2(-to_center.x, -to_center.z)

func _end_match(winner_id: int) -> void:
	var won: bool = winner_id == my_id
	var detail: String = "%d : %d" % [int(scores.get(my_id, 0)), int(scores.get(_opp_id, 0))]
	_show_end("SIEG!" if won else "NIEDERLAGE", Color(0.47, 0.95, 0.6) if won else Color(1.0, 0.4, 0.35), detail, true)

func _show_end(title: String, color: Color, detail: String, allow_rematch: bool) -> void:
	_match_over = true
	_pause_menu.set("blocked", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_end_title.text = title
	_end_title.add_theme_color_override("font_color", color)
	_end_detail.text = detail
	_rematch_button.visible = allow_rematch and Net.is_host
	_end_wait.visible = allow_rematch and not Net.is_host
	_end_layer.visible = true

# --------------------------------------------------------------- HUD -------

func _refresh_score() -> void:
	var mine: int = int(scores.get(my_id, 0))
	var theirs: int = int(scores.get(_opp_id, 0))
	_score_label.text = "%s   %d : %d   %s" % [GameConfig.player_name.to_upper(), mine, theirs, Net.opponent_name.to_upper()]
	_sub_label.text = "ERSTER MIT %d ABSCHÜSSEN GEWINNT" % Net.frag_limit

func _say(text: String) -> void:
	_feed.text = text
	_feed.modulate.a = 1.0
	if _feed_tween != null:
		_feed_tween.kill()
	_feed_tween = create_tween()
	_feed_tween.tween_interval(2.5)
	_feed_tween.tween_property(_feed, "modulate:a", 0.0, 0.6)

func _flash_hurt() -> void:
	_hurt.color.a = 0.38
	if _hurt_tween != null:
		_hurt_tween.kill()
	_hurt_tween = create_tween()
	_hurt_tween.tween_property(_hurt, "color:a", 0.0, 0.4)

func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_hurt = ColorRect.new()
	_hurt.color = Color(0.9, 0.05, 0.05, 0.0)
	_hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hurt)

	_score_label = _make_label(layer, 32, Color(0.47, 0.92, 0.85), Control.PRESET_TOP_WIDE)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.offset_top = 12.0
	_score_label.offset_bottom = 56.0

	_sub_label = _make_label(layer, 14, Color(0.7, 0.78, 0.8, 0.85), Control.PRESET_TOP_WIDE)
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.offset_top = 56.0
	_sub_label.offset_bottom = 80.0

	_feed = _make_label(layer, 18, Color(1.0, 0.9, 0.7), Control.PRESET_TOP_WIDE)
	_feed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_feed.offset_top = 14.0
	_feed.offset_bottom = 46.0
	_feed.offset_right = -24.0
	_feed.modulate.a = 0.0

	_banner = _make_label(layer, 40, Color(1.0, 0.45, 0.35), Control.PRESET_FULL_RECT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.offset_top = 160.0

func _make_label(parent: Node, size: int, color: Color, preset: Control.LayoutPreset) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	label.set_anchors_and_offsets_preset(preset)
	return label

func _build_end_screen() -> void:
	_end_layer = CanvasLayer.new()
	_end_layer.layer = 25
	_end_layer.visible = false
	add_child(_end_layer)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_layer.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_layer.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.07, 0.97)
	style.border_color = Color(0.15, 0.72, 0.68, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 50.0
	style.content_margin_right = 50.0
	style.content_margin_top = 30.0
	style.content_margin_bottom = 30.0
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	_end_title = Label.new()
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.add_theme_font_size_override("font_size", 48)
	column.add_child(_end_title)

	_end_detail = Label.new()
	_end_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_detail.add_theme_font_size_override("font_size", 30)
	_end_detail.add_theme_color_override("font_color", Color(0.85, 0.92, 0.93))
	column.add_child(_end_detail)

	_end_wait = Label.new()
	_end_wait.text = "Warte auf den Host für die Revanche …"
	_end_wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_wait.add_theme_font_size_override("font_size", 16)
	_end_wait.add_theme_color_override("font_color", Color(0.7, 0.78, 0.8))
	column.add_child(_end_wait)

	_rematch_button = _end_button(column, "REVANCHE", func() -> void: Net.request_rematch())
	_end_button(column, "HAUPTMENÜ", func() -> void: Net.leave())

func _end_button(column: VBoxContainer, text: String, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300.0, 48.0)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(handler)
	column.add_child(button)
	return button
