extends SceneTree

const HarnessScript = preload("res://tests/vr_sim_harness.gd")
const GeneratorScript = preload("res://core/maps/map_generator.gd")
const WorldScene = preload("res://scenes/world/game_world.tscn")
const SessionScript = preload("res://core/game/game_session.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""

func _initialize() -> void:
	await process_frame
	await _run_probe()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + str(failure))
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])

func _run_probe() -> void:
	_case = "sonda VR: 1 NPC en mapa vacio"
	
	var harness = HarnessScript.new()
	var meta = GeneratorScript.generate(9999, {
		"width": 24, "height": 18, "obstacle_density": 0.0, "spawn_count": 1,
	})
	meta["max_npcs"] = 2
	await harness.start(self, meta)
	var world = harness.world
	await process_frame
	for i in range(5):
		await physics_frame
	
	_expect(world.npcs.size() >= 1, "hay al menos 1 NPC (%d)" % world.npcs.size())
	if world.npcs.size() == 0:
		harness.cleanup()
		await process_frame
		return
	
	var npc = world.npcs[0] as Node3D
	print("[PROBE] NPC: %s role=%s platform=%s" % [npc.name, str(npc.get("role")), str(npc.get("platform"))])
	print("[PROBE] NPC auto_tick=%s _use_steering=%s _use_behavior_tree=%s" % [str(npc.auto_tick), str(npc._use_steering), str(npc._use_behavior_tree)])
	print("[PROBE] NPC _steering_initialized=%s _behavior_tree_initialized=%s" % [str(npc._steering_initialized), str(npc._behavior_tree_initialized)])
	print("[PROBE] NPC steering_agent=%s steering_behavior=%s" % [str(npc.steering_agent), str(npc.steering_behavior)])
	print("[PROBE] NPC behavior_tree=%s bt_blackboard=%s" % [str(npc.behavior_tree), str(npc.bt_blackboard)])
	
	var pos_before = npc.global_position
	print("[PROBE] NPC pos inicial: %s" % str(pos_before))
	
	for frame in range(240):
		await physics_frame
		harness.step(2)
		
		if frame % 40 == 0:
			var pos = npc.global_position
			var moved = pos.distance_to(pos_before)
			var vel = npc.velocity if npc.has_method("get_velocity") else Vector3.ZERO
			if npc.has_method("get_velocity"):
				vel = npc.velocity
			elif npc.has("velocity"):
				vel = npc.get("velocity")
			
			print("[PROBE] Frame %d: pos=%s moved=%.3f vel=%s" % [frame, str(pos), moved, str(vel)])
			
			if npc.behavior_tree != null and npc.bt_blackboard != null:
				var action_id = str(npc.bt_blackboard.get_value("current_action", npc.behavior_tree))
				var move_target = npc.bt_blackboard.get_value("move_target", npc.behavior_tree)
				var behavior_mode = str(npc.bt_blackboard.get_value("behavior_mode", npc.behavior_tree))
				print("[PROBE]   BT: action=%s move_target=%s mode=%s" % [action_id, str(move_target), behavior_mode])
			
			if npc.steering_agent != null:
				print("[PROBE]   SteeringAgent: pos=%s ori=%.3f vel=%s max_speed=%.2f" % [
					str(npc.steering_agent.position), npc.steering_agent.orientation, 
					str(npc.steering_agent.linear_velocity), npc.steering_agent.linear_speed_max
				])
				if npc._steering_arrive_target != null:
					print("[PROBE]   ArriveTarget: pos=%s" % str(npc._steering_arrive_target.position))
			
			if npc.steering_behavior != null and npc.steering_behavior is Priority:
				var priority = npc.steering_behavior as Priority
				var accel = TargetAcceleration.new()
				priority.calculate_steering(accel)
				print("[PROBE]   PrioritySteering: accel=%s last_selected=%d" % [str(accel.linear), priority.last_selected_index])
				
				for i in range(priority._behaviors.size()):
					var behavior = priority.get_behavior_at(i)
					if behavior != null:
						var b_accel = TargetAcceleration.new()
						behavior.calculate_steering(b_accel)
						print("[PROBE]     Behavior[%d] %s: accel=%s" % [i, behavior.get_class(), str(b_accel.linear)])
	
	var pos_after = npc.global_position
	var total_moved = pos_after.distance_to(pos_before)
	print("[PROBE] NPC pos final: %s total_moved=%.3f" % [str(pos_after), total_moved])
	
	_expect(total_moved > 0.5, "NPC se movio mas de 0.5m en 240 frames (movio %.2f)" % total_moved)
	
	harness.cleanup()
	await process_frame