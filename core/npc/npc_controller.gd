class_name NPCController
extends RefCounted

var state_machine: NPCStateMachine
var personality: NPCPersonality
var needs: NPCNeeds
var memory: NPCMemory
var routine: NPCRoutine

func _init(sm: NPCStateMachine, pers: NPCPersonality, nds: NPCNeeds, mem: NPCMemory, rt: NPCRoutine):
	state_machine = sm
	personality = pers
	needs = nds
	memory = mem
	routine = rt

func update(delta: float, context: Dictionary) -> void:
	var player_dist: float = context.get("player_distance", 100.0)
	var is_alert: bool = context.get("is_alert", false)
	var sim_hour: float = context.get("sim_hour", 12.0)
	
	# Needs update
	needs.tick(delta)
	
	# Decision Logic
	if needs.stun > 0.5:
		state_machine.transition_to("stunned")
		return
	
	if is_alert or player_dist < 20.0:
		if personality.fear > 0.7 and player_dist < 5.0:
			state_machine.transition_to("flee")
		elif personality.aggressiveness > 0.6:
			state_machine.transition_to("alert")
		else:
			state_machine.transition_to("alert")
		return

	# Routine logic
	var current_stop = routine.get_current_stop(sim_hour)
	if not current_stop.is_empty():
		state_machine.transition_to("walk")
	else:
		state_machine.transition_to("idle")
