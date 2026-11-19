extends SceneTree

const NPCStateMachine = preload("res://core/npc/npc_state_machine.gd")
const NPCPersonality = preload("res://core/npc/npc_personality.gd")
const NPCNeeds = preload("res://core/npc/npc_needs.gd")
const NPCMemory = preload("res://core/npc/npc_memory.gd")
const NPCRoutine = preload("res://core/npc/npc_routine.gd")
const NPCController = preload("res://core/npc/npc_controller.gd")
const NPCLOD = preload("res://core/npc/npc_lod.gd")

var success = true

func _init():
	run_tests()
	quit(0 if success else 1)

func assert_eq(actual, expected, message):
	if actual != expected:
		print("FAIL: %s | Expected %s, got %s" % [message, expected, actual])
		success = false
	else:
		print("PASS: %s" % message)

func run_tests():
	print("--- Starting NPC Core Tests ---")
	
	# 1. State Machine
	var sm = NPCStateMachine.new()
	assert_eq(sm.transition_to("walk"), true, "Valid transition idle -> walk")
	assert_eq(sm.get_state(), "walk", "State should be walk")
	assert_eq(sm.transition_to("recover"), false, "Invalid transition walk -> recover")
	assert_eq(sm.get_state(), "walk", "State should remain walk after invalid transition")
	
	# 2. Personality
	var pers = NPCPersonality.new({"bravery": 1.5, "fear": -0.5})
	assert_eq(pers.bravery, 1.0, "Bravery clamped to 1.0")
	assert_eq(pers.fear, 0.0, "Fear clamped to 0.0")
	
	# 3. Needs
	var needs = NPCNeeds.new()
	needs.change_fatigue(0.5)
	assert_eq(needs.fatigue, 0.5, "Fatigue set to 0.5")
	needs.tick(10.0) # Recovery: 0.01 * 10 = 0.1
	assert_eq(needs.fatigue, 0.4, "Fatigue recovered to 0.4")
	
	# 4. Memory
	var mem = NPCMemory.new(2)
	mem.add_event("e1")
	mem.add_event("e2")
	mem.add_event("e3")
	assert_eq(mem.get_events().size(), 2, "Memory capacity limit")
	assert_eq(mem.get_events()[0], "e2", "Oldest event e1 discarded")
	
	# 5. Routine
	var routine = NPCRoutine.new([{"id": "home", "dur": 10}, {"id": "work", "dur": 10}])
	assert_eq(routine.get_current_stop(2.0)["id"], "home", "Routine stop at 2am")
	assert_eq(routine.get_current_stop(14.0)["id"], "work", "Routine stop at 2pm")
	
	# 6. Controller
	var ctrl_sm = NPCStateMachine.new()
	var ctrl_pers = NPCPersonality.new({"fear": 0.9, "aggressiveness": 0.1})
	var ctrl_needs = NPCNeeds.new()
	var ctrl_mem = NPCMemory.new()
	var ctrl_rt = NPCRoutine.new([{"id": "walk_way", "dur": 1}])
	var ctrl = NPCController.new(ctrl_sm, ctrl_pers, ctrl_needs, ctrl_mem, ctrl_rt)
	
	# Scenario: Close player, high fear -> flee
	ctrl.update(0.1, {"player_distance": 2.0, "sim_hour": 12.0})
	assert_eq(ctrl_sm.get_state(), "flee", "Fearful NPC flees close player")
	
	# Scenario: Far player, routine active -> walk
	ctrl_sm.transition_to("idle") # Reset
	ctrl.update(0.1, {"player_distance": 100.0, "sim_hour": 12.0})
	assert_eq(ctrl_sm.get_state(), "walk", "Routine NPC walks when player far")
	
	# 7. LOD
	var lod = NPCLOD.new()
	assert_eq(lod.get_update_interval(5.0), 0.0, "LOD Close: 0.0")
	assert_eq(lod.get_update_interval(30.0), 1.0, "LOD Mid: 1.0")
	assert_eq(lod.get_update_interval(100.0), 5.0, "LOD Far: 5.0")
	
	print("--- Tests Finished ---")
