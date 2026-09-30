class_name GameConfig
extends RefCounted

## Static settings store shared by the menu, the pause menu and the game.
## Persists to user://settings.cfg.

const PATH: String = "user://settings.cfg"

const WEAPON_NAMES: Array[String] = ["PISTOLE", "STURMGEWEHR", "SNIPER", "SCHROTFLINTE"]
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
	difficulty = config.get_value("game", "difficulty", DEFAULT_DIFFICULTY)
	var slots: Variant = config.get_value("game", "weapon_slots", weapon_slots)
	if slots is Array and (slots as Array).size() == 4:
		var loaded_slots: Array[int] = []
		for value: Variant in slots:
			loaded_slots.append(clampi(int(value), 0, WEAPON_NAMES.size() - 1))
		weapon_slots = loaded_slots
	apply()

static func save_config() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("input", "sensitivity", sensitivity)
	config.set_value("input", "invert_y", invert_y)
	config.set_value("video", "fov", fov)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("game", "difficulty", difficulty)
	config.set_value("game", "weapon_slots", weapon_slots)
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