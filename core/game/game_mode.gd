class_name GameMode
extends RefCounted

const ItemDbScript = preload("res://core/game/item_db.gd")
const InventoryScript = preload("res://core/game/inventory.gd")
const SaveSystemScript = preload("res://core/game/save_system.gd")

enum ModeType {
	FREE = 0,
	SURVIVAL = 1,
}

var mode_type: int = ModeType.FREE
var world: Node3D = null
var player: Node3D = null
var score_board: Node = null
var is_active: bool = false
var _seed: int = 0
var _wave: int = 0
var _objectives: Array = []
var _pickup_manager: Node = null

signal mode_started(mode_type: int)
signal mode_ended(result: Dictionary)
signal wave_started(wave: int, enemy_count: int)
signal wave_completed(wave: int, score: int)
signal objective_updated(objective: Dictionary)
signal objective_completed(objective: Dictionary)
signal player_died(attempts: int)
signal player_respawned(spawn_point: Vector3)

func _init(p_world: Node3D = null, p_player: Node3D = null, p_seed: int = 0) -> void:
	world = p_world
	player = p_player
	_seed = p_seed if p_seed != 0 else randi()
	_setup_score_board()

func _setup_score_board() -> void:
	var script = load("res://core/game/score_board.gd")
	if script:
		score_board = script.new()
		score_board.name = "ScoreBoard"
		if world:
			world.add_child(score_board)

func setup(p_world: Node3D, p_player: Node3D, p_seed: int = 0) -> void:
	world = p_world
	player = p_player
	_seed = p_seed if p_seed != 0 else randi()
	_setup_score_board()

func start() -> void:
	is_active = true
	mode_started.emit(mode_type)

func stop() -> void:
	is_active = false
	var result = _get_final_result()
	mode_ended.emit(result)

func _get_final_result() -> Dictionary:
	return {
		"mode": mode_type,
		"wave": _wave,
		"score": score_board.get_total_score() if score_board else 0,
		"objectives_completed": _objectives.filter(func(o): return bool(o.get("completed", false))).size(),
		"seed": _seed,
	}

func tick(delta: float) -> void:
	if not is_active:
		return

func on_player_died() -> void:
	var attempts = int(score_board.get("deaths")) + 1 if score_board else 1
	if score_board:
		score_board.set("deaths", attempts)
	player_died.emit(attempts)

func on_player_respawned(spawn_point: Vector3) -> void:
	player_respawned.emit(spawn_point)

func get_mode_type() -> int:
	return mode_type

func get_wave() -> int:
	return _wave

func get_seed() -> int:
	return _seed

func get_objectives() -> Array:
	return _objectives.duplicate()

func _pick_random_spawn_far_from(center: Vector3, min_distance: float = 15.0) -> Vector3:
	if not world or not world.has_method("spawn_point_positions"):
		return center
	var spawns = world.spawn_point_positions()
	var far_spawns = spawns.filter(func(s): return (s as Vector3).distance_to(center) >= min_distance)
	if far_spawns.is_empty():
		far_spawns = spawns
	var rng = RandomNumberGenerator.new()
	rng.seed = _seed + _wave * 1000
	return far_spawns[rng.randi_range(0, far_spawns.size() - 1)]

func _pick_multiple_spawns_far_from(center: Vector3, count: int, min_distance: float = 15.0) -> Array:
	if not world or not world.has_method("spawn_point_positions"):
		return [center]
	var spawns = world.spawn_point_positions()
	var far_spawns = spawns.filter(func(s): return (s as Vector3).distance_to(center) >= min_distance)
	if far_spawns.is_empty():
		far_spawns = spawns
	var rng = RandomNumberGenerator.new()
	rng.seed = _seed + _wave * 1000 + 500
	far_spawns.shuffle()
	var result = []
	for i in range(min(count, far_spawns.size())):
		result.append(far_spawns[i])
	return result