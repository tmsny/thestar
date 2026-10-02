class_name Enemy
extends CharacterBody3D

## Humanoid enemy with 100 HP, a floating health bar and simple "smart" AI:
## approaches the player, keeps a fighting distance, strafes, jumps over
## obstacles and shoots back when it has line of sight.

enum Kind { TROOPER, RUSHER }

const MAX_HEALTH: int = 100
const GRAVITY: float = 18.0
const JUMP_VELOCITY: float = 6.2

const HEAD_HEIGHT: float = 1.5          # local y above the feet that counts as a headshot
const AIM_HEIGHT: float = 1.25          # height on the player's body to aim at
const SHOT_SPREAD: float = 0.09

# Per-type stats; chosen from `kind` in _ready().
var kind: int = Kind.TROOPER
var max_health: int = MAX_HEALTH
var move_speed: float = 4.4
var engage_range: float = 36.0
var keep_min: float = 6.0
var keep_max: float = 13.0
var shot_damage: int = 5
var shoot_interval: float = 2.2
var jump_min: float = 1.8
var jump_max: float = 4.0

const TRACER_SCRIPT: Script = preload("res://scripts/weapons/effects/weapon_tracer.gd")
const IMPACT_SCRIPT: Script = preload("res://scripts/weapons/effects/weapon_impact.gd")

var health: int = MAX_HEALTH
var player: Node3D = null

var shoot_timer: float = 0.0
var strafe_dir: float = 1.0
var strafe_timer: float = 0.0
var jump_timer: float = 0.0
var muzzle_timer: float = 0.0
var flash: float = 0.0

var muzzle: Node3D
var muzzle_light: OmniLight3D
var health_fill: MeshInstance3D
var body_materials: Array[StandardMaterial3D] = []
@onready var visual: Node3D = get_node_or_null("Visual") as Node3D
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	GameConfig.ensure_loaded()
	add_to_group("enemies")
	_apply_kind()
	rng.randomize()
	shoot_timer = rng.randf_range(0.5, 1.4)
	strafe_timer = rng.randf_range(0.6, 1.8)
	jump_timer = rng.randf_range(1.5, 4.0)
	if visual == null:
		visual = Node3D.new()
		visual.name = "Visual"
		add_child(visual)
		var runtime_muzzle: Node3D = Node3D.new()
		runtime_muzzle.name = "Muzzle"
		runtime_muzzle.position = Vector3(0.0, 1.25, -0.72)
		visual.add_child(runtime_muzzle)
	_setup_visual()
	_build_health_bar()
	_update_bar()
	player = get_tree().get_first_node_in_group("player") as Node3D

func _apply_kind() -> void:
	if kind == Kind.RUSHER:
		max_health = 60
		move_speed = 7.4
		engage_range = 28.0
		keep_min = 2.0
		keep_max = 6.5
		shot_damage = 4
		shoot_interval = 1.05
		jump_min = 0.8
		jump_max = 2.2
	else:
		max_health = MAX_HEALTH
		move_speed = 4.4
		engage_range = 36.0
		keep_min = 6.0
		keep_max = 13.0
		shot_damage = 5
		shoot_interval = 2.2
		jump_min = 1.8
		jump_max = 4.0
	health = max_health

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D

	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta

	var desired: Vector3 = Vector3.ZERO
	if health > 0 and is_instance_valid(player):
		desired = _ai_direction()

	velocity.x = desired.x * move_speed
	velocity.z = desired.z * move_speed

	# Hop over low obstacles / cover directly ahead.
	if desired.length() > 0.05 and is_on_floor():
		var probe_from: Vector3 = global_position + Vector3(0.0, 0.8, 0.0)
		var probe_to: Vector3 = probe_from + desired.normalized() * 1.5
		var probe: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(probe_from, probe_to)
		probe.exclude = [get_rid()]
		probe.collision_mask = 1
		if not get_world_3d().direct_space_state.intersect_ray(probe).is_empty():
			velocity.y = JUMP_VELOCITY

	move_and_slide()
	_face_player(delta)

	# Timers.
	strafe_timer -= delta
	if strafe_timer <= 0.0:
		strafe_dir = 1.0 if rng.randf() < 0.5 else -1.0
		strafe_timer = rng.randf_range(0.8, 2.2)

	jump_timer -= delta
	if jump_timer <= 0.0:
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		jump_timer = rng.randf_range(jump_min, jump_max)

	shoot_timer -= delta
	if shoot_timer <= 0.0 and health > 0 and is_instance_valid(player):
		_try_shoot()

	if muzzle_timer > 0.0:
		muzzle_timer -= delta
		if muzzle_timer <= 0.0:
			muzzle_light.light_energy = 0.0

	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 6.0)
		_apply_flash()

# ---------------------------------------------------------------- combat ----

func is_headshot(point: Vector3) -> bool:
	return point.y - global_position.y >= HEAD_HEIGHT

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(0, health - amount)
	flash = 1.0
	_apply_flash()
	_update_bar()
	if health <= 0:
		_die()

func _die() -> void:
	if is_instance_valid(player) and player.has_method("add_kill"):
		player.call("add_kill")
	if is_inside_tree() and get_tree().current_scene != null:
		var puff: Node3D = Node3D.new()
		puff.set_script(IMPACT_SCRIPT)
		get_tree().current_scene.add_child(puff)
		puff.global_position = global_position + Vector3(0.0, 1.2, 0.0)
	queue_free()

func _try_shoot() -> void:
	if not _has_line_of_sight():
		shoot_timer = 0.3
		return
	shoot_timer = shoot_interval * rng.randf_range(0.8, 1.3)
	var origin: Vector3 = muzzle.global_position
	var aim_point: Vector3 = player.global_position + Vector3(0.0, AIM_HEIGHT, 0.0)
	if player is CharacterBody3D:
		aim_point += (player as CharacterBody3D).velocity * 0.12
	var dir: Vector3 = (aim_point - origin).normalized()
	dir += Vector3(rng.randf_range(-SHOT_SPREAD, SHOT_SPREAD), rng.randf_range(-SHOT_SPREAD, SHOT_SPREAD), rng.randf_range(-SHOT_SPREAD, SHOT_SPREAD))
	dir = dir.normalized()
	var end: Vector3 = origin + dir * engage_range
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [get_rid()]
	query.collision_mask = 1
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var hit_pos: Vector3 = end
	if not hit.is_empty():
		hit_pos = hit["position"]
		var collider: Object = hit["collider"]
		if collider is Node and collider.is_in_group("player"):
			var damage: int = maxi(1, int(round(shot_damage * GameConfig.difficulty_damage_mult())))
			collider.call("apply_damage", damage)
	_spawn_tracer(origin, hit_pos)
	muzzle_light.light_energy = 5.0
	muzzle_timer = 0.06

func _has_line_of_sight() -> bool:
	if not is_instance_valid(player):
		return false
	var origin: Vector3 = muzzle.global_position
	var target: Vector3 = player.global_position + Vector3(0.0, AIM_HEIGHT, 0.0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [get_rid()]
	query.collision_mask = 1
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider: Object = hit["collider"]
	return collider is Node and collider.is_in_group("player")

func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	if from.distance_to(to) < 0.1:
		return
	var tracer: MeshInstance3D = MeshInstance3D.new()
	tracer.set_script(TRACER_SCRIPT)
	get_tree().current_scene.add_child(tracer)
	tracer.call("set_line", from, to)

# -------------------------------------------------------------------- ai ----

func _ai_direction() -> Vector3:
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	var dir: Vector3 = Vector3.ZERO
	if dist > 0.01:
		var forward: Vector3 = to_player.normalized()
		if dist > keep_max:
			dir = forward
		elif dist < keep_min:
			dir = -forward
		else:
			var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
			dir = right * strafe_dir
			var mid: float = (keep_min + keep_max) * 0.5
			dir += forward * (0.35 if dist > mid else -0.35)
	dir += _separation()
	if dir.length() > 1.0:
		dir = dir.normalized()
	return dir

func _separation() -> Vector3:
	var push: Vector3 = Vector3.ZERO
	for other: Node in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var offset: Vector3 = global_position - (other as Node3D).global_position
		offset.y = 0.0
		var length: float = offset.length()
		if length > 0.01 and length < 1.7:
			push += offset / length * (1.7 - length)
	return push

func _face_player(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() < 0.05:
		return
	var target: float = atan2(-to_player.x, -to_player.z)
	rotation.y = lerp_angle(rotation.y, target, clampf(delta * 8.0, 0.0, 1.0))

# ------------------------------------------------------------ health bar ----

func _update_bar() -> void:
	if health_fill == null:
		return
	var ratio: float = clampf(float(health) / float(max_health), 0.0, 1.0)
	health_fill.scale.x = maxf(ratio, 0.001)
	health_fill.position.x = -0.45 + 0.45 * ratio
	var material: StandardMaterial3D = health_fill.material_override as StandardMaterial3D
	var color: Color = Color(0.92, 0.16, 0.12).lerp(Color(0.28, 0.9, 0.36), ratio)
	material.albedo_color = color
	material.emission = color

func _apply_flash() -> void:
	for material: StandardMaterial3D in body_materials:
		material.emission_enabled = flash > 0.01
		material.emission = Color(1.0, 0.2, 0.15)
		material.emission_energy_multiplier = flash * 3.5

# ----------------------------------------------------------- visual setup ---

func _setup_visual() -> void:
	muzzle = visual.get_node("Muzzle") as Node3D
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.55, 0.15)
	muzzle_light.light_energy = 0.0
	muzzle_light.omni_range = 4.0
	muzzle.add_child(muzzle_light)
	body_materials.clear()
	for node: Node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		var material: StandardMaterial3D = mesh_node.get_active_material(0) as StandardMaterial3D
		if material != null and not body_materials.has(material):
			body_materials.append(material)
	if kind == Kind.RUSHER:
		var rusher_plate: MeshInstance3D = visual.get_node("ChestPlate") as MeshInstance3D
		var visor: MeshInstance3D = visual.get_node("Visor") as MeshInstance3D
		var plate_material: StandardMaterial3D = StandardMaterial3D.new()
		plate_material.albedo_color = Color(0.95, 0.45, 0.1)
		plate_material.metallic = 0.3
		rusher_plate.material_override = plate_material
		var visor_material: StandardMaterial3D = StandardMaterial3D.new()
		visor_material.albedo_color = Color(1.0, 0.85, 0.2)
		visor_material.emission_enabled = true
		visor_material.emission = Color(1.0, 0.55, 0.05)
		visor.material_override = visor_material
		body_materials.append(plate_material)
		body_materials.append(visor_material)
	var armor_color: Color = Color(0.17, 0.2, 0.24)
	var plate_color: Color = Color(0.66, 0.16, 0.12)
	var accent_color: Color = Color(0.96, 0.4, 0.13)
	if kind == Kind.RUSHER:
		armor_color = Color(0.3, 0.14, 0.1)
		plate_color = Color(0.95, 0.45, 0.1)
		accent_color = Color(1.0, 0.85, 0.2)
	var armor: StandardMaterial3D = _mat(armor_color, 0.5, 0.5)
	var plate: StandardMaterial3D = _mat(plate_color, 0.3, 0.45)
	var accent: StandardMaterial3D = _mat(accent_color, 0.0, 0.4)
	var skin: StandardMaterial3D = _mat(Color(0.26, 0.29, 0.32), 0.4, 0.6)
	var gun: StandardMaterial3D = _mat(Color(0.05, 0.06, 0.07), 0.8, 0.3)
	for material: StandardMaterial3D in [armor, plate, accent, skin, gun]:
		body_materials.append(material)

	# Legs and boots.
	_box("LegL", Vector3(0.20, 0.80, 0.22), Vector3(-0.15, 0.40, 0.0), armor)
	_box("LegR", Vector3(0.20, 0.80, 0.22), Vector3(0.15, 0.40, 0.0), armor)
	_box("BootL", Vector3(0.24, 0.14, 0.34), Vector3(-0.15, 0.07, -0.05), gun)
	_box("BootR", Vector3(0.24, 0.14, 0.34), Vector3(0.15, 0.07, -0.05), gun)

	# Torso and gear.
	_box("Torso", Vector3(0.58, 0.62, 0.32), Vector3(0.0, 1.14, 0.0), armor)
	_box("ChestPlate", Vector3(0.50, 0.34, 0.10), Vector3(0.0, 1.22, -0.19), plate)
	_box("Belt", Vector3(0.60, 0.10, 0.34), Vector3(0.0, 0.84, 0.0), gun)

	# Arms and shoulders.
	_box("ArmL", Vector3(0.16, 0.62, 0.18), Vector3(-0.37, 1.16, 0.0), armor)
	_box("ArmR", Vector3(0.16, 0.62, 0.18), Vector3(0.37, 1.16, 0.0), armor)
	_box("ShoulderL", Vector3(0.22, 0.20, 0.24), Vector3(-0.34, 1.42, 0.0), plate)
	_box("ShoulderR", Vector3(0.22, 0.20, 0.24), Vector3(0.34, 1.42, 0.0), plate)
	_box("HandR", Vector3(0.15, 0.15, 0.17), Vector3(0.30, 1.02, -0.28), skin)

	# Neck and head.
	_cyl("Neck", 0.09, 0.12, Vector3(0.0, 1.50, 0.0), skin)
	var head_mesh: SphereMesh = SphereMesh.new()
	head_mesh.radius = 0.20
	head_mesh.height = 0.40
	head_mesh.radial_segments = 16
	head_mesh.rings = 8
	var head: MeshInstance3D = MeshInstance3D.new()
	head.name = "Head"
	head.mesh = head_mesh
	head.position = Vector3(0.0, 1.64, 0.0)
	head.material_override = skin
	add_child(head)
	_box("Visor", Vector3(0.30, 0.08, 0.06), Vector3(0.0, 1.66, -0.19), accent)

	# Weapon in the right hand.
	_box("GunBody", Vector3(0.12, 0.16, 0.46), Vector3(0.30, 1.02, -0.32), gun)
	_cyl("GunBarrel", 0.03, 0.36, Vector3(0.30, 1.05, -0.62), gun)
	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.30, 1.05, -0.82)
	add_child(muzzle)
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.55, 0.15)
	muzzle_light.light_energy = 0.0
	muzzle_light.omni_range = 4.0
	muzzle.add_child(muzzle_light)

func _build_health_bar() -> void:
	var bar: Node3D = Node3D.new()
	bar.name = "HealthBar"
	bar.position = Vector3(0.0, 2.08, 0.0)
	add_child(bar)
	var background_quad: QuadMesh = QuadMesh.new()
	background_quad.size = Vector2(0.96, 0.14)
	var background: MeshInstance3D = MeshInstance3D.new()
	background.mesh = background_quad
	background.material_override = _ui_material(Color(0.02, 0.03, 0.04, 0.8), false)
	bar.add_child(background)
	var fill_quad: QuadMesh = QuadMesh.new()
	fill_quad.size = Vector2(0.9, 0.09)
	health_fill = MeshInstance3D.new()
	health_fill.mesh = fill_quad
	health_fill.position = Vector3(0.0, 0.0, 0.03)
	health_fill.material_override = _ui_material(Color(0.28, 0.9, 0.36), true)
	bar.add_child(health_fill)

func _box(part_name: String, dimensions: Vector3, local_pos: Vector3, material: Material) -> void:
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.name = part_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	mesh_node.mesh = mesh
	mesh_node.material_override = material
	mesh_node.position = local_pos
	add_child(mesh_node)

func _cyl(part_name: String, radius: float, length: float, local_pos: Vector3, material: Material) -> void:
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.name = part_name
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	mesh_node.mesh = mesh
	mesh_node.material_override = material
	mesh_node.position = local_pos
	mesh_node.rotation.x = PI * 0.5
	add_child(mesh_node)

func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material

func _ui_material(color: Color, emissive: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emissive:
		material.emission_enabled = true
		material.emission = color
	return material
