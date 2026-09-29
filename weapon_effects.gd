extends Node3D

var tracer_mesh: MeshInstance3D
var tracer_timer: Timer

func _ready() -> void:
	tracer_mesh = MeshInstance3D.new()
	var immediate: ImmediateMesh = ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	immediate.surface_set_color(Color(1.0, 0.72, 0.22, 1.0))
	immediate.surface_add_vertex(Vector3.ZERO)
	immediate.surface_add_vertex(Vector3(0.0, 0.0, -1.0))
	immediate.surface_end()
	tracer_mesh.mesh = immediate
	var tracer_material: StandardMaterial3D = StandardMaterial3D.new()
	tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer_material.albedo_color = Color(1.0, 0.67, 0.2)
	tracer_material.no_depth_test = true
	tracer_mesh.material_override = tracer_material
	add_child(tracer_mesh)
	tracer_timer = Timer.new()
	tracer_timer.one_shot = true
	tracer_timer.wait_time = 0.075
	tracer_timer.timeout.connect(queue_free)
	add_child(tracer_timer)

func set_segment(start: Vector3, finish: Vector3) -> void:
	global_position = start
	var vector: Vector3 = finish - start
	if vector.length() < 0.1:
		queue_free()
		return
	look_at(finish, Vector3.UP)
	tracer_mesh.scale.z = -vector.length()
	tracer_timer.start()
