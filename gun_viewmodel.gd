extends Node3D

var weapon_index: int = 0
var recoil_amount: float = 0.0
var bob_phase: float = 0.0
var parts: Node3D
var flash_light: OmniLight3D
var material_dark: StandardMaterial3D
var material_metal: StandardMaterial3D
var material_grip: StandardMaterial3D
var material_accent: StandardMaterial3D
var flash_sprite: MeshInstance3D
var flash_timer: float = 0.0
var flash_scale_tween: Tween

func _ready() -> void:
	position = Vector3(0.30, -0.28, -0.78)
	scale = Vector3(0.74, 0.74, 0.74)
	parts = Node3D.new()
	parts.name = "Parts"
	add_child(parts)
	flash_light = OmniLight3D.new()
	flash_light.position = Vector3(0.0, 0.015, -0.9)
	flash_light.light_color = Color(1.0, 0.53, 0.12)
	flash_light.light_energy = 0.0
	flash_light.omni_range = 3.0
	add_child(flash_light)
	flash_sprite = MeshInstance3D.new()
	flash_sprite.name = "MuzzleFlame"
	var flash_mesh: SphereMesh = SphereMesh.new()
	flash_mesh.radius = 0.18
	flash_mesh.height = 0.42
	flash_sprite.mesh = flash_mesh
	flash_sprite.position = Vector3(0.0, 0.025, -1.12)
	var flash_material: StandardMaterial3D = StandardMaterial3D.new()
	flash_material.albedo_color = Color(1.0, 0.55, 0.12, 1.0)
	flash_material.emission_enabled = true
	flash_material.emission = Color(1.0, 0.24, 0.025, 2.5)
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_sprite.material_override = flash_material
	flash_sprite.visible = false
	add_child(flash_sprite)
	material_dark = _material(Color(0.055, 0.07, 0.085), 0.78, 0.3)
	material_metal = _material(Color(0.24, 0.28, 0.31), 0.85, 0.22)
	material_grip = _material(Color(0.075, 0.09, 0.095), 0.0, 0.72)
	material_accent = _material(Color(0.12, 0.34, 0.32), 0.25, 0.35)
	build_weapon(0)

func build_weapon(index: int) -> void:
	weapon_index = clampi(index, 0, 2)
	for child: Node in parts.get_children():
		child.queue_free()
	var dark: StandardMaterial3D = material_dark
	var metal: StandardMaterial3D = material_metal
	var grip: StandardMaterial3D = material_grip
	var accent: StandardMaterial3D = material_accent
	if weapon_index == 0:
		_box("Slide", Vector3(0.22, 0.13, 0.39), Vector3(0.0, 0.025, -0.12), metal)
		_box("Frame", Vector3(0.21, 0.10, 0.34), Vector3(0.0, -0.055, -0.11), dark)
		_cylinder("Barrel", 0.035, 0.36, Vector3(0.0, 0.025, -0.42), metal)
		_cylinder("MuzzleCrown", 0.047, 0.035, Vector3(0.0, 0.025, -0.61), dark)
		_box("TriggerGuard", Vector3(0.12, 0.09, 0.14), Vector3(0.0, -0.12, 0.015), metal)
		_box("Trigger", Vector3(0.025, 0.065, 0.035), Vector3(0.0, -0.105, -0.025), accent)
		_box("Grip", Vector3(0.15, 0.28, 0.17), Vector3(0.0, -0.22, 0.025), grip, Vector3(-0.2, 0.0, 0.0))
		_box("GripPlate", Vector3(0.158, 0.18, 0.025), Vector3(0.0, -0.23, 0.11), accent)
		_box("GripInset", Vector3(0.11, 0.12, 0.018), Vector3(0.0, -0.23, 0.126), dark)
		_box("SightFront", Vector3(0.035, 0.045, 0.035), Vector3(0.0, 0.11, -0.3), dark)
		_box("SightRear", Vector3(0.07, 0.045, 0.04), Vector3(0.0, 0.11, 0.04), dark)
		_box("SightDot", Vector3(0.018, 0.018, 0.022), Vector3(0.0, 0.136, -0.3), accent)
	elif weapon_index == 1:
		_box("Receiver", Vector3(0.25, 0.18, 0.42), Vector3(0.0, 0.0, 0.03), dark)
		_box("UpperReceiver", Vector3(0.21, 0.055, 0.37), Vector3(0.0, 0.105, 0.0), metal)
		_cylinder("LongBarrel", 0.032, 0.73, Vector3(0.0, 0.025, -0.49), metal)
		_cylinder("MuzzleBrake", 0.052, 0.11, Vector3(0.0, 0.025, -0.91), dark)
		_box("Handguard", Vector3(0.18, 0.15, 0.38), Vector3(0.0, -0.005, -0.37), grip)
		_box("Rail", Vector3(0.10, 0.028, 0.55), Vector3(0.0, 0.105, -0.35), dark)
		_box("RailSlotA", Vector3(0.025, 0.012, 0.40), Vector3(0.0, 0.123, -0.37), metal)
		_box("TriggerGuard", Vector3(0.12, 0.09, 0.14), Vector3(0.0, -0.12, 0.10), metal)
		_box("Trigger", Vector3(0.025, 0.06, 0.03), Vector3(0.0, -0.11, 0.05), accent)
		_box("Magazine", Vector3(0.15, 0.29, 0.18), Vector3(0.0, -0.23, 0.015), dark, Vector3(-0.15, 0.0, 0.0))
		_box("MagazineInset", Vector3(0.08, 0.17, 0.02), Vector3(0.0, -0.22, -0.084), accent)
		_box("PistolGrip", Vector3(0.14, 0.25, 0.16), Vector3(0.0, -0.2, 0.18), grip, Vector3(-0.22, 0.0, 0.0))
		_box("Stock", Vector3(0.18, 0.15, 0.43), Vector3(0.0, 0.015, 0.43), grip)
		_box("StockPad", Vector3(0.19, 0.16, 0.045), Vector3(0.0, 0.015, 0.65), dark)
		_box("Optic", Vector3(0.11, 0.11, 0.17), Vector3(0.0, 0.2, 0.02), accent)
		_box("SightFront", Vector3(0.035, 0.07, 0.035), Vector3(0.0, 0.13, -0.79), metal)
	else:
		_box("Receiver", Vector3(0.24, 0.18, 0.42), Vector3(0.0, 0.0, 0.18), dark)
		_cylinder("ShotgunBarrel", 0.055, 1.05, Vector3(0.0, 0.02, -0.53), metal)
		_cylinder("MuzzleRing", 0.072, 0.08, Vector3(0.0, 0.02, -1.08), accent)
		_cylinder("MagazineTube", 0.038, 0.83, Vector3(0.0, -0.1, -0.51), dark)
		_box("Pump", Vector3(0.2, 0.17, 0.34), Vector3(0.0, -0.015, -0.43), grip)
		_box("PumpGrooveA", Vector3(0.012, 0.14, 0.26), Vector3(-0.103, -0.015, -0.43), metal)
		_box("PumpGrooveB", Vector3(0.012, 0.14, 0.26), Vector3(0.103, -0.015, -0.43), metal)
		_box("ShellCarrier", Vector3(0.08, 0.13, 0.14), Vector3(0.13, -0.09, 0.17), accent)
		_box("Stock", Vector3(0.19, 0.17, 0.42), Vector3(0.0, 0.015, 0.58), grip)
		_box("StockPad", Vector3(0.20, 0.17, 0.05), Vector3(0.0, 0.015, 0.80), dark)
		_box("PistolGrip", Vector3(0.15, 0.25, 0.17), Vector3(0.0, -0.2, 0.31), grip, Vector3(-0.2, 0.0, 0.0))
		_box("TriggerGuard", Vector3(0.12, 0.09, 0.14), Vector3(0.0, -0.12, 0.20), metal)
		_box("Sight", Vector3(0.05, 0.06, 0.06), Vector3(0.0, 0.12, -0.83), accent)

func set_motion(phase: float, recoil: float) -> void:
	bob_phase = phase
	recoil_amount = maxf(recoil_amount, recoil)

func fire() -> void:
	recoil_amount = 1.0
	flash_light.light_energy = 7.0
	flash_sprite.visible = true
	flash_sprite.scale = Vector3(1.0, 1.0, 1.0)
	flash_timer = 0.14
	if flash_scale_tween != null and flash_scale_tween.is_running():
		flash_scale_tween.kill()
	flash_scale_tween = create_tween()
	flash_scale_tween.tween_property(flash_sprite, "scale", Vector3(1.7, 1.7, 1.7), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			flash_sprite.visible = false
			flash_light.light_energy = 0.0
	recoil_amount = move_toward(recoil_amount, 0.0, delta * 5.0)
	bob_phase += delta * 8.0
	position.y = -0.29 + sin(bob_phase) * 0.006 - recoil_amount * 0.055
	rotation.x = recoil_amount * 0.035

func _box(part_name: String, dimensions: Vector3, local_pos: Vector3, material: Material, local_rot: Vector3 = Vector3.ZERO) -> void:
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.name = part_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	mesh_node.mesh = mesh
	mesh_node.material_override = material
	mesh_node.position = local_pos
	mesh_node.rotation = local_rot
	parts.add_child(mesh_node)

func _cylinder(part_name: String, radius: float, length: float, local_pos: Vector3, material: Material) -> void:
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
	parts.add_child(mesh_node)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material
