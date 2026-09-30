extends CharacterBody3D

const SPEED: float = 7.0
const GRAVITY: float = 18.0
const CLIMB_SPEED: float = 4.5
const LADDER_JUMP: float = 6.0
const MAX_HEALTH: int = 100
const REGEN_DELAY: float = 5.0
const REGEN_RATE: float = 9.0
const MAGAZINES: Array[int] = [12, 30, 5, 6]
const FIRE_INTERVALS: Array[float] = [0.28, 0.095, 1.10, 0.72]
const RELOAD_LENGTHS: Array[float] = [1.2, 1.6, 2.4, 1.9]
const ADS_FOV: Array[float] = [50.0, 45.0, 16.0, 48.0]
const PELLETS: Array[int] = [1, 1, 1, 7]
const BODY_DAMAGE: Array[int] = [34, 20, 30, 9]
const HEAD_MULT: Array[float] = [2.0, 1.5, 10.0, 2.0]
const HUD_SCENE: PackedScene = preload("res://hud_pro.tscn")
const TRACER_SCRIPT: Script = preload("res://weapon_tracer.gd")
const IMPACT_SCRIPT: Script = preload("res://weapon_impact.gd")
const GRENADE_SCRIPT: Script = preload("res://grenade.gd")
const THROW_SPEED: float = 17.0
const GRENADE_COUNT: int = 3

@onready var camera: Camera3D = $Camera3D
@onready var viewmodel: Node3D = $Camera3D/Viewmodel
@onready var muzzle_light: OmniLight3D = $Camera3D/Viewmodel/MuzzleFlash
@onready var ladder_sensor: Area3D = $LadderSensor

var health: int = MAX_HEALTH
var score: int = 0
var selected_weapon: int = 0
var wid: int = 0
var regen_timer: float = 0.0
var regen_accum: float = 0.0
var ammunition: Array[int] = [12, 30, 5, 6]
var cooldown: float = 0.0
var reloading_for: float = 0.0
var pitch: float = 0.0
var bob_phase: float = 0.0
var recoil_amount: float = 0.0
var hit_time: float = 0.0
var hud: Control
var hit_marker: Label
var aiming: bool = false
var aim_blend: float = 0.0
var ladder_area: Area3D = null
var ladder_cooldown: float = 0.0
var mantle_time: float = 0.0
var mantle_velocity: Vector3 = Vector3.ZERO
var grenades: int = GRENADE_COUNT

func _ready() -> void:
	GameConfig.ensure_loaded()
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	wid = GameConfig.weapon_slots[selected_weapon]
	camera.fov = GameConfig.fov
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
	viewmodel.call("build_weapon", wid)
	hud.call("set_grenades", grenades)
	update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = GameConfig.sensitivity * (1.0 - 0.55 * aim_blend)
		var dy_sign: float = -1.0 if GameConfig.invert_y else 1.0
		rotate_y(-event.relative.x * sens)
		pitch = clampf(pitch - event.relative.y * sens * dy_sign, -1.25, 1.25)
		camera.rotation.x = pitch
		viewmodel.call("add_look", event.relative.x, event.relative.y)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			shoot()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			aiming = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select_weapon(posmod(selected_weapon - 1, GameConfig.weapon_slots.size()))
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_weapon((selected_weapon + 1) % GameConfig.weapon_slots.size())
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: select_weapon(0)
			KEY_2: select_weapon(1)
			KEY_3: select_weapon(2)
			KEY_4: select_weapon(3)
			KEY_R: reload_weapon()
			KEY_G: throw_grenade()

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	ladder_cooldown = maxf(ladder_cooldown - delta, 0.0)
	_update_ladder()
	var move_axis: Vector2 = Vector2.ZERO
	move_axis.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	move_axis.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	move_axis = move_axis.normalized()
	if mantle_time > 0.0:
		mantle_time = maxf(mantle_time - delta, 0.0)
		velocity = mantle_velocity
	elif ladder_area != null and ladder_cooldown <= 0.0:
		_climb(move_axis)
	else:
		_walk(delta, move_axis)
	move_and_slide()
	cooldown = maxf(cooldown - delta, 0.0)
	recoil_amount = move_toward(recoil_amount, 0.0, delta * 4.0)
	bob_phase += delta * (9.0 if move_axis.length() > 0.0 else 0.0)
	aim_blend = move_toward(aim_blend, 1.0 if aiming else 0.0, delta * 7.0)
	camera.fov = lerpf(GameConfig.fov, ADS_FOV[wid], aim_blend)
	viewmodel.call("set_aim", aim_blend)
	viewmodel.call("set_motion", bob_phase, recoil_amount)
	if hud != null:
		hud.call("set_aim", aim_blend > 0.5)
		hud.call("set_scope", wid == 2 and aim_blend > 0.35)
	if health > 0 and health < MAX_HEALTH:
		regen_timer = maxf(regen_timer - delta, 0.0)
		if regen_timer == 0.0:
			regen_accum += REGEN_RATE * delta
			var whole: int = int(regen_accum)
			if whole > 0:
				regen_accum -= float(whole)
				health = mini(MAX_HEALTH, health + whole)
				if health == MAX_HEALTH:
					regen_accum = 0.0
				update_hud()
	if reloading_for > 0.0:
		reloading_for = maxf(reloading_for - delta, 0.0)
		if reloading_for == 0.0:
			ammunition[wid] = MAGAZINES[wid]
		update_hud()
	if hit_time > 0.0:
		hit_time -= delta
		if hit_time <= 0.0:
			hud.call("set_hit", false)
			hit_marker.visible = false

func _walk(delta: float, move_axis: Vector2) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = 5.0
	var direction: Vector3 = (transform.basis * Vector3(move_axis.x, 0.0, move_axis.y)).normalized()
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

func _climb(move_axis: Vector2) -> void:
	# Step off the top of the ladder onto the roof / platform above it.
	var normal: Vector3 = ladder_area.global_basis.z
	var top: float = 9999.0
	if ladder_area.has_meta("top_y"):
		top = float(ladder_area.get_meta("top_y"))
	if Input.is_key_pressed(KEY_W) and global_position.y >= top - 0.25:
		mantle_time = 0.32
		mantle_velocity = Vector3(-normal.x, 0.0, -normal.z).normalized() * 4.2 + Vector3(0.0, 3.8, 0.0)
		ladder_cooldown = 0.5
		velocity = mantle_velocity
		return
	velocity.y = 0.0
	if Input.is_key_pressed(KEY_W):
		velocity.y = CLIMB_SPEED
	elif Input.is_key_pressed(KEY_S):
		velocity.y = -CLIMB_SPEED
	var side: Vector3 = transform.basis.x * move_axis.x * 2.2
	velocity.x = side.x
	velocity.z = side.z
	if Input.is_key_pressed(KEY_SPACE):
		velocity.y = LADDER_JUMP
		ladder_cooldown = 0.45
	_face_ladder()

func _update_ladder() -> void:
	ladder_area = null
	if ladder_sensor == null:
		return
	for area: Area3D in ladder_sensor.get_overlapping_areas():
		if area.is_in_group("ladders") or area.has_meta("top_y"):
			ladder_area = area
			break

func _face_ladder() -> void:
	if ladder_area == null:
		return
	var to_ladder: Vector3 = ladder_area.global_position - global_position
	to_ladder.y = 0.0
	if to_ladder.length() < 0.05:
		return
	rotation.y = atan2(-to_ladder.x, -to_ladder.z)

func shoot() -> void:
	if health <= 0 or cooldown > 0.0 or reloading_for > 0.0:
		return
	if ammunition[wid] <= 0:
		reload_weapon()
		return
	ammunition[wid] -= 1
	cooldown = FIRE_INTERVALS[wid]
	recoil_amount = 1.0
	viewmodel.call("fire")
	var pellets: int = PELLETS[wid]
	var scored_hit: bool = false
	var headshot_hit: bool = false
	var spread_scale: float = 0.35 if aim_blend > 0.5 else 1.0
	for pellet: int in range(pellets):
		var spread: Vector2 = Vector2.ZERO
		if pellets > 1:
			spread = Vector2(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05)) * spread_scale
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
			if target is Node and target.has_method("take_damage"):
				var headshot: bool = false
				if target.has_method("is_headshot"):
					headshot = target.call("is_headshot", endpoint)
				var damage: float = BODY_DAMAGE[wid] * (HEAD_MULT[wid] if headshot else 1.0)
				target.call("take_damage", int(round(damage)))
				scored_hit = true
				if headshot:
					headshot_hit = true
		spawn_tracer(origin, endpoint)
	if scored_hit:
		hud.call("set_hit", true)
		hit_marker.visible = true
		hit_marker.add_theme_color_override("font_color", Color(1.0, 0.25, 0.15) if headshot_hit else Color(1.0, 0.45, 0.2))
		hit_marker.add_theme_font_size_override("font_size", 34 if headshot_hit else 26)
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
	if index < 0 or index >= GameConfig.weapon_slots.size():
		return
	selected_weapon = index
	wid = GameConfig.weapon_slots[index]
	reloading_for = 0.0
	aiming = false
	viewmodel.call("build_weapon", wid)
	update_hud()

func reload_weapon() -> void:
	if reloading_for > 0.0 or ammunition[wid] >= MAGAZINES[wid]:
		return
	reloading_for = RELOAD_LENGTHS[wid]
	update_hud()

func throw_grenade() -> void:
	if health <= 0 or grenades <= 0:
		return
	grenades -= 1
	if hud != null:
		hud.call("set_grenades", grenades)
	var grenade: RigidBody3D = RigidBody3D.new()
	grenade.set_script(GRENADE_SCRIPT)
	get_tree().current_scene.add_child(grenade)
	grenade.global_position = camera.global_position - camera.global_basis.z * 0.7
	var dir: Vector3 = -camera.global_basis.z
	grenade.call("launch", dir * THROW_SPEED + Vector3(0.0, 3.2, 0.0))

func update_hud() -> void:
	if hud == null:
		return
	hud.call("update_hud", health, GameConfig.WEAPON_NAMES[wid], ammunition[wid], MAGAZINES[wid], score, reloading_for > 0.0)
	hud.call("set_weapon_slot", selected_weapon)

func apply_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(0, health - amount)
	regen_timer = REGEN_DELAY
	regen_accum = 0.0
	update_hud()
	if health <= 0 and hud != null:
		hud.call("set_status", "AUSGESCHALTET")

func add_kill() -> void:
	score += 1
	update_hud()
