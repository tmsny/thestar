extends CharacterBody3D

const SPEED: float = 7.0
const GRAVITY: float = 18.0
const SENSITIVITY: float = 0.0019
const WEAPON_NAMES: Array[String] = ["PISTOLE", "STURMGEWEHR", "SCHROTFLINTE"]
const MAGAZINES: Array[int] = [12, 30, 6]
const FIRE_INTERVALS: Array[float] = [0.30, 0.095, 0.72]
const RELOAD_LENGTHS: Array[float] = [1.2, 1.6, 1.9]
const HUD_SCENE: PackedScene = preload("res://hud_pro.tscn")
const TRACER_SCRIPT: Script = preload("res://weapon_tracer.gd")
const IMPACT_SCRIPT: Script = preload("res://weapon_impact.gd")

@onready var camera: Camera3D = $Camera3D
@onready var viewmodel: Node3D = $Camera3D/Viewmodel
@onready var muzzle_light: OmniLight3D = $Camera3D/Viewmodel/MuzzleFlash

var health: int = 100
var score: int = 0
var selected_weapon: int = 0
var ammunition: Array[int] = [12, 30, 6]
var cooldown: float = 0.0
var reloading_for: float = 0.0
var pitch: float = 0.0
var bob_phase: float = 0.0
var recoil_amount: float = 0.0
var hit_time: float = 0.0
var hud: Control
var hit_marker: Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "HUDLayer"
	add_child(layer)
	hud = HUD_SCENE.instantiate() as Control
	layer.add_child(hud)
	hit_marker = Label.new()
	hit_marker.text = "×"
	hit_marker.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hit_marker.position = Vector2(-9.0, -23.0)
	hit_marker.add_theme_font_size_override("font_size", 26)
	hit_marker.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2))
	hit_marker.visible = false
	hud.add_child(hit_marker)
	viewmodel.call("build_weapon", selected_weapon)
	update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * SENSITIVITY)
		pitch = clampf(pitch - event.relative.y * SENSITIVITY, -1.25, 1.25)
		camera.rotation.x = pitch
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			shoot()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select_weapon(posmod(selected_weapon - 1, 3))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_weapon((selected_weapon + 1) % 3)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
			KEY_1: select_weapon(0)
			KEY_2: select_weapon(1)
			KEY_3: select_weapon(2)
			KEY_R: reload_weapon()
			KEY_SPACE:
				if health <= 0:
					get_tree().reload_current_scene()

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = 5.0
	var move_axis: Vector2 = Vector2.ZERO
	move_axis.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	move_axis.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	move_axis = move_axis.normalized()
	var direction: Vector3 = (transform.basis * Vector3(move_axis.x, 0.0, move_axis.y)).normalized()
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	move_and_slide()
	cooldown = maxf(cooldown - delta, 0.0)
	recoil_amount = move_toward(recoil_amount, 0.0, delta * 4.0)
	bob_phase += delta * (9.0 if move_axis.length() > 0.0 else 0.0)
	viewmodel.call("set_motion", bob_phase, recoil_amount)
	if reloading_for > 0.0:
		reloading_for = maxf(reloading_for - delta, 0.0)
		if reloading_for == 0.0:
			ammunition[selected_weapon] = MAGAZINES[selected_weapon]
		update_hud()
	if hit_time > 0.0:
		hit_time -= delta
		if hit_time <= 0.0:
			hud.call("set_hit", false)
			hit_marker.visible = false

func shoot() -> void:
	if health <= 0 or cooldown > 0.0 or reloading_for > 0.0:
		return
	if ammunition[selected_weapon] <= 0:
		reload_weapon()
		return
	ammunition[selected_weapon] -= 1
	cooldown = FIRE_INTERVALS[selected_weapon]
	recoil_amount = 1.0
	viewmodel.call("fire")
	var pellets: int = 7 if selected_weapon == 2 else 1
	var scored_hit: bool = false
	for pellet: int in range(pellets):
		var spread: Vector2 = Vector2.ZERO
		if pellets > 1:
			spread = Vector2(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05))
		var aim: Vector3 = -camera.global_basis.z + camera.global_basis.x * spread.x + camera.global_basis.y * spread.y
		var origin: Vector3 = camera.global_position
		var endpoint: Vector3 = origin + aim.normalized() * 100.0
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, endpoint)
		query.exclude = [get_rid()]
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			endpoint = hit["position"]
			var surface_normal: Vector3 = hit["normal"]
			spawn_impact(endpoint, surface_normal)
			var target: Object = hit["collider"]
			if target is Node and target.is_in_group("targets"):
				target.queue_free()
				score += 1
				scored_hit = true
		spawn_tracer(origin, endpoint)
	if scored_hit:
		hud.call("set_hit", true)
		hit_marker.visible = true
		hit_time = 0.23
	update_hud()

func spawn_tracer(origin: Vector3, endpoint: Vector3) -> void:
	var tracer: MeshInstance3D = MeshInstance3D.new()
	tracer.set_script(TRACER_SCRIPT)
	get_tree().current_scene.add_child(tracer)
	tracer.call("set_line", origin, endpoint)

func spawn_impact(position_world: Vector3, surface_normal: Vector3) -> void:
	var impact: Node3D = Node3D.new()
	impact.set_script(IMPACT_SCRIPT)
	get_tree().current_scene.add_child(impact)
	impact.global_position = position_world + surface_normal * 0.035
	impact.look_at(position_world + surface_normal, Vector3.UP)

func select_weapon(index: int) -> void:
	if index < 0 or index >= WEAPON_NAMES.size():
		return
	selected_weapon = index
	reloading_for = 0.0
	viewmodel.call("build_weapon", selected_weapon)
	update_hud()

func reload_weapon() -> void:
	if reloading_for > 0.0 or ammunition[selected_weapon] >= MAGAZINES[selected_weapon]:
		return
	reloading_for = RELOAD_LENGTHS[selected_weapon]
	update_hud()

func update_hud() -> void:
	if hud == null:
		return
	hud.call("update_hud", health, WEAPON_NAMES[selected_weapon], ammunition[selected_weapon], MAGAZINES[selected_weapon], score, reloading_for > 0.0)
