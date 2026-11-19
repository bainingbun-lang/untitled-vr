class_name NPCPersonality
extends RefCounted

var temperament: float = 0.5
var confidence: float = 0.5
var bravery: float = 0.5
var fear: float = 0.5
var curiosity: float = 0.5
var sociability: float = 0.5
var aggressiveness: float = 0.5

func _init(params: Dictionary = {}):
	temperament = clamp(params.get("temperament", 0.5), 0.0, 1.0)
	confidence = clamp(params.get("confidence", 0.5), 0.0, 1.0)
	bravery = clamp(params.get("bravery", 0.5), 0.0, 1.0)
	fear = clamp(params.get("fear", 0.5), 0.0, 1.0)
	curiosity = clamp(params.get("curiosity", 0.5), 0.0, 1.0)
	sociability = clamp(params.get("sociability", 0.5), 0.0, 1.0)
	aggressiveness = clamp(params.get("aggressiveness", 0.5), 0.0, 1.0)
