extends MainLoop

var _npcs: Array = []
var _frame_times: Array = []
var _test_duration: float = 5.0
var _elapsed: float = 0.0
var _warmup_frames: int = 30
var _frame_count: int = 0
var _player: Node3D = null
var _scene: Node = null

func _initialize() -> void:
	print("PERF: Starting NPC performance test")
	_setup_scene()

func _process(delta: float) -> bool:
	if _frame_count < _warmup_frames:
		_frame_count += 1
		return false
	
	_elapsed += delta
	_frame_times.append(delta * 1000.0)
	
	if _elapsed >= _test_duration:
		_print_results()
		return true
	
	return false

func _finalize() -> void:
	pass

func _print_results() -> void:
	var total_frames = _frame_times.size()
	if total_frames == 0:
		print("PERF: No frames recorded")
		return
	
	_frame_times.sort()
	var sum_ms: float = 0.0
	for t in _frame_times:
		sum_ms += t
	var avg_ms = sum_ms / total_frames
	var min_ms = _frame_times[0]
	var max_ms = _frame_times[total_frames - 1]
	var p95_idx = int(total_frames * 0.95)
	var p99_idx = int(total_frames * 0.99)
	var p95_ms = _frame_times[min(p95_idx, total_frames - 1)]
	var p99_ms = _frame_times[min(p99_idx, total_frames - 1)]
	var ms_per_npc = avg_ms / 12.0
	
	print("=== NPC PERFORMANCE RESULTS (12 NPCs) ===")
	print("Frames: %d, Duration: %.2fs" % [total_frames, _elapsed])
	print("Avg frame: %.3fms (%.2fms/NPC)" % [avg_ms, ms_per_npc])
	print("Min frame: %.3fms" % [min_ms])
	print("Max frame: %.3fms" % [max_ms])
	print("P95 frame: %.3fms" % [p95_ms])
	print("P99 frame: %.3fms" % [p99_ms])
	print("Budget (72 FPS): 13.89ms total, 1.16ms/NPC")
	print("Within budget: %s" % ["YES" if avg_ms <= 13.89 else "NO"])
	
	# Write JSON for CI
	var results = {
		"avg_ms": avg_ms,
		"min_ms": min_ms,
		"max_ms": max_ms,
		"p95_ms": p95_ms,
		"p99_ms": p99_ms,
		"ms_per_npc": ms_per_npc,
		"frame_budget_ms": 13.89,
		"npc_budget_ms": 1.16,
		"within_budget": avg_ms <= 13.89,
		"frame_count": total_frames
	}
	var file = FileAccess.open("user://perf_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results))
	file.close()
	print("Results written to user://perf_results.json")

func _setup_scene() -> void:
	_scene = Node.new()
	
	# Create player
	_player = Node3D.new()
	_player.name = "player"
	_player.global_position = Vector3(0, 0, 0)
	_scene.add_child(_player)
	
	# Create 12 NPCs
	for i in range(12):
		var npc = _create_test_npc("perf_npc_%d" % i)
		_npcs.append(npc)
		_scene.add_child(npc)
	
	# Position NPCs in a circle around player
	for i in range(12):
		var angle = (float(i) / 12.0) * TAU
		var radius = 10.0 + (i % 3) * 5.0
		_npcs[i].global_position = _player.global_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	
	print("PERF: Scene setup complete with 12 NPCs")

func _create_test_npc(npc_id: String) -> ArmedNpc:
	var npc = ArmedNpc.new()
	npc.npc_id = npc_id
	npc.faction_id = "hostile"
	npc.weapon_id = "pistol"
	npc.role = "hostile"
	npc.max_health = 100.0
	npc.vision_range = 20.0
	npc.patrol_speed = 2.0
	npc.run_speed = 5.5
	npc.auto_tick = true
	
	# Initialize NPC components
	npc.call_deferred("_init_components")
	
	return npc