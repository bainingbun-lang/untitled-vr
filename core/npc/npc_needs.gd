class_name NPCNeeds
extends RefCounted

var fatigue: float = 0.0
var stress: float = 0.0
var fear: float = 0.0
var confusion: float = 0.0
var stun: float = 0.0
var health: float = 1.0

func tick(delta: float) -> void:
	# Recovery rates per second
	fatigue = clamp(fatigue - (0.01 * delta), 0.0, 1.0)
	stress = clamp(stress - (0.02 * delta), 0.0, 1.0)
	fear = clamp(fear - (0.05 * delta), 0.0, 1.0)
	confusion = clamp(confusion - (0.1 * delta), 0.0, 1.0)
	stun = clamp(stun - (0.2 * delta), 0.0, 1.0)

func change_fatigue(amount: float) -> void:
	fatigue = clamp(fatigue + amount, 0.0, 1.0)

func change_stress(amount: float) -> void:
	stress = clamp(stress + amount, 0.0, 1.0)

func change_fear(amount: float) -> void:
	fear = clamp(fear + amount, 0.0, 1.0)

func change_confusion(amount: float) -> void:
	confusion = clamp(confusion + amount, 0.0, 1.0)

func change_stun(amount: float) -> void:
	stun = clamp(stun + amount, 0.0, 1.0)

func change_health(amount: float) -> void:
	health = clamp(health + amount, 0.0, 1.0)
