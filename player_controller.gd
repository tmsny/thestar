extends CharacterBody3D

const SPEED: float = 7.0
const JUMP_VELOCITY: float = 5.0
const SENSITIVITY: float = 0.002
const NAMES: Array[String] = ["PISTOLE", "STURMGEWEHR", "SCHROTFLINTE"]
const CLIPS: Array[int] = [12, 30, 6]
const DELAYS: Array[float] = [0.28, 0.1, 0.72]

var health: int = 100
var score: int = 0
var weapon: int = 0
var ammo: Array[int] = [12, 30, 6]
var shot_wait: float = 0.0
var reload_wait: float = 0.0
var pitch: float = 0.0
var hud: Label
var camera: Camera3D
var bar: ProgressBar

func _ready() -> void:
	camera = $Camera3D
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_hud()
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * SENSITIVITY)
		pitch = clampf(pitch - event.relative.y * SENSITIVITY, -1.35, 1.35)
		camera.rotation.x = pitch
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		shoot()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
			KEY_1: select_weapon(0)
			KEY_2: select_weapon(1)
			KEY_3: select_weapon(2)
			KEY_R: reload()
			KEY_SPACE:
				if health <= 0: get_tree().reload_current_scene()

func _physics_process(delta: float) -> void:
	if health <= 0: return
	if not is_on_floor(): velocity.y -= 18.0 * delta
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor(): velocity.y = JUMP_VELOCITY
	var direction_input: Vector2 = Vector2.ZERO
	direction_input.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	direction_input.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	direction_input = direction_input.normalized()
	var direction: Vector3 = (transform.basis * Vector3(direction_input.x, 0.0, direction_input.y)).normalized()
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	move_and_slide()
	shot_wait = maxf(shot_wait - delta, 0.0)
	if reload_wait > 0.0:
		reload_wait -= delta
		if reload_wait <= 0.0:
			ammo[weapon] = CLIPS[weapon]
		_update_hud()

func shoot() -> void:
	if health <= 0 or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or shot_wait > 0.0 or reload_wait > 0.0: return
	if ammo[weapon] <= 0: reload(); return
	ammo[weapon] -= 1
	shot_wait = DELAYS[weapon]
	var pellets: int = 5 if weapon == 2 else 1
	for i: int in range(pellets):
		var spread: Vector2 = Vector2(randf_range(-0.04, 0.04), randf_range(-0.04, 0.04)) if pellets > 1 else Vector2.ZERO
		var forward: Vector3 = -camera.global_basis.z + camera.global_basis.x * spread.x + camera.global_basis.y * spread.y
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + forward.normalized() * 100.0)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var thing: Object = hit.get("collider")
			if thing is Node and thing.is_in_group("targets"):
				thing.queue_free()
				score += 1
	_update_hud()

func select_weapon(index: int) -> void:
	weapon = index
	reload_wait = 0.0
	_update_hud()

func reload() -> void:
	if ammo[weapon] < CLIPS[weapon] and reload_wait <= 0.0:
		reload_wait = 1.5
	_update_hud()

func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24, 16)
	hud.add_theme_font_size_override("font_size", 21)
	layer.add_child(hud)
	bar = ProgressBar.new()
	bar.position = Vector2(24, 48)
	bar.size = Vector2(250, 20)
	bar.max_value = 100
	bar.show_percentage = false
	layer.add_child(bar)
	var crosshair: Label = Label.new()
	crosshair.text = "┼"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-12, -22)
	crosshair.add_theme_font_size_override("font_size", 30)
	crosshair.add_theme_color_override("font_color", Color.YELLOW)
	layer.add_child(crosshair)
	var hint: Label = Label.new()
	hint.text = "WASD bewegen  |  SPACE springen  |  Maus zielen  |  Linksklick schießen  |  1/2/3 Waffen  |  R nachladen  |  ESC Maus"
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -32
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(hint)

func _update_hud() -> void:
	if hud == null: return
	bar.value = health
	var ammo_label: String = "NACHLADEN..." if reload_wait > 0 else "%d/%d" % [ammo[weapon], CLIPS[weapon]]
	hud.text = "LEBEN %d/100   |   %s   |   MUNITION %s   |   TREFFER %d" % [health, NAMES[weapon], ammo_label, score]
