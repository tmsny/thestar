extends CharacterBody3D

const SPEED: float = 7.0
const GRAVITY: float = 18.0
const CLIMB_SPEED: float = 4.5
const LADDER_JUMP: float = 6.0
const MAX_HEALTH: int = 100
const REGEN_DELAY: float = 5.0
const REGEN_RATE: float = 9.0
const MAGAZINES: Array[int] = [12, 30, 5, 6, 18, 999999, 24, 6, 999999, 4]
const FIRE_INTERVALS: Array[float] = [0.28, 0.095, 1.10, 0.72, 0.20, 0.55, 0.075, 0.62, 0.90, 1.15]
const RELOAD_LENGTHS: Array[float] = [1.2, 1.6, 2.4, 1.9, 1.5, 0.0, 1.8, 2.0, 0.0, 2.2]
const ADS_FOV: Array[float] = [50.0, 45.0, 16.0, 48.0, 48.0, 78.0, 44.0, 42.0, 78.0, 52.0]
const PELLETS: Array[int] = [1, 1, 1, 7, 1, 1, 1, 1, 1, 1]
const BODY_DAMAGE: Array[int] = [34, 20, 30, 9, 24, 48, 12, 58, 72, 0]
const HEAD_MULT: Array[float] = [2.0, 1.5, 10.0, 2.0, 1.5, 1.0, 1.5, 1.8, 1.0, 1.0]
const AUTOMATIC: Array[bool] = [false, true, false, false, true, false, false, false, false, false]
const MELEE_REACH: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 2.1, 0.0, 0.0, 1.7, 0.0]
const HUD_SCENE: PackedScene = preload("res://hud_pro.tscn")
const TRACER_SCRIPT: Script = preload("res://weapon_tracer.gd")
const IMPACT_SCRIPT: Script = preload("res://weapon_impact.gd")
const GRENADE_SCRIPT: Script = preload("res://grenade.gd")
const THROW_SPEED: float = 17.0
const GRENADE_COUNT: int = 3
const WEAPON_COUNT: int = 10
const BURST_WEAPON: int = 6
const GRENADE_LAUNCHER: int = 9

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
var ammunition: Array[int] = []
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
var firing: bool = false
var burst_shots_left: int = 0
var burst_timer: float = 0.0
var controls_enabled: bool = true

func _ready() -> void:
	GameConfig.ensure_loaded()
	if GameConfig.weapon_slots.size() != 4:
		GameConfig.weapon_slots = [0, 1, 2, 3]
	for magazine: int in MAGAZINES:
		ammunition.append(magazine)
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
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = GameConfig.sensitivity * (1.0 - 0.55 * aim_blend)
		var dy_sign: float = -1.0 if GameConfig.invert_y else 1.0
		rotate_y(-event.relative.x * sens)
		pitch = clampf(pitch - event.relative.y * sens * dy_sign, -1.25, 1.25)
		camera.rotation.x = pitch
		viewmodel.call("add_look", event.relative.x, event.relative.y)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			firing = event.pressed
			if event.pressed:
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
			KEY_5: select_weapon(4)
			KEY_6: select_weapon(5)
			KEY_7: select_weapon(6)
			KEY_8: select_weapon(7)
			KEY_9: select_weapon(8)
			KEY_0: select_weapon(9)
			KEY_R: reload_weapon()
			KEY_G: throw_grenade()

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	controls_enabled = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if not controls_enabled:
		firing = false
		aiming = false
	ladder_cooldown = maxf(ladder_cooldown - delta, 0.0)
	_update_ladder()
	var move_axis: Vector2 = Vector2.ZERO
	move_axis.x = float(_key(KEY_D)) - float(_key(KEY_A))
	move_axis.y = float(_key(KEY_S)) - float(_key(KEY_W))
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
	burst_timer = maxf(burst_timer - delta, 0.0)
	if burst_shots_left > 0 and burst_timer <= 0.0:
		burst_shots_left -= 1
		_fire_round()
		burst_timer = 0.075
	if firing and controls_enabled and AUTOMATIC[wid]:
		shoot()
	if wid == GRENADE_LAUNCHER or wid == 5 or wid == 8:
		aim_blend = 0.0
	recoil_amount = move_toward(recoil_amount, 0.0, delta * 4.0)
	bob_phase += delta * (9.0 if move_axis.length() > 0.0 else 0.0)
	aim_blend = move_toward(aim_blend, 1.0 if aiming else 0.0, delta * 7.0)
	camera.fov = lerpf(GameConfig.fov, ADS_FOV[wid], aim_blend)
	var scoped_now: bool = wid == 2 and aim_blend > 0.6
	viewmodel.visible = not scoped_now
	viewmodel.call("set_aim", aim_blend)
	viewmodel.call("set_motion", bob_phase, recoil_amount)
	if hud != null:
		hud.call("set_aim", aim_blend > 0.5)
		hud.call("set_scope", scoped_now)
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
			if wid == 5 or wid == 8:
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
	if _key(KEY_SPACE) and is_on_floor():
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
	if _key(KEY_W) and global_position.y >= top - 0.25:
		mantle_time = 0.32
		mantle_velocity = Vector3(-normal.x, 0.0, -normal.z).normalized() * 4.2 + Vector3(0.0, 3.8, 0.0)
		ladder_cooldown = 0.5
		velocity = mantle_velocity
		return
	velocity.y = 0.0
	if _key(KEY_W):
		velocity.y = CLIMB_SPEED
	elif _key(KEY_S):
		velocity.y = -CLIMB_SPEED
	var side: Vector3 = transform.basis.x * move_axis.x * 2.2
	velocity.x = side.x
	velocity.z = side.z
	if _key(KEY_SPACE):
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
	if wid == BURST_WEAPON and burst_shots_left > 0:
		return
	if ammunition[wid] <= 0:
		reload_weapon()
		return
	if wid == 5:
		_melee_attack(48, MELEE_REACH[wid])
		return
	if wid == 8:
		_melee_attack(72, MELEE_REACH[wid])
		return
	if wid == GRENADE_LAUNCHER:
		_fire_grenade_launcher()
		return
	if wid == BURST_WEAPON:
		cooldown = FIRE_INTERVALS[wid]
		recoil_amount = 0.35
		burst_shots_left = 2
		burst_timer = 0.075
		_fire_round()
		return
	_fire_round()

func _fire_round() -> void:
	if health <= 0 or reloading_for > 0.0 or ammunition[wid] <= 0:
		burst_shots_left = 0
		return
	if wid == BURST_WEAPON and burst_shots_left > 0 and burst_timer > 0.0 and ammunition[wid] <= 2:
		burst_shots_left = 0
		return
	ammunition[wid] -= 1
	cooldown = FIRE_INTERVALS[wid]
	recoil_amount = 1.0
	viewmodel.call("fire")
	var pellets: int = PELLETS[wid]
	var scored_hit: bool = false
	var headshot_hit: bool = false
	var spread_scale: float = 0.35 if aim_blend > 0.5 else 1.0
	var burst_spread: float = 0.0
	if wid == BURST_WEAPON:
		burst_spread = float(2 - burst_shots_left) * 0.003
	for pellet: int in range(pellets):
		var spread: Vector2 = Vector2.ZERO
		if pellets > 1:
			spread = Vector2(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05)) * spread_scale
		if wid == 7:
			spread = Vector2(randf_range(-0.006, 0.006), randf_range(-0.006, 0.006))
		if wid == 4:
			spread = Vector2(randf_range(-0.018, 0.018), randf_range(-0.018, 0.018))
		var aim: Vector3 = -camera.global_basis.z + camera.global_basis.x * (spread.x + burst_spread) + camera.global_basis.y * spread.y
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

func _melee_attack(damage: int, reach: float) -> void:
	if health <= 0:
		return
	cooldown = FIRE_INTERVALS[wid]
	recoil_amount = 0.45
	viewmodel.call("fire")
	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_basis.z
	var shape_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var swing_shape: SphereShape3D = SphereShape3D.new()
	swing_shape.radius = 0.32 if wid == 5 else 0.48
	shape_query.shape = swing_shape
	shape_query.transform = Transform3D(Basis.IDENTITY, origin + forward * reach * 0.55)
	shape_query.exclude = [get_rid()]
	var overlaps: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(shape_query, 8)
	var nearest: Node3D = null
	var nearest_distance: float = reach + 1.0
	for overlap: Dictionary in overlaps:
		var candidate: Node3D = overlap["collider"] as Node3D
		if candidate == null or not candidate.is_in_group("enemies"):
			continue
		var candidate_distance: float = origin.distance_to(candidate.global_position + Vector3(0.0, 1.0, 0.0))
		if candidate_distance < nearest_distance:
			nearest = candidate
			nearest_distance = candidate_distance
	if nearest != null and nearest.has_method("take_damage"):
		nearest.call("take_damage", damage)
		if hud != null:
			hud.call("set_hit", true)
			hit_marker.visible = true
			hit_time = 0.23
	update_hud()

func _fire_grenade_launcher() -> void:
	if ammunition[wid] <= 0:
		reload_weapon()
		return
	ammunition[wid] -= 1
	cooldown = FIRE_INTERVALS[wid]
	recoil_amount = 0.8
	viewmodel.call("fire")
	var grenade: RigidBody3D = RigidBody3D.new()
	grenade.set_script(GRENADE_SCRIPT)
	grenade.set("blast_radius", 3.8)
	grenade.set("max_damage", 55)
	grenade.set("fuse", 1.3)
	get_tree().current_scene.add_child(grenade)
	grenade.global_position = camera.global_position - camera.global_basis.z * 0.9
	grenade.add_collision_exception_with(self)
	var launch_dir: Vector3 = (-camera.global_basis.z + Vector3.UP * 0.18).normalized()
	var launch_velocity: Vector3 = launch_dir * 22.0
	grenade.call("launch", launch_velocity)
	Net.send_grenade(grenade.global_position, launch_velocity, float(grenade.get("blast_radius")), int(grenade.get("max_damage")), float(grenade.get("fuse")))
	update_hud()

func spawn_tracer(origin: Vector3, endpoint: Vector3) -> void:
	var tracer: MeshInstance3D = MeshInstance3D.new()
	tracer.set_script(TRACER_SCRIPT)
	get_tree().current_scene.add_child(tracer)
	tracer.call("set_line", origin, endpoint)
	Net.send_tracer(origin, endpoint)

func spawn_impact(position_world: Vector3, surface_normal: Vector3) -> void:
	var impact: Node3D = Node3D.new()
	impact.set_script(IMPACT_SCRIPT)
	get_tree().current_scene.add_child(impact)
	impact.global_position = position_world + surface_normal * 0.035
	var normal: Vector3 = surface_normal.normalized()
	if normal.length_squared() < 0.001:
		normal = Vector3.UP
	var up_axis: Vector3 = Vector3.RIGHT if absf(normal.dot(Vector3.UP)) > 0.98 else Vector3.UP
	impact.look_at(position_world + normal, up_axis)
	Net.send_impact(position_world, surface_normal)

func select_weapon(index: int) -> void:
	if index < 0 or index >= GameConfig.weapon_slots.size():
		return
	selected_weapon = index
	wid = GameConfig.weapon_slots[index]
	reloading_for = 0.0
	burst_shots_left = 0
	burst_timer = 0.0
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
	grenade.add_collision_exception_with(self)
	var dir: Vector3 = -camera.global_basis.z
	var throw_velocity: Vector3 = dir * THROW_SPEED + Vector3(0.0, 3.2, 0.0)
	grenade.call("launch", throw_velocity)
	Net.send_grenade(grenade.global_position, throw_velocity, float(grenade.get("blast_radius")), int(grenade.get("max_damage")), float(grenade.get("fuse")))

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

func _key(code: Key) -> bool:
	return controls_enabled and Input.is_key_pressed(code)

## Setzt den Spieler zurück (Respawn / Matchstart im LAN-Modus).
func respawn_at(spawn: Vector3, yaw: float) -> void:
	health = MAX_HEALTH
	regen_timer = 0.0
	regen_accum = 0.0
	for index: int in range(MAGAZINES.size()):
		ammunition[index] = MAGAZINES[index]
	grenades = GRENADE_COUNT
	reloading_for = 0.0
	burst_shots_left = 0
	burst_timer = 0.0
	cooldown = 0.0
	aiming = false
	firing = false
	mantle_time = 0.0
	velocity = Vector3.ZERO
	global_position = spawn
	rotation = Vector3(0.0, yaw, 0.0)
	pitch = 0.0
	camera.rotation.x = 0.0
	if hud != null:
		hud.call("set_status", "")
		hud.call("set_grenades", grenades)
	update_hud()
