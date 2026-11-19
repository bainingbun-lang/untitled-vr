class_name NPCStateMachine
extends RefCounted

signal state_changed(new_state: String)

var current_state: String = "idle"

const VALID_STATES: Array[String] = [
	"idle", "walk", "run", "sit", "rest", 
	"converse", "alert", "flee", "stunned", "recover", "need_help"
]

const VALID_TRANSITIONS: Dictionary = {
	"idle": ["walk", "run", "sit", "rest", "converse", "alert", "flee", "stunned", "need_help"],
	"walk": ["idle", "run", "sit", "rest", "converse", "alert", "stunned", "need_help"],
	"run": ["idle", "walk", "sit", "rest", "alert", "stunned", "need_help"],
	"sit": ["idle", "walk", "converse", "alert", "stunned", "need_help"],
	"rest": ["idle", "walk", "alert", "stunned", "need_help"],
	"converse": ["idle", "walk", "alert", "stunned", "need_help"],
	"alert": ["idle", "walk", "run", "flee", "stunned", "need_help"],
	"flee": ["idle", "walk", "run", "stunned", "need_help"],
	"stunned": ["recover"],
	"recover": ["idle", "walk", "alert", "need_help"],
	"need_help": ["idle", "walk", "recover"]
}

func transition_to(new_state: String) -> bool:
	if not VALID_STATES.has(new_state):
		return false
	
	var allowed = VALID_TRANSITIONS.get(current_state, []) as Array[String]
	if new_state in allowed:
		current_state = new_state
		state_changed.emit(current_state)
		return true
	
	return false

func get_state() -> String:
	return current_state
