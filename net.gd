extends Node

## Autoload "Net": LAN-1v1-Netzwerk (ENet) + automatische LAN-Suche per UDP.
## Alle Gameplay-RPCs laufen hier durch, damit der Node-Pfad (/root/Net) auf
## beiden Rechnern immer gleich ist, egal welche Szene gerade geladen ist.

signal connection_failed
signal opponent_left
signal servers_changed
signal opponent_name_changed

const GAME_PORT: int = 24680
const DISCOVERY_PORT: int = 24681
const MAGIC: String = "TESTSTAR1"
const VERSUS_SCENE: String = "res://versus.tscn"
const MENU_SCENE: String = "res://menu.tscn"
const SERVER_TIMEOUT_MS: int = 3500

var is_online: bool = false
var is_host: bool = false
var frag_limit: int = 10
var opponent_id: int = 0
var opponent_name: String = "GEGNER"
var versus: Node = null  # wird von versus.gd gesetzt, solange ein Match läuft
var servers: Dictionary = {}  # ip -> {"name": String, "limit": int, "seen": int}

var _peer: ENetMultiplayerPeer = null
var _broadcaster: PacketPeerUDP = null
var _listener: PacketPeerUDP = null
var _broadcast_timer: float = 0.0

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# ------------------------------------------------------------ verbinden ----

func host_game(limit: int) -> Error:
	close()
	_peer = ENetMultiplayerPeer.new()
	var err: Error = _peer.create_server(GAME_PORT, 1)
	if err != OK:
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	is_online = true
	is_host = true
	frag_limit = limit
	_start_broadcast()
	return OK

func join_game(ip: String) -> Error:
	close()
	_peer = ENetMultiplayerPeer.new()
	var err: Error = _peer.create_client(ip, GAME_PORT)
	if err != OK:
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	is_online = true
	is_host = false
	return OK

func close() -> void:
	_stop_broadcast()
	if _peer != null:
		_peer.close()
		_peer = null
	multiplayer.multiplayer_peer = null
	is_online = false
	is_host = false
	opponent_id = 0
	opponent_name = "GEGNER"

func leave() -> void:
	close()
	versus = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)

func in_match() -> bool:
	return is_online and opponent_id != 0 and multiplayer.multiplayer_peer != null

func local_ips() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for address: String in IP.get_local_addresses():
		if address.count(".") != 3:
			continue
		if address.begins_with("192.168.") or address.begins_with("10."):
			result.append(address)
		elif address.begins_with("172."):
			var second: int = int(address.split(".")[1])
			if second >= 16 and second <= 31:
				result.append(address)
	return result

# --------------------------------------------------- LAN-Suche (UDP) ------

func _start_broadcast() -> void:
	_stop_broadcast()
	_broadcaster = PacketPeerUDP.new()
	_broadcaster.set_broadcast_enabled(true)
	_broadcaster.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_broadcast_timer = 0.0

func _stop_broadcast() -> void:
	if _broadcaster != null:
		_broadcaster.close()
		_broadcaster = null

func start_discovery() -> void:
	stop_discovery()
	servers.clear()
	_listener = PacketPeerUDP.new()
	if _listener.bind(DISCOVERY_PORT) != OK:
		_listener = null
	servers_changed.emit()

func stop_discovery() -> void:
	if _listener != null:
		_listener.close()
		_listener = null

func _process(delta: float) -> void:
	if _broadcaster != null:
		_broadcast_timer -= delta
		if _broadcast_timer <= 0.0:
			_broadcast_timer = 1.0
			var message: String = "%s|%s|%d" % [MAGIC, GameConfig.player_name, frag_limit]
			_broadcaster.put_packet(message.to_utf8_buffer())
	if _listener != null:
		_poll_listener()

func _poll_listener() -> void:
	var changed: bool = false
	var now: int = Time.get_ticks_msec()
	while _listener.get_available_packet_count() > 0:
		var text: String = _listener.get_packet().get_string_from_utf8()
		var ip: String = _listener.get_packet_ip()
		var parts: PackedStringArray = text.split("|")
		if parts.size() != 3 or parts[0] != MAGIC:
			continue
		var info: Dictionary = {"name": parts[1], "limit": int(parts[2]), "seen": now}
		if not servers.has(ip) or servers[ip]["name"] != info["name"] or servers[ip]["limit"] != info["limit"]:
			changed = true
		servers[ip] = info
	for ip: String in servers.keys():
		if now - int(servers[ip]["seen"]) > SERVER_TIMEOUT_MS:
			servers.erase(ip)
			changed = true
	if changed:
		servers_changed.emit()

# ------------------------------------------------- Verbindungs-Signale ----

func _on_peer_connected(id: int) -> void:
	opponent_id = id
	_hello.rpc_id(id, GameConfig.player_name, frag_limit)
	if is_host:
		_stop_broadcast()
		_start_match.rpc()

func _on_peer_disconnected(id: int) -> void:
	if id != opponent_id:
		return
	opponent_id = 0
	opponent_left.emit()
	if is_host and versus == null:
		_start_broadcast()

func _on_connection_failed() -> void:
	close()
	connection_failed.emit()

func _on_server_disconnected() -> void:
	opponent_id = 0
	opponent_left.emit()

# --------------------------------------------------------------- RPCs ------

@rpc("any_peer", "reliable")
func _hello(player_name: String, limit: int) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	opponent_id = sender
	opponent_name = player_name.strip_edges().left(16)
	if opponent_name.is_empty():
		opponent_name = "GEGNER"
	if sender == 1:
		frag_limit = clampi(limit, 1, 100)
	opponent_name_changed.emit()

@rpc("authority", "call_local", "reliable")
func _start_match() -> void:
	stop_discovery()
	get_tree().change_scene_to_file(VERSUS_SCENE)

@rpc("authority", "call_local", "reliable")
func _rematch() -> void:
	if versus != null:
		versus.call("net_rematch")

func request_rematch() -> void:
	if is_host and in_match():
		_rematch.rpc()

# Spielerzustand (~30 Mal pro Sekunde, darf auch mal verloren gehen).
func send_state(pos: Vector3, yaw: float, hp: int, alive: bool) -> void:
	if in_match():
		_state.rpc_id(opponent_id, pos, yaw, hp, alive)

@rpc("any_peer", "unreliable_ordered")
func _state(pos: Vector3, yaw: float, hp: int, alive: bool) -> void:
	if versus != null and multiplayer.get_remote_sender_id() == opponent_id:
		versus.call("net_state", pos, yaw, hp, alive)

# Schuss-Effekte, damit der Gegner Tracer und Einschläge sieht.
func send_tracer(origin: Vector3, endpoint: Vector3) -> void:
	if in_match():
		_tracer.rpc_id(opponent_id, origin, endpoint)

@rpc("any_peer", "unreliable")
func _tracer(origin: Vector3, endpoint: Vector3) -> void:
	if versus != null and multiplayer.get_remote_sender_id() == opponent_id:
		versus.call("net_tracer", origin, endpoint)

func send_impact(pos: Vector3, normal: Vector3) -> void:
	if in_match():
		_impact.rpc_id(opponent_id, pos, normal)

@rpc("any_peer", "unreliable")
func _impact(pos: Vector3, normal: Vector3) -> void:
	if versus != null and multiplayer.get_remote_sender_id() == opponent_id:
		versus.call("net_impact", pos, normal)

func send_grenade(pos: Vector3, vel: Vector3, radius: float, damage: int, fuse: float) -> void:
	if in_match():
		_grenade.rpc_id(opponent_id, pos, vel, radius, damage, fuse)

@rpc("any_peer", "reliable")
func _grenade(pos: Vector3, vel: Vector3, radius: float, damage: int, fuse: float) -> void:
	if versus != null and multiplayer.get_remote_sender_id() == opponent_id:
		versus.call("net_grenade", pos, vel, radius, damage, fuse)

# Der Schütze meldet den Treffer, das Opfer zieht sich die Lebenspunkte selbst ab.
func send_damage(amount: int) -> void:
	if in_match():
		_damage.rpc_id(opponent_id, amount)

@rpc("any_peer", "reliable")
func _damage(amount: int) -> void:
	if versus != null and multiplayer.get_remote_sender_id() == opponent_id:
		versus.call("net_damage", clampi(amount, 0, 500))

# Das Opfer meldet seinen Tod an beide Seiten (Punktestand bleibt so synchron).
func report_death() -> void:
	if in_match():
		_death.rpc(multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "reliable")
func _death(victim_id: int) -> void:
	if victim_id != multiplayer.get_unique_id() and victim_id != opponent_id:
		return
	if versus != null:
		versus.call("net_death", victim_id)
