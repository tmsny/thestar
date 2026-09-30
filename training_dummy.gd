class_name TrainingDummy
extends StaticBody3D

## Stehender Trainings-NPC: greift nicht an, nimmt unbegrenzt Schaden und
## blinkt bei jedem Treffer kurz auf. Kopfschuesse werden erkannt.

const HEAD_THRESHOLD: float = 1.5
const BODY_COLOR: Color = Color(0.36, 0.42, 0.46)
const HEAD_COLOR: Color = Color(0.72, 0.62, 0.5)
const FLASH_COLOR: Color = Color(1.0, 0.32, 0.22)

var total_damage: int = 0

var _body_material: StandardMaterial3D
var _head_material: StandardMaterial3D
var _flash: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	_build()

func _build() -> void:
	_body_material = _material(BODY_COLOR)
	_head_material = _material(HEAD_COLOR)

	# Koerper / Beine
	var body_shape: CapsuleShape3D = CapsuleShape3D.new()
	body_shape.radius = 0.36
	body_shape.height = 1.5
	var body_collision: CollisionShape3D = CollisionShape3D.new()
	body_collision.shape = body_shape
	body_collision.position = Vector3(0.0, 0.75, 0.0)
	add_child(body_collision)

	var body_mesh: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.36
	capsule.height = 1.5
	body_mesh.mesh = capsule
	body_mesh.position = Vector3(0.0, 0.75, 0.0)
	body_mesh.material_override = _body_material
	add_child(body_mesh)

	# Kopf
	var head_shape: SphereShape3D = SphereShape3D.new()
	head_shape.radius = 0.2
	var head_collision: CollisionShape3D = CollisionShape3D.new()
	head_collision.shape = head_shape
	head_collision.position = Vector3(0.0, 1.66, 0.0)
	add_child(head_collision)

	var head_mesh: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	head_mesh.mesh = sphere
	head_mesh.position = Vector3(0.0, 1.66, 0.0)
	head_mesh.material_override = _head_material
	add_child(head_mesh)

func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material

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