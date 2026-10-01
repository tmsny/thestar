class_name RemotePlayer
extends Enemy

## Der Gegner im LAN-Match. Nutzt das Körpermodell von Enemy, wird aber nicht
## von einer KI gesteuert: Position kommt per Netzwerk, Treffer werden an den
## echten Spieler weitergeleitet (der zieht sich die Lebenspunkte selbst ab).
## Bleibt in der Gruppe "enemies", damit Nahkampf und Granaten ihn treffen.

var peer_id: int = 0
var display_name: String = "GEGNER"
var alive: bool = true
var target_position: Vector3 = Vector3.ZERO
var target_yaw: float = 0.0

var _name_label: Label3D
var _snap_next: bool = true

func _ready() -> void:
	kind = Kind.TROOPER
	super()
	max_health = 100
	health = 100
	_update_bar()
	collision_layer = 2
	collision_mask = 0
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	collision.position = Vector3(0.0, 0.9, 0.0)
	add_child(collision)
	_recolor_blue()
	_name_label = Label3D.new()
	_name_label.text = display_name
	_name_label.position = Vector3(0.0, 2.35, 0.0)
	_name_label.pixel_size = 0.005
	_name_label.font_size = 56
	_name_label.outline_size = 12
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	_name_label.modulate = Color(0.55, 0.9, 1.0)
	add_child(_name_label)
	target_position = global_position
	target_yaw = rotation.y

func _recolor_blue() -> void:
	# body_materials: [armor, plate, accent, skin, gun]
	if body_materials.size() < 3:
		return
	body_materials[1].albedo_color = Color(0.12, 0.42, 0.92)
	body_materials[2].albedo_color = Color(0.35, 0.92, 1.0)

func set_display_name(new_name: String) -> void:
	display_name = new_name
	if _name_label != null:
		_name_label.text = new_name

func apply_state(pos: Vector3, yaw: float, hp: int, is_alive: bool) -> void:
	target_position = pos
	target_yaw = yaw
	health = clampi(hp, 0, max_health)
	_update_bar()
	if is_alive != alive:
		alive = is_alive
		visible = alive
		collision_layer = 2 if alive else 0
		_snap_next = true
	if _snap_next:
		_snap_next = false
		global_position = pos
		rotation.y = yaw

func flash_muzzle() -> void:
	if muzzle_light != null:
		muzzle_light.light_energy = 3.0
		muzzle_timer = 0.06

func _physics_process(delta: float) -> void:
	# Keine KI und keine Physik: nur zur gemeldeten Position gleiten.
	var weight: float = clampf(delta * 18.0, 0.0, 1.0)
	global_position = global_position.lerp(target_position, weight)
	rotation.y = lerp_angle(rotation.y, target_yaw, weight)
	if muzzle_timer > 0.0:
		muzzle_timer -= delta
		if muzzle_timer <= 0.0 and muzzle_light != null:
			muzzle_light.light_energy = 0.0
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 6.0)
		_apply_flash()

# Wird vom lokalen Spieler (Schuss, Messer, Granate) aufgerufen.
func take_damage(amount: int) -> void:
	if not alive or amount <= 0:
		return
	Net.send_damage(amount)
	flash = 1.0
	_apply_flash()

func _die() -> void:
	pass
