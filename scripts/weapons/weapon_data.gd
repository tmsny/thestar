class_name WeaponData
extends RefCounted

## Zentraler Waffen-Katalog: eine Quelle der Wahrheit fuer Spielverhalten UND
## Anzeige im Waffen-Menue. Index = Waffe (wid). Es gibt 10 Waffen.

const COUNT: int = 10
const BURST_WEAPON: int = 6
const GRENADE_LAUNCHER: int = 9
const MELEE_WEAPONS: Array[int] = [5, 8]

const MAGAZINES: Array[int] = [12, 30, 5, 6, 18, 999999, 24, 6, 999999, 4]
const FIRE_INTERVALS: Array[float] = [0.28, 0.095, 1.10, 0.72, 0.20, 0.55, 0.075, 0.62, 0.90, 1.15]
const RELOAD_LENGTHS: Array[float] = [1.2, 1.6, 2.4, 1.9, 1.5, 0.0, 1.8, 2.0, 0.0, 2.2]
const ADS_FOV: Array[float] = [50.0, 45.0, 16.0, 48.0, 48.0, 78.0, 44.0, 42.0, 78.0, 52.0]
const PELLETS: Array[int] = [1, 1, 1, 7, 1, 1, 1, 1, 1, 1]
const BODY_DAMAGE: Array[int] = [34, 20, 30, 9, 24, 90, 12, 58, 150, 0]
const HEAD_MULT: Array[float] = [2.0, 1.5, 10.0, 2.0, 1.5, 1.0, 1.5, 1.8, 1.0, 1.0]
const AUTOMATIC: Array[bool] = [false, true, false, false, true, false, false, false, false, false]
const MELEE_REACH: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 2.1, 0.0, 0.0, 1.7, 0.0]

static func _clamp(index: int) -> int:
	return clampi(index, 0, COUNT - 1)

static func damage(index: int) -> int:
	return BODY_DAMAGE[_clamp(index)]

static func head_mult(index: int) -> float:
	return HEAD_MULT[_clamp(index)]

static func magazine(index: int) -> int:
	return MAGAZINES[_clamp(index)]

static func shots_per_second(index: int) -> float:
	var interval: float = FIRE_INTERVALS[_clamp(index)]
	return 0.0 if interval <= 0.0 else 1.0 / interval

static func mode_text(index: int) -> String:
	var i: int = _clamp(index)
	if i in MELEE_WEAPONS:
		return "Nahkampf"
	if i == GRENADE_LAUNCHER:
		return "Projektil"
	if i == BURST_WEAPON:
		return "3er-Salve"
	if AUTOMATIC[i]:
		return "Automatik"
	return "Einzelfeuer"

static func ammo_text(index: int) -> String:
	var i: int = _clamp(index)
	if i in MELEE_WEAPONS:
		return "unbegrenzt"
	return str(MAGAZINES[i])