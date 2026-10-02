class_name GameConfig
extends RefCounted

## Static settings store shared by the menu, the pause menu and the game.
## Persists to user://settings.cfg.

const PATH: String = "user://settings.cfg"

const WEAPON_NAMES: Array[String] = ["PISTOLE", "STURMGEWEHR", "SNIPER", "SCHROTFLINTE", "ENERGIEPISTOLE", "MESSER", "BURST-SMG", "HANDKANONE", "VORSCHLAGHAMMER", "GRANATWERFER"]
const DIFFICULTY_NAMES: Array[String] = ["LEICHT", "NORMAL", "SCHWER"]

const DEFAULT_SENSITIVITY: float = 0.0018
const DEFAULT_FOV: float = 78.0
const DEFAULT_VOLUME: float = 1.0
const DEFAULT_DIFFICULTY: int = 0
const DEFAULT_INVERT_Y: bool = false

static var sensitivity: float = DEFAULT_SENSITIVITY
static var fov: float = DEFAULT_FOV
static var master_volume: float = DEFAULT_VOLUME
static var difficulty: int = DEFAULT_DIFFICULTY
static var invert_y: bool = DEFAULT_INVERT_Y
static var weapon_slots: Array[int] = [0, 1, 2, 3]
static var player_name: String = "Spieler"
static var pending_weapon: int = -1
static var fullscreen: bool = false
static var bindings: Dictionary = {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "jump": KEY_SPACE, "crouch": KEY_CTRL, "reload": KEY_R, "grenade": KEY_G, "slot_1": KEY_1, "slot_2": KEY_2, "slot_3": KEY_3, "slot_4": KEY_4, "fullscreen": KEY_F11}
const BINDING_ORDER: Array[String] = ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "reload", "grenade", "slot_1", "slot_2", "slot_3", "slot_4", "fullscreen"]
const BINDING_LABELS: Dictionary = {"move_forward": "Vorwärts", "move_back": "Rückwärts", "move_left": "Links", "move_right": "Rechts", "jump": "Springen / Leiter", "crouch": "Ducken", "reload": "Nachladen", "grenade": "Granate", "slot_1": "Waffenslot 1", "slot_2": "Waffenslot 2", "slot_3": "Waffenslot 3", "slot_4": "Waffenslot 4", "fullscreen": "Vollbild umschalten"}

static var _loaded: bool = false

static func ensure_loaded() -> void:
	if not _loaded:
		load_config()

static func load_config() -> void:
	_loaded = true
	var config: ConfigFile = ConfigFile.new()
	if config.load(PATH) != OK:
		apply()
		return
	sensitivity = config.get_value("input", "sensitivity", DEFAULT_SENSITIVITY)
	invert_y = config.get_value("input", "invert_y", DEFAULT_INVERT_Y)
	fov = config.get_value("video", "fov", DEFAULT_FOV)
	master_volume = config.get_value("audio", "master_volume", DEFAULT_VOLUME)
	difficulty = clampi(int(config.get_value("game", "difficulty", DEFAULT_DIFFICULTY)), 0, DIFFICULTY_NAMES.size() - 1)
	player_name = str(config.get_value("player", "name", player_name))
	fullscreen = bool(config.get_value("video", "fullscreen", false))
	var stored_bindings: Variant = config.get_value("input", "bindings", bindings)
	if stored_bindings is Dictionary:
		for action: String in BINDING_ORDER:
			bindings[action] = int(stored_bindings.get(action, bindings[action]))
	var slots: Variant = config.get_value("game", "weapon_slots", weapon_slots)
	if slots is Array:
		var loaded_slots: Array[int] = []
		for value: Variant in slots:
			loaded_slots.append(clampi(int(value), 0, WEAPON_NAMES.size() - 1))
		if loaded_slots.size() >= 4:
			weapon_slots = loaded_slots.slice(0, 4)
	for slot: int in range(weapon_slots.size()):
		if weapon_slots.count(weapon_slots[slot]) > 1:
			for candidate: int in range(WEAPON_NAMES.size()):
				if not weapon_slots.has(candidate):
					weapon_slots[slot] = candidate
					break
	apply()

static func save_config() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("input", "sensitivity", sensitivity)
	config.set_value("input", "invert_y", invert_y)
	config.set_value("video", "fov", fov)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("game", "difficulty", difficulty)
	config.set_value("player", "name", player_name)
	config.set_value("game", "weapon_slots", weapon_slots)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("input", "bindings", bindings)
	config.save(PATH)

static func reset_defaults() -> void:
	sensitivity = DEFAULT_SENSITIVITY
	fov = DEFAULT_FOV
	master_volume = DEFAULT_VOLUME
	difficulty = DEFAULT_DIFFICULTY
	invert_y = DEFAULT_INVERT_Y
	weapon_slots = [0, 1, 2, 3]
	apply()
	save_config()

static func apply() -> void:
	AudioServer.set_bus_mute(0, master_volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(master_volume, 0.0001, 1.0)))

static func key_name(action: String) -> String:
	var key: int = int(bindings.get(action, KEY_NONE))
	return OS.get_keycode_string(key)

static func set_binding(action: String, key: int) -> void:
	if BINDING_ORDER.has(action):
		bindings[action] = key
		save_config()

static func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	save_config()

static func difficulty_damage_mult() -> float:
	match difficulty:
		0:
			return 0.55
		2:
			return 1.45
		_:
			return 1.0

static func difficulty_enemy_count() -> int:
	match difficulty:
		0:
			return 4
		2:
			return 8
		_:
			return 6
