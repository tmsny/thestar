class_name Grenade
extends RigidBody3D

## Throwable fragmentation grenade: arcs through the air with a blinking light,
## then explodes after a short fuse, damaging every enemy within a radius.

const FUSE: float = 2.4
const RADIUS: float = 6.5
const MAX_DAMAGE: int = 90

@export var blast_radius: float = RADIUS
@export var max_damage: int = MAX_DAMAGE
var fuse: float = FUSE
var exploded: bool = false
var visual_only: bool = false  # Kopie der Granate des Gegners: nur Anzeige, kein Schaden

func _ready() -> void:
	add_to_group("grenades")
	collision_layer = 1
	collision_mask = 3
	gravity_scale = 1.15
	continuous_cd = true
	_build()

func _build() -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	sphere.radial_segments = 12
	sphere.rings = 6
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Shell"
	mi.mesh = sphere
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.3, 0.2)
	mat.metallic = 0.4
	mat.roughness = 0.5
	mi.material_override = mat
	add_child(mi)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.14
	cs.shape = shape
	add_child(cs)
	var blink: OmniLight3D = OmniLight3D.new()
	blink.name = "Blink"
	blink.light_color = Color(1.0, 0.25, 0.15)
	blink.light_energy = 1.0
	blink.omni_range = 2.4
	add_child(blink)

func launch(initial_velocity: Vector3) -> void:
	linear_velocity = initial_velocity
	angular_velocity = Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))

func _physics_process(delta: float) -> void:
	if exploded:
		return
	fuse -= delta
	var blink: OmniLight3D = get_node_or_null("Blink") as OmniLight3D
	if blink != null:
		var rate: float = 6.0 + (1.0 - maxf(fuse, 0.0) / FUSE) * 26.0
		blink.light_energy = 0.5 + 1.7 * absf(sin(Time.get_ticks_msec() * 0.001 * rate))
	if fuse <= 0.0:
		explode()

func explode() -> void:
	if exploded:
		return
	exploded = true
	var origin: Vector3 = global_position
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if visual_only:
			break
		var e: Node3D = node as Node3D
		if e == null or not is_instance_valid(e):
			continue
		var center: Vector3 = e.global_position + Vector3(0.0, 1.0, 0.0)
		var d: float = origin.distance_to(center)
		if d <= blast_radius and e.has_method("take_damage"):
			var falloff: float = 1.0 - d / blast_radius
			var dmg: int = maxi(1, int(round(float(max_damage) * falloff)))
			e.call("take_damage", dmg)
	_blast(origin)
	queue_free()

func _blast(origin: Vector3) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.6, 0.2, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.15)
	var blast: MeshInstance3D = MeshInstance3D.new()
	blast.mesh = sphere
	blast.material_override = mat
	blast.scale = Vector3(0.3, 0.3, 0.3)
	scene.add_child(blast)
	blast.global_position = origin
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.2)
	light.omni_range = 14.0
	light.light_energy = 7.0
	scene.add_child(light)
	light.global_position = origin
	var target_scale: float = RADIUS * 0.75
	var tw: Tween = blast.create_tween()
	tw.set_parallel(true)
	tw.tween_property(blast, "scale", Vector3(target_scale, target_scale, target_scale), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color", Color(1.0, 0.5, 0.12, 0.0), 0.32)
	tw.chain().tween_callback(blast.queue_free)
	var light_tw: Tween = light.create_tween()
	light_tw.tween_property(light, "light_energy", 0.0, 0.4)
	light_tw.tween_callback(light.queue_free)
