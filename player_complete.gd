extends CharacterBody3D

const SPEED: float = 7.0
const GRAVITY: float = 18.0
const CROUCH_SPEED_MULT: float = 0.45
const CROUCH_SIZE_MULT: float = 0.8
const CROUCH_BLEND_SPEED: float = 9.0
const STAND_CAMERA_Y: float = 1.58
const CROUCH_CAMERA_Y: float = 1.12
const CAPSULE_HEIGHT: float = 1.8
const CAPSULE_RADIUS: float = 0.38
const CLIMB_SPEED: float = 4.5
const LADDER_JUMP: float = 6.0
const MAX_HEALTH: int = 100
const REGEN_DELAY: float = 5.0
const REGEN_RATE: float = 9.0
# Waffenwerte kommen zentral aus WeaponData (eine Quelle der Wahrheit fuer
# Spielverhalten UND Waffen-Menue).
const MAGAZINES: Array[int] = WeaponData.MAGAZINES
const FIRE_INTERVALS: Array[float] = WeaponData.FIRE_INTERVALS
const RELOAD_LENGTHS: Array[float] = WeaponData.RELOAD_LENGTHS
const ADS_FOV: Array[float] = WeaponData.ADS_FOV
const PELLETS: Array[int] = WeaponData.PELLETS
const BODY_DAMAGE: Array[int] = WeaponData.BODY_DAMAGE
const HEAD_MULT: Array[float] = WeaponData.HEAD_MULT
const AUTOMATIC: Array[bool] = WeaponData.AUTOMATIC
const MELEE_REACH: Array[float] = WeaponData.MELEE_REACH
const HUD_SCENE: PackedScene = preload("res://hud_pro.tscn")
const TRACER_SCRIPT: Script = preload("res://weapon_tracer.gd")
const IMPACT_SCRIPT: Script = preload("res://weapon_impact.gd")
const GRENADE_SCRIPT: Script = preload("res://grenade.gd")
const THROW_SPEED: float = 17.0
const GRENADE_COUNT: int = 3
const WEAPON_COUNT: int = WeaponData.COUNT
const BURST_WEAPON: int = WeaponData.BURST_WEAPON
const GRENADE_LAUNCHER: int = WeaponData.GRENADE_LAUNCHER

@onready var camera: Camera3D = $Camera3D
@onready var viewmodel: Node3D = $Camera3D/Viewmodel
@onready var muzzle_light: OmniLight3D = $Camera3D/Viewmodel/MuzzleFlash
@onready var ladder_sensor: Area3D = $LadderSensor
@onready var body_collision: CollisionShape3D = $BodyCollision

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
var crouching: bool = false
var crouch_blend: float = 0.0

func _ready() -> void:
	GameConfig.ensure_loaded()
	if GameConfig.weapon_slots.size() != 4:
		GameConfig.weapon_slots = [0, 1, 2, 3]
	for magazine: int in MAGAZINES:
		ammunition.append(magazine)
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	wid = GameConfig.weapon_slots[selected_weapon]
	if GameConfig.pending_weapon >= 0 and GameConfig.pending_weapon < WEAPON_COUNT:
		wid = GameConfig.pending_weapon
	GameConfig.pending_weapon = -1
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
		var slot_handled: bool = false
		for i: int in range(mini(4, GameConfig.weapon_slots.size())):
			if event.is_action_pressed("slot_%d" % (i + 1)):
				select_weapon(i)
				slot_handled = true
				break
		if not slot_handled:
			if event.is_action_pressed("reload"):
				reload_weapon()
			elif event.is_action_pressed("grenade"):
				throw_grenade()

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	ladder_cooldown = maxf(ladder_cooldown - delta, 0.0)
	_update_ladder()
	_update_crouch(delta)
	var move_axis: Vector2 = Vector2.ZERO
	move_axis.x = float(Input.is_action_pressed("move_right")) - float(Input.is_action_pressed("move_left"))
	move_axis.y = float(Input.is_action_pressed("move_back")) - float(Input.is_action_pressed("move_forward"))
	move_axis = move_axis.normalized()
	if mantle_time > 0.0:
		mantle_time = maxf(mantle_time - delta, 0.0)
		velocity = mantle_velocity
	elif ladder_area != null and ladder_cooldown <= 0.0 and Input.is_action_pressed("jump"):
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
	if firing and AUTOMATIC[wid]:
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

func _update_crouch(delta: float) -> void:
	crouching = Input.is_action_pressed("crouch")
	crouch_blend = move_toward(crouch_blend, 1.0 if crouching else 0.0, delta * CROUCH_BLEND_SPEED)
	var size_mult: float = lerpf(1.0, CROUCH_SIZE_MULT, crouch_blend)
	var capsule: CapsuleShape3D = body_collision.shape as CapsuleShape3D
	if capsule != null:
		capsule.height = CAPSULE_HEIGHT * size_mult
		capsule.radius = CAPSULE_RADIUS * size_mult
	body_collision.position.y = CAPSULE_HEIGHT * size_mult * 0.5
	camera.position.y = lerpf(STAND_CAMERA_Y, CROUCH_CAMERA_Y, crouch_blend)

func _walk(delta: float, move_axis: Vector2) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if Input.is_action_pressed("jump") and is_on_floor():
		velocity.y = 5.0
	var direction: Vector3 = (transform.basis * Vector3(move_axis.x, 0.0, move_axis.y)).normalized()
	var move_speed: float = SPEED * lerpf(1.0, CROUCH_SPEED_MULT, crouch_blend)
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

func _climb(move_axis: Vector2) -> void:
	# Step off the top of the ladder onto the roof / platform above it.
	var normal: Vector3 = ladder_area.global_basis.z
	var top: float = 9999.0
	if ladder_area.has_meta("top_y"):
		top = float(ladder_area.get_meta("top_y"))
	if global_position.y >= top - 0.25:
		mantle_time = 0.32
		mantle_velocity = Vector3(-normal.x, 0.0, -normal.z).normalized() * 4.2 + Vector3(0.0, 3.8, 0.0)
		ladder_cooldown = 0.5
		velocity = mantle_velocity
		return
	# Klettern ist nur aktiv, solange Space gehalten wird (siehe _physics_process).
	# Standard: aufsteigen; mit S absteigen.
	velocity.y = -CLIMB_SPEED if Input.is_action_pressed("move_back") else CLIMB_SPEED
	var side: Vector3 = transform.basis.x * move_axis.x * 2.2
	velocity.x = side.x
	velocity.z = side.z
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
	if wid == 5 or wid == 8:
		_melee_attack(BODY_DAMAGE[wid], MELEE_REACH[wid])
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
				var dealt: int = int(round(damage))
				target.call("take_damage", dealt)
				hud.call("show_damage", dealt)
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
			hud.call("show_damage", damage)
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
	grenade.call("launch", launch_dir * 22.0)
	update_hud()

func spawn_tracer(origin: Vector3, endpoint: Vector3) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var tracer: MeshInstance3D = MeshInstance3D.new()
	tracer.set_script(TRACER_SCRIPT)
	scene.add_child(tracer)
	tracer.call("set_line", origin, endpoint)

func spawn_impact(position_world: Vector3, surface_normal: Vector3) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var impact: Node3D = Node3D.new()
	impact.set_script(IMPACT_SCRIPT)
	scene.add_child(impact)
	impact.global_position = position_world + surface_normal * 0.035
	impact.look_at(position_world + surface_normal, Vector3.UP)

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
	if viewmodel != null:
		viewmodel.call("play_throw")
	_animate_grenade_throw()

## Sichtbare Granate fliegt aus der Hand zum Freigabepunkt, dann startet die Physik.
func _animate_grenade_throw() -> void:
	var release: Vector3 = camera.global_position - camera.global_basis.z * 0.7
	var visual: MeshInstance3D = _make_grenade_visual()
	var start: Vector3 = camera.global_position + camera.global_basis.x * 0.24 - camera.global_basis.y * 0.20 - camera.global_basis.z * 0.35
	visual.global_position = start
	visual.global_rotation = Vector3.ZERO
	var mid: Vector3 = start.lerp(release, 0.5) + camera.global_basis.y * 0.16 - camera.global_basis.z * 0.08
	var throw_tw: Tween = create_tween()
	throw_tw.tween_property(visual, "global_position", mid, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	throw_tw.tween_property(visual, "global_position", release, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	throw_tw.parallel().tween_property(visual, "rotation:y", TAU * 1.5, 0.22)
	throw_tw.tween_callback(visual.queue_free)
	throw_tw.tween_callback(_launch_grenade.bind(release))

func _make_grenade_visual() -> MeshInstance3D:
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.085
	sphere.height = 0.17
	mesh_node.mesh = sphere
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.17, 0.23, 0.19)
	mat.metallic = 0.45
	mat.roughness = 0.5
	mesh_node.material_override = mat
	var scene: Node = get_tree().current_scene
	if scene != null:
		scene.add_child(mesh_node)
	else:
		add_child(mesh_node)
	return mesh_node

func _launch_grenade(release: Vector3) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		scene = get_parent()
	var grenade: RigidBody3D = RigidBody3D.new()
	grenade.set_script(GRENADE_SCRIPT)
	scene.add_child(grenade)
	grenade.global_position = release
	grenade.add_collision_exception_with(self)
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
