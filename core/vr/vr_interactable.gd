class_name VrInteractable
extends Node3D

signal interacted(interactor: Node3D, action: String)
signal interaction_started(interactor: Node3D)
signal interaction_ended(interactor: Node3D)

const GRAB_RADIUS: float = 0.15
const INTERACTION_RADIUS: float = 0.25

var interactor: Node3D = null
var is_interacting: bool = false
var interaction_radius: float = INTERACTION_RADIUS
var grab_radius: float = GRAB_RADIUS

var _hand: String = "right"
var _interaction_type: String = "grab"

func _ready() -> void:
	add_to_group("vr_interactable")
	set_physics_process(true)
	set_process_input(true)

func _physics_process(delta: float) -> void:
	if not is_interacting or not is_instance_valid(interactor):
		_check_auto_release()
		return
	_update_interaction(delta)

func _check_auto_release() -> void:
	if is_interacting and (not is_instance_valid(interactor) or _is_too_far()):
		force_release()

func _is_too_far() -> bool:
	if not is_instance_valid(interactor):
		return true
	var actor_pos: Vector3 = interactor.global_position
	if interactor.has_method("get_hand_pose"):
		actor_pos = interactor.get_hand_pose(_hand).origin
	var distance: float = global_position.distance_to(actor_pos)
	return distance > interaction_radius * 2.0

func can_interact(actor: Node3D, hand: String = "right") -> bool:
	if is_interacting or not is_instance_valid(actor):
		return false
	var actor_pos: Vector3 = actor.global_position
	if actor.has_method("get_hand_pose"):
		actor_pos = actor.get_hand_pose(hand).origin
	var distance: float = global_position.distance_to(actor_pos)
	return distance <= interaction_radius

func start_interaction(actor: Node3D, hand: String = "right", interaction_type: String = "grab") -> bool:
	if not can_interact(actor, hand):
		return false
	interactor = actor
	_hand = hand
	_interaction_type = interaction_type
	is_interacting = true
	interaction_started.emit(actor)
	return true

func end_interaction() -> void:
	if not is_interacting:
		return
	var old_interactor := interactor
	interactor = null
	is_interacting = false
	interaction_ended.emit(old_interactor)

func force_release() -> void:
	end_interaction()

func _update_interaction(delta: float) -> void:
	pass

func _get_hand_pose() -> Transform3D:
	if not is_instance_valid(interactor):
		return Transform3D.IDENTITY
	if interactor.has_method("get_hand_pose"):
		return interactor.get_hand_pose(_hand)
	return interactor.global_transform

func _get_grip_value() -> float:
	if not is_instance_valid(interactor):
		return 0.0
	if interactor.has_method("get_grip_value"):
		return interactor.get_grip_value(_hand)
	return 1.0

func _get_trigger_value() -> float:
	if not is_instance_valid(interactor):
		return 0.0
	if interactor.has_method("get_trigger_value"):
		return interactor.get_trigger_value(_hand)
	return 0.0