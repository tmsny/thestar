extends Node3D

var elapsed: float = 0.0
const DURATION: float = 0.16
var core: MeshInstance3D
var halo: MeshInstance3D

func _ready() -> void:
	core = MeshInstance3D.new()
	var core_mesh: SphereMesh = SphereMesh.new()
	core_mesh.radius = 0.07
	core_mesh.height = 0.14
	core.mesh = core_mesh
	var core_material: StandardMaterial3D = StandardMaterial3D.new()
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_material.albedo_color = Color(1.0, 0.76, 0.34, 1.0)
	core_material.emission_enabled = true
	core_material.emission = Color(1.0, 0.38, 0.08, 2.2)
	core.material_override = core_material
	add_child(core)
	halo = MeshInstance3D.new()
	var halo_mesh: SphereMesh = SphereMesh.new()
	halo_mesh.radius = 0.17
	halo_mesh.height = 0.34
	halo.mesh = halo_mesh
	var halo_material: StandardMaterial3D = StandardMaterial3D.new()
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_material.albedo_color = Color(1.0, 0.27, 0.06, 0.36)
	halo_material.emission_enabled = true
	halo_material.emission = Color(1.0, 0.13, 0.015, 0.8)
	halo.material_override = halo_material
	add_child(halo)
	var impact_light: OmniLight3D = OmniLight3D.new()
	impact_light.light_color = Color(1.0, 0.35, 0.08)
	impact_light.light_energy = 1.8
	impact_light.omni_range = 2.0
	add_child(impact_light)

func _process(delta: float) -> void:
	elapsed += delta
	var ratio: float = clampf(elapsed / DURATION, 0.0, 1.0)
	core.scale = Vector3.ONE * (1.0 + ratio * 0.45)
	halo.scale = Vector3.ONE * (0.6 + ratio * 1.5)
	var halo_material: StandardMaterial3D = halo.material_override as StandardMaterial3D
	halo_material.albedo_color.a = (1.0 - ratio) * 0.36
	if elapsed >= DURATION:
		queue_free()
