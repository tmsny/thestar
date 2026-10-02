extends MeshInstance3D

var lifetime: float = 0.18
var age: float = 0.0

func _ready() -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.88, 0.48, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.42, 0.08, 2.0)
	material_override = mat

func set_line(start: Vector3, finish: Vector3) -> void:
	var distance: float = start.distance_to(finish)
	if distance < 0.05:
		queue_free()
		return
	var beam: BoxMesh = BoxMesh.new()
	beam.size = Vector3(0.025, 0.025, distance)
	mesh = beam
	global_position = (start + finish) * 0.5
	look_at(finish, Vector3.UP)

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
	else:
		var mat: StandardMaterial3D = material_override as StandardMaterial3D
		mat.albedo_color.a = 1.0 - age / lifetime
