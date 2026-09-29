extends CharacterBody3D

const WALK_SPEED: float = 7.0
const JUMP_SPEED: float = 5.0
const MOUSE_SENSITIVITY: float = 0.002
const WEAPON_NAMES: Array[String] = ["PISTOLE", "STURMGEWEHR", "SCHROTFLINTE"]
const MAGAZINE_SIZES: Array[int] = [12, 30, 6]
const FIRE_DELAYS: Array[float] = [0.28, 0.10, 0.72]
const CrosshairDrawer: Script = preload("res://crosshair.gd")

var score: int = 0
var targets_left: int = 0
var health: int = 100
var pitch: float = 0.0
var current_weapon: int = 0
var ammo: Array[int] = [12, 30, 6]
var fire_cooldown: float = 0.0
var reload_time: float = 0.0
var hud_label: Label
var health_bar: ProgressBar
var camera: Camera3D
var crosshair: Control
var weapon_model: MeshInstance3D
var message_label: Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_arena()
	_build_player()
	_build_hud()
	_spawn_targets()
	_update_hud()
	var attack_timer: Timer = Timer.new()
	attack_timer.wait_time = 3.5
	attack_timer.timeout.connect(_targets_attack)
	add_child(attack_timer)
	attack_timer.start()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_shoot()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		pitch = clampf(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.35, 1.35)
		camera.rotation.x = pitch
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		elif event.keycode == KEY_1:
			_select_weapon(0)
		elif event.keycode == KEY_2:
			_select_weapon(1)
		elif event.keycode == KEY_3:
			_select_weapon(2)
		elif event.keycode == KEY_R:
			_reload()
		elif event.keycode == KEY_SPACE and health <= 0:
			get_tree().reload_current_scene()

func _process(delta: float) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if reload_time > 0.0:
		reload_time -= delta
		if reload_time <= 0.0:
			ammo[current_weapon] = MAGAZINE_SIZES[current_weapon]
			_update_hud()
	if crosshair != null:
		crosshair.queue_redraw()

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_SPEED
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	velocity.x = direction.x * WALK_SPEED
	velocity.z = direction.z * WALK_SPEED
	move_and_slide()

func _build_player() -> void:
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.58
	camera.current = true
	add_child(camera)
	weapon_model = MeshInstance3D.new()
	var weapon_mesh: BoxMesh = BoxMesh.new()
	weapon_mesh.size = Vector3(0.16, 0.16, 0.62)
	weapon_model.mesh = weapon_mesh
	weapon_model.position = Vector3(0.28, -0.25, -0.48)
	var weapon_mat: StandardMaterial3D = StandardMaterial3D.new()
	weapon_mat.albedo_color = Color(0.13, 0.18, 0.22)
	weapon_mat.metallic = 0.65
	weapon_mat.roughness = 0.3
	weapon_model.material_override = weapon_mat
	camera.add_child(weapon_model)

func _build_arena() -> void:
	_add_box(Vector3(0, -0.5, 0), Vector3(34, 1, 34), Color(0.12, 0.18, 0.22), true)
	_add_box(Vector3(0, 2, -17), Vector3(34, 4, 0.5), Color(0.15, 0.25, 0.3), true)
	_add_box(Vector3(0, 2, 17), Vector3(34, 4, 0.5), Color(0.15, 0.25, 0.3), true)
	_add_box(Vector3(-17, 2, 0), Vector3(0.5, 4, 34), Color(0.15, 0.25, 0.3), true)
	_add_box(Vector3(17, 2, 0), Vector3(0.5, 4, 34), Color(0.15, 0.25, 0.3), true)
	for i: int in range(6):
		var x: float = -10.0 + float(i % 3) * 10.0
		var z: float = -7.0 + float(i / 3.0) * 14.0
		if i != 2 and i != 3:
			_add_box(Vector3(x, 0.8, z), Vector3(2.4, 1.6, 2.4), Color(0.22, 0.34, 0.36), true)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.4
	add_child(light)

func _add_box(pos: Vector3, size: Vector3, color: Color, solid: bool) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	add_child(body)
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh_node.material_override = material
	body.add_child(mesh_node)
	if solid:
		var collision: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = size
		collision.shape = box
		body.add_child(collision)

func _spawn_targets() -> void:
	var positions: Array[Vector3] = [Vector3(-12, 2.0, -12), Vector3(12, 2.0, -12), Vector3(-12, 2.0, 12), Vector3(12, 2.0, 12), Vector3(-6, 2.0, -14), Vector3(6, 2.0, -14)]
	for pos: Vector3 in positions:
		var target: StaticBody3D = StaticBody3D.new()
		target.position = pos
		target.add_to_group("targets")
		add_child(target)
		var target_mesh: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.65
		sphere.height = 1.3
		target_mesh.mesh = sphere
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.22, 0.08)
		mat.emission_enabled = true
		mat.emission = Color(0.8, 0.08, 0.02)
		target_mesh.material_override = mat
		target.add_child(target_mesh)
		var hit_shape: CollisionShape3D = CollisionShape3D.new()
		var hit_sphere: SphereShape3D = SphereShape3D.new()
		hit_sphere.radius = 0.7
		hit_shape.shape = hit_sphere
		target.add_child(hit_shape)
		targets_left += 1

func _shoot() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or health <= 0 or reload_time > 0.0 or fire_cooldown > 0.0:
		return
	if ammo[current_weapon] <= 0:
		_reload()
		return
	ammo[current_weapon] -= 1
	fire_cooldown = FIRE_DELAYS[current_weapon]
	var pellet_count: int = 5 if current_weapon == 2 else 1
	for pellet: int in range(pellet_count):
		var spread: Vector2 = Vector2.ZERO
		if pellet_count > 1:
			spread = Vector2(randf_range(-0.035, 0.035), randf_range(-0.035, 0.035))
		var direction: Vector3 = -camera.global_basis.z + camera.global_basis.x * spread.x + camera.global_basis.y * spread.y
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + direction.normalized() * 100.0)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var collider: Object = hit.get("collider")
			if collider is Node and collider.is_in_group("targets"):
				collider.queue_free()
				score += 1
				targets_left -= 1
	_update_hud()

func _select_weapon(index: int) -> void:
	current_weapon = index
	reload_time = 0.0
	_update_hud()

func _reload() -> void:
	if reload_time > 0.0 or ammo[current_weapon] >= MAGAZINE_SIZES[current_weapon]:
		return
	reload_time = 1.25 if current_weapon != 2 else 1.6
	_update_hud()

func _targets_attack() -> void:
	if health <= 0:
		return
	health = maxi(0, health - 10)
	if health == 0:
		message_label.text = "DU BIST K.O. – Leertaste zum Neustart"
	_update_hud()

func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	hud_label = Label.new()
	hud_label.position = Vector2(24, 20)
	hud_label.add_theme_font_size_override("font_size", 22)
	hud_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.92))
	layer.add_child(hud_label)
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(24, 54)
	health_bar.size = Vector2(280, 22)
	health_bar.max_value = 100.0
	health_bar.show_percentage = false
	layer.add_child(health_bar)
	crosshair = Control.new()
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.set_script(CrosshairDrawer)
	layer.add_child(crosshair)
	message_label = Label.new()
	message_label.anchor_left = 0.25
	message_label.anchor_right = 0.75
	message_label.anchor_top = 0.12
	message_label.anchor_bottom = 0.2
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 25)
	message_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
	layer.add_child(message_label)
	var tips: Label = Label.new()
	tips.text = "WASD bewegen | SPACE springen | Maus zielen | Klick schießen | 1/2/3 Waffen | R nachladen | ESC Maus lösen"
	tips.anchor_left = 0.0
	tips.anchor_right = 1.0
	tips.anchor_top = 1.0
	tips.anchor_bottom = 1.0
	tips.offset_top = -38.0
	tips.offset_bottom = 0.0
	tips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tips.add_theme_color_override("font_color", Color(0.8, 0.9, 0.95))
	layer.add_child(tips)

func _update_hud() -> void:
	if hud_label == null:
		return
	health_bar.value = health
	var ammo_text: String = "NACHLADEN..." if reload_time > 0.0 else "%d / %d" % [ammo[current_weapon], MAGAZINE_SIZES[current_weapon]]
	hud_label.text = "LEBEN: %d / 100   |   %s   |   MUNITION: %s   |   TREFFER: %d   |   ZIELE: %d" % [health, WEAPON_NAMES[current_weapon], ammo_text, score, targets_left]
