class_name EnemySpawner
extends Node3D

## Keeps a fixed number of enemies alive, respawning them at safe points
## around the arena so the fight never runs dry.

const ENEMY_SCENE: PackedScene = preload("res://enemy.tscn")
const RESPAWN_DELAY: float = 1.8
const MIN_PLAYER_DISTANCE: float = 10.0

const SPAWN_POINTS: Array[Vector3] = [
	Vector3(-25.0, 0.2, 0.0),
	Vector3(25.0, 0.2, 0.0),
	Vector3(0.0, 0.2, -28.0),
	Vector3(0.0, 0.2, 28.0),
	Vector3(-19.0, 0.2, 3.0),
	Vector3(20.0, 0.2, 2.0),
	Vector3(-13.0, 0.2, 21.0),
	Vector3(13.0, 0.2, -21.0),
	Vector3(-23.0, 0.2, -13.0),
	Vector3(23.0, 0.2, 15.0),
	Vector3(8.0, 0.2, 3.0),
	Vector3(-8.0, 0.2, -4.0),
	Vector3(-20.0, 0.2, -25.0),
	Vector3(20.0, 0.2, -25.0),
]

var respawn_timer: float = 0.0
var max_alive: int = 4
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	GameConfig.ensure_loaded()
	max_alive = GameConfig.difficulty_enemy_count()
	rng.randomize()
	for index: int in range(max_alive):
		_spawn(index)

func _process(delta: float) -> void:
	var alive: int = get_tree().get_nodes_in_group("enemies").size()
	if alive < max_alive:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_spawn(rng.randi() % SPAWN_POINTS.size())
			respawn_timer = RESPAWN_DELAY
	else:
		respawn_timer = RESPAWN_DELAY

func _spawn(point_index: int) -> void:
	var enemy: CharacterBody3D = ENEMY_SCENE.instantiate()
	if rng.randf() < 0.35:
		enemy.set("kind", 1)
	add_child(enemy)
	enemy.global_position = _safe_point(point_index)

func _safe_point(point_index: int) -> Vector3:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	var best: Vector3 = SPAWN_POINTS[clampi(point_index, 0, SPAWN_POINTS.size() - 1)]
	if not is_instance_valid(player):
		return best
	var best_distance: float = -1.0
	for point: Vector3 in SPAWN_POINTS:
		var distance: float = point.distance_to(player.global_position)
		if distance > best_distance and distance >= MIN_PLAYER_DISTANCE:
			best_distance = distance
			best = point
	return best