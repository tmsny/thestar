extends CharacterBody3D

const WEAPON_NAMES: Array[String] = ["PISTOLE", "STURMGEWEHR", "SCHROTFLINTE"]
const CLIPS: Array[int] = [12, 30, 6]
const SHOT_INTERVAL: Array[float] = [0.30, 0.095, 0.72]
const RELOAD_TIME: Array[float] = [1.2, 1.6, 1.9]

@onready var camera: Camera3D = $Camera3D
@onready var viewmodel: Node3D = $Camera3D/Viewmodel
@onready var hud: Control = $HUDLayer/HUD
@onready var muzzle_flash: OmniLight3D = $Camera3D/Viewmodel/MuzzleFlash

var health: int = 100
var score: int = 0
var weapon_id: int = 0
var ammo: Array[int] = [12, 30, 6]
var cooldown: float = 0.0
var reload_remaining: float = 0.0
var look_pitch: float = 0.0
var kick: float = 0.0
var bob: float = 0.0
var fire_timer: float = 0.0
var marker_timer: float = 0.0
var tracer_script: Script = preload("res://weapon_tracer.gd")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	update_weapon()
	update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.0019)
		look_pitch = clampf(look_pitch - event.relative.y * 0.0019, -1.25, 1.25)
		camera.rotation.x = look_pitch
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			fire()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			change_weapon(posmod(weapon_id - 1, 3))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			change_weapon((weapon_id + 1) % 3)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
			KEY_1: change_weapon(0)
			KEY_2: change_weapon(1)
			KEY_3: change_weapon(2)
			KEY_R: start_reload()
			KEY_SPACE:
				if health <= 0:
					get_tree().reload_current_scene()

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = 5.0
	var input_dir: Vector2 = Vector2.ZERO
	input_dir.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	input_dir.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	input_dir = input_dir.normalized()
	var move_dir: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	velocity.x = move_dir.x * 7.0
	velocity.z = move_dir.z * 7.0
	move_and_slide()
	cooldown = maxf(0.0, cooldown - delta)
	kick = move_toward(kick, 0.0, delta * 4.0)
	if input_dir.length() > 0.0:
		bob += delta * 9.0
	else:
		bob = 0.0
	viewmodel.position.y = -0.28 + sin(bob) * 0.009 - kick * 0.07
	viewmodel.rotation.x = kick * 0.055
	if reload_remaining > 0.0:
		reload_remaining = maxf(0.0, reload_remaining - delta)
		if reload_remaining == 0.0:
			ammo[weapon_id] = CLIPS[weapon_id]
		update_hud()
	if fire_timer > 0.0:
		fire_timer -= delta
		if fire_timer <= 0.0:
			muzzle_flash.light_energy = 0.0
	if marker_timer > 0.0:
		marker_timer -= delta
		if marker_timer <= 0.0:
			hud.set_hit(false)

func fire() -> void:
	if health <= 0 or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or cooldown > 0.0 or reload_remaining > 0.0:
		return
	if ammo[weapon_id] <= 0:
		start_reload()
		return
	ammo[weapon_id] -= 1
	cooldown = SHOT_INTERVAL[weapon_id]
	kick = 1.0
	muzzle_flash.light_energy = 4.0
	fire_timer = 0.055
	var pellet_count: int = 7 if weapon_id == 2 else 1
	var did_hit: bool = false
	for pellet: int in range(pellet_count):
		var spread: Vector2 = Vector2.ZERO
		if pellet_count > 1:
			spread = Vector2(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05))
		var aim_dir: Vector3 = -camera.global_basis.z + camera.global_basis.x * spread.x + camera.global_basis.y * spread.y
		var ray_start: Vector3 = camera.global_position
		var ray_end: Vector3 = ray_start + aim_dir.normalized() * 100.0
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.exclude = [get_rid()]
		var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not result.is_empty():
			ray_end = result["position"]
			var body: Object = result["collider"]
			if body is Node and body.is_in_group("targets"):
				body.queue_free()
				score += 1
				did_hit = true
		spawn_tracer(ray_start, ray_end)
	if did_hit:
		hud.set_hit(true)
		marker_timer = 0.22
	update_hud()

func spawn_tracer(start: Vector3, finish: Vector3) -> void:
	var tracer: MeshInstance3D = MeshInstance3D.new()
	tracer.set_script(tracer_script)
	get_tree().current_scene.add_child(tracer)
	tracer.call("set_line", start, finish)

func change_weapon(index: int) -> void:
	if index < 0 or index >= 3:
		return
	weapon_id = index
	reload_remaining = 0.0
	update_weapon()
	update_hud()

func update_weapon() -> void:
	viewmodel.call("build_weapon", weapon_id)

func start_reload() -> void:
	if reload_remaining > 0.0 or ammo[weapon_id] >= CLIPS[weapon_id]:
		return
	reload_remaining = RELOAD_TIME[weapon_id]
	update_hud()

func update_hud() -> void:
	hud.call("update_hud", health, WEAPON_NAMES[weapon_id], ammo[weapon_id], CLIPS[weapon_id], score, reload_remaining > 0.0)
