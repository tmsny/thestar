class_name TrainingDummy
extends StaticBody3D

## Stehender Trainings-NPC: greift nicht an, nimmt unbegrenzt Schaden und
## blinkt bei jedem Treffer kurz auf. Kopfschuesse werden erkannt.

const HEAD_THRESHOLD: float = 1.5
const BODY_COLOR: Color = Color(0.36, 0.42, 0.46)
const HEAD_COLOR: Color = Color(0.72, 0.62, 0.5)
const FLASH_COLOR: Color = Color(1.0, 0.32, 0.22)

var total_damage: int = 0

@onready var _body_mesh: MeshInstance3D = $Visual/Body
@onready var _head_mesh: MeshInstance3D = $Visual/Head
var _flash: float = 0.0
var _body_material: StandardMaterial3D
var _head_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("enemies")
	_body_material = _body_mesh.material_override as StandardMaterial3D
	_head_material = _head_mesh.material_override as StandardMaterial3D
	if _body_material == null or _head_material == null:
		push_error("Trainingspuppe braucht Body- und Head-Material in training_dummy_visual.tscn")
		set_process(false)

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 4.0, 0.0)
		var energy: float = _flash
		_body_material.emission_enabled = energy > 0.0
		_body_material.emission = FLASH_COLOR
		_body_material.emission_energy_multiplier = energy * 1.6
		_head_material.emission_enabled = energy > 0.0
		_head_material.emission = FLASH_COLOR
		_head_material.emission_energy_multiplier = energy * 1.6

func is_headshot(point: Vector3) -> bool:
	return (point.y - global_position.y) >= HEAD_THRESHOLD

func take_damage(amount: int) -> void:
	total_damage += amount
	_flash = 1.0
