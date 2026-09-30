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
const DEFAULT_FULLSCREEN: bool = false

static var sensitivity: float = DEFAULT_SENSITIVITY
static var fov: float = DEFAULT_FOV
static var master_volume: float = DEFAULT_VOLUME
static var difficulty: int = DEFAULT_DIFFICULTY
static var invert_y: bool = DEFAULT_INVERT_Y
static var fullscreen: bool = DEFAULT_FULLSCREEN
static var weapon_slots: Array[int] = [0, 1, 2, 3]
static var bindings: Dictionary = {}
## Waffe, die beim naechsten Szenenstart direkt ausgeruestet wird (-1 = normale Slots).
## Das Waffen-Menue setzt das vor dem Laden der Testwelt.
static var pending_weapon: int = -1

## Belegbare Aktionen -> Standard-Taste (physical keycode).
const DEFAULT_BINDINGS: Dictionary = {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"jump": KEY_SPACE,
	"crouch": KEY_SHIFT,
	"reload": KEY_R,
	"grenade": KEY_G,
	"slot_1": KEY_1,
	"slot_2": KEY_2,
	"slot_3": KEY_3,
	"slot_4": KEY_4,
	"fullscreen": KEY_F11,
}

const BINDING_ORDER: Array[String] = [
	"move_forward", "move_back", "move_left", "move_right",
	"jump", "crouch", "reload", "grenade",
	"slot_1", "slot_2", "slot_3", "slot_4",
	"fullscreen",
]

const BINDING_LABELS: Dictionary = {
	"move_forward": "Vorwärts",
	"move_back": "Rückwärts",
	"move_left": "Links",
	"move_right": "Rechts",
	"jump": "Springen",
	"crouch": "Ducken",
	"reload": "Nachladen",
	"grenade": "Granate",
	"slot_1": "Waffe Slot 1",
	"slot_2": "Waffe Slot 2",
	"slot_3": "Waffe Slot 3",
	"slot_4": "Waffe Slot 4",
	"fullscreen": "Vollbild",
}

static var _loaded: bool = false

static func ensure_loaded() -> void:
	if not _loaded:
		load_config()

static func load_config() -> void:
	_loaded = true
	bindings = DEFAULT_BINDINGS.duplicate()
	var config: ConfigFile = ConfigFile.new()
	if config.load(PATH) != OK:
		apply()
		return
	sensitivity = config.get_value("input", "sensitivity", DEFAULT_SENSITIVITY)
	invert_y = config.get_value("input", "invert_y", DEFAULT_INVERT_Y)
	fov = config.get_value("video", "fov", DEFAULT_FOV)
	fullscreen = config.get_value("video", "fullscreen", DEFAULT_FULLSCREEN)
	master_volume = config.get_value("audio", "master_volume", DEFAULT_VOLUME)
	difficulty = config.get_value("game", "difficulty", DEFAULT_DIFFICULTY)
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
	var loaded_bindings: Variant = config.get_value("input", "bindings", {})
	if loaded_bindings is Dictionary:
		for action: String in DEFAULT_BINDINGS.keys():
			if loaded_bindings.has(action):
				bindings[action] = int(loaded_bindings[action])
	apply()

static func save_config() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("input", "sensitivity", sensitivity)
	config.set_value("input", "invert_y", invert_y)
	config.set_value("video", "fov", fov)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("game", "difficulty", difficulty)
	config.set_value("game", "weapon_slots", weapon_slots)
	config.set_value("input", "bindings", bindings)
	config.save(PATH)

static func reset_defaults() -> void:
	sensitivity = DEFAULT_SENSITIVITY
	fov = DEFAULT_FOV
	master_volume = DEFAULT_VOLUME
	difficulty = DEFAULT_DIFFICULTY
	invert_y = DEFAULT_INVERT_Y
	fullscreen = DEFAULT_FULLSCREEN
	weapon_slots = [0, 1, 2, 3]
	bindings = DEFAULT_BINDINGS.duplicate()
	apply()
	save_config()

static func apply() -> void:
	register_bindings()
	_apply_window_mode()
	AudioServer.set_bus_mute(0, master_volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(master_volume, 0.0001, 1.0)))

## Fenstermodus anhand von `fullscreen` setzen.
static func _apply_window_mode() -> void:
	var mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)

## Vollbild an-/ausschalten (z. B. per Hotkey).
static func toggle_fullscreen() -> void:
	set_fullscreen(not fullscreen)

static func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_window_mode()
	save_config()

## Aktuelle Taste (physical keycode) einer Aktion.
static func key_for(action: String) -> int:
	return int(bindings.get(action, DEFAULT_BINDINGS.get(action, KEY_NONE)))

## Anzeigename der aktuell belegten Taste einer Aktion.
static func key_name(action: String) -> String:
	var key: int = key_for(action)
	if key == KEY_NONE:
		return "-"
	return OS.get_keycode_string(key)

## Neue Taste fuer eine Aktion setzen, in InputMap uebernehmen und speichern.
static func set_binding(action: String, keycode: int) -> void:
	if not DEFAULT_BINDINGS.has(action):
		return
	bindings[action] = keycode
	register_action(action)
	save_config()

static func register_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key_for(action)
	InputMap.action_add_event(action, event)

## Alle belegbaren Aktionen in die InputMap schreiben.
static func register_bindings() -> void:
	for action: String in DEFAULT_BINDINGS.keys():
		register_action(action)

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
