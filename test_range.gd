extends Node3D

## Testwelt: stehende Trainings-NPCs in verschiedenen Entfernungen. Der Schaden,
## den man anrichtet, wird unten im HUD angezeigt (z. B. "-72"). Rueckkehr ueber
## das Pause-Menue (ESC -> HAUPTMENU).

const DUMMY_SCRIPT: Script = preload("res://training_dummy.gd")
const RANGES: Array[float] = [10.0, 18.0, 26.0, 34.0]
const PLAYER_Z: float = 16.0

func _ready() -> void:
	GameConfig.ensure_loaded()
	_build_sky()
	_build_floor()
	_build_dummies()

func _build_sky() -> void:
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	material.sky_top_color = Color(0.12, 0.2, 0.32)
	material.sky_horizon_color = Color(0.4, 0.45, 0.5)
	material.ground_bottom_color = Color(0.06, 0.08, 0.1)
	material.ground_horizon_color = Color(0.3, 0.34, 0.38)
	sky.sky_material = material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	environment_node.environment = env
	add_child(environment_node)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-50.0, 40.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)

func _build_floor() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "Floor"
	add_child(floor_body)

	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 90.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = box
	collision.position = Vector3(0.0, -0.5, 6.0)
	floor_body.add_child(collision)

	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = Vector3(60.0, 1.0, 90.0)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = box_mesh
	mesh.position = Vector3(0.0, -0.5, 6.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.2, 0.22)
	material.roughness = 0.9
	mesh.material_override = material
	floor_body.add_child(mesh)

func _build_dummies() -> void:
	for i: int in range(RANGES.size()):
		var distance: float = RANGES[i]
		var dummy: StaticBody3D = StaticBody3D.new()
		dummy.name = "Dummy%d" % (i + 1)
		dummy.set_script(DUMMY_SCRIPT)
		dummy.position = Vector3(0.0, 0.0, PLAYER_Z - distance)
		add_child(dummy)

		var marker: Label3D = Label3D.new()
		marker.text = "%d m" % int(distance)
		marker.position = Vector3(0.0, 2.15, 0.0)
		marker.pixel_size = 0.004
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.modulate = Color(0.6, 0.95, 0.9)
		dummy.add_child(marker)