class_name NpcDismemberReaction
extends Node

const GameSessionScript = preload("res://core/game/game_session.gd")
const ModHooksScript = preload("res://core/game/mod_hooks.gd")

enum ReactionState {
	IDLE = 0,
	FALL = 1,
	CRAWL = 2,
	FLEE = 3
}

var _reaction_state: int = ReactionState.IDLE
var _severed_limbs: Array[String] = []
var _subscription_id: int = -1
var _armed: bool = false
var _target_id: String = ""

func _ready() -> void:
	if not GameSessionScript.gore_enabled:
		return
	var bus = ModHooksScript.instance().get_bus()
	if bus != null:
		_subscription_id = bus.subscribe("limb_severed", Callable(self, "_on_limb_severed"), "npc_dismember_reaction_%d" % get_instance_id())
	var parent = get_parent()
	if parent != null:
		_target_id = str(parent.get_instance_id())
		_armed = bool(parent.get_meta("armed", false))

func _exit_tree() -> void:
	if _subscription_id >= 0:
		var bus = ModHooksScript.instance().get_bus()
		if bus != null:
			bus.unsubscribe(_subscription_id)
		_subscription_id = -1

func _on_limb_severed(payload: Dictionary) -> void:
	if not GameSessionScript.gore_enabled:
		return
	
	var target_id: String = str(payload.get("target", ""))
	if target_id != _target_id:
		return
	
	var limb: String = str(payload.get("limb", "")).to_lower()
	if limb.is_empty():
		return
	
	if not _severed_limbs.has(limb):
		_severed_limbs.append(limb)
	
	_update_reaction_state()

func _update_reaction_state() -> void:
	var has_left_leg := _severed_limbs.has("leg.l") or _severed_limbs.has("leg_left")
	var has_right_leg := _severed_limbs.has("leg.r") or _severed_limbs.has("leg_right")
	var has_left_arm := _severed_limbs.has("arm.l") or _severed_limbs.has("arm_left")
	var has_right_arm := _severed_limbs.has("arm.r") or _severed_limbs.has("arm_right")
	
	var legs_lost := 0
	if has_left_leg:
		legs_lost += 1
	if has_right_leg:
		legs_lost += 1
	
	var arms_lost := 0
	if has_left_arm:
		arms_lost += 1
	if has_right_arm:
		arms_lost += 1
	
	if legs_lost >= 2:
		_reaction_state = ReactionState.CRAWL
	elif legs_lost >= 1:
		_reaction_state = ReactionState.FALL
	elif arms_lost >= 1 and _armed:
		_reaction_state = ReactionState.FLEE
	else:
		_reaction_state = ReactionState.IDLE

func get_reaction_state() -> String:
	match _reaction_state:
		ReactionState.IDLE:
			return "idle"
		ReactionState.FALL:
			return "fall"
		ReactionState.CRAWL:
			return "crawl"
		ReactionState.FLEE:
			return "flee"
		_:
			return "idle"

func get_severed_limbs() -> Array[String]:
	return _severed_limbs.duplicate()

func set_armed(armed: bool) -> void:
	_armed = armed
	var parent = get_parent()
	if parent != null:
		parent.set_meta("armed", armed)