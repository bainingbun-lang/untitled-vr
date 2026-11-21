class_name NPCNeeds
extends RefCounted

# Core needs (0.0 to 1.0)
var fatigue: float = 0.0
var stress: float = 0.0
var fear: float = 0.0
var confusion: float = 0.0
var stun: float = 0.0
var health: float = 1.0

# Additional needs for daily life
var hunger: float = 0.0
var thirst: float = 0.0
var social: float = 0.0
var boredom: float = 0.0
var bladder: float = 0.0

# Recovery rates per second (can be modified by traits/perks)
var fatigue_recovery_rate: float = 0.01
var stress_recovery_rate: float = 0.02
var fear_recovery_rate: float = 0.05
var confusion_recovery_rate: float = 0.1
var stun_recovery_rate: float = 0.2
var hunger_increase_rate: float = 0.0005
var thirst_increase_rate: float = 0.0008
var social_decrease_rate: float = 0.0003
var boredom_increase_rate: float = 0.0004
var bladder_increase_rate: float = 0.0002

# State flags
var is_sleeping: bool = false
var is_eating: bool = false
var is_drinking: bool = false
var is_socializing: bool = false
var is_using_facility: bool = false

func _init(params: Dictionary = {}) -> void:
	fatigue = clamp(params.get("fatigue", 0.0), 0.0, 1.0)
	stress = clamp(params.get("stress", 0.0), 0.0, 1.0)
	fear = clamp(params.get("fear", 0.0), 0.0, 1.0)
	confusion = clamp(params.get("confusion", 0.0), 0.0, 1.0)
	stun = clamp(params.get("stun", 0.0), 0.0, 1.0)
	health = clamp(params.get("health", 1.0), 0.0, 1.0)
	hunger = clamp(params.get("hunger", 0.0), 0.0, 1.0)
	thirst = clamp(params.get("thirst", 0.0), 0.0, 1.0)
	social = clamp(params.get("social", 0.5), 0.0, 1.0)
	boredom = clamp(params.get("boredom", 0.0), 0.0, 1.0)
	bladder = clamp(params.get("bladder", 0.0), 0.0, 1.0)

func tick(delta: float) -> void:
	# Fatigue: decreases when sleeping, increases when awake
	if is_sleeping:
		fatigue = clamp(fatigue - (fatigue_recovery_rate * 3.0 * delta), 0.0, 1.0)
	else:
		fatigue = clamp(fatigue + (0.002 * delta), 0.0, 1.0)
	
	# Stress recovery
	stress = clamp(stress - (stress_recovery_rate * delta), 0.0, 1.0)
	
	# Fear recovery (faster when safe)
	fear = clamp(fear - (fear_recovery_rate * delta), 0.0, 1.0)
	
	# Confusion recovery
	confusion = clamp(confusion - (confusion_recovery_rate * delta), 0.0, 1.0)
	
	# Stun recovery
	stun = clamp(stun - (stun_recovery_rate * delta), 0.0, 1.0)
	
	# Hunger increases over time, decreases when eating
	if is_eating:
		hunger = clamp(hunger - (0.02 * delta), 0.0, 1.0)
	else:
		hunger = clamp(hunger + (hunger_increase_rate * delta), 0.0, 1.0)
	
	# Thirst increases over time, decreases when drinking
	if is_drinking:
		thirst = clamp(thirst - (0.03 * delta), 0.0, 1.0)
	else:
		thirst = clamp(thirst + (thirst_increase_rate * delta), 0.0, 1.0)
	
	# Social need decreases when socializing, increases when alone
	if is_socializing:
		social = clamp(social + (0.01 * delta), 0.0, 1.0)
	else:
		social = clamp(social - (social_decrease_rate * delta), 0.0, 1.0)
	
	# Boredom increases when idle, decreases when engaged
	if is_sleeping or is_eating or is_drinking or is_socializing or is_using_facility:
		boredom = clamp(boredom - (0.005 * delta), 0.0, 1.0)
	else:
		boredom = clamp(boredom + (boredom_increase_rate * delta), 0.0, 1.0)
	
	# Bladder increases, decreases when using facility
	if is_using_facility:
		bladder = clamp(bladder - (0.05 * delta), 0.0, 1.0)
	else:
		bladder = clamp(bladder + (bladder_increase_rate * delta), 0.0, 1.0)

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

func change_hunger(amount: float) -> void:
	hunger = clamp(hunger + amount, 0.0, 1.0)

func change_thirst(amount: float) -> void:
	thirst = clamp(thirst + amount, 0.0, 1.0)

func change_social(amount: float) -> void:
	social = clamp(social + amount, 0.0, 1.0)

func change_boredom(amount: float) -> void:
	boredom = clamp(boredom + amount, 0.0, 1.0)

func change_bladder(amount: float) -> void:
	bladder = clamp(bladder + amount, 0.0, 1.0)

func set_sleeping(value: bool) -> void:
	is_sleeping = value

func set_eating(value: bool) -> void:
	is_eating = value

func set_drinking(value: bool) -> void:
	is_drinking = value

func set_socializing(value: bool) -> void:
	is_socializing = value

func set_using_facility(value: bool) -> void:
	is_using_facility = value

func get_dominant_need() -> Dictionary:
	var needs: Dictionary = {
		"fatigue": fatigue,
		"stress": stress,
		"fear": fear,
		"confusion": confusion,
		"stun": stun,
		"hunger": hunger,
		"thirst": thirst,
		"social": 1.0 - social,
		"boredom": boredom,
		"bladder": bladder,
		"health": 1.0 - health
	}
	
	var max_need: String = ""
	var max_value: float = 0.0
	for key in needs.keys():
		if needs[key] > max_value:
			max_value = needs[key]
			max_need = key
	
	return {"need": max_need, "value": max_value, "all": needs}

func get_need_priority(need_name: String) -> float:
	match need_name:
		"health": return 100.0
		"stun": return 90.0
		"fear": return 80.0
		"bladder": return 70.0
		"hunger": return 60.0
		"thirst": return 50.0
		"fatigue": return 40.0
		"stress": return 30.0
		"social": return 20.0
		"boredom": return 10.0
		"confusion": return 5.0
	return 0.0

func needs_rest() -> bool:
	return fatigue > 0.7 or health < 0.4

func needs_food() -> bool:
	return hunger > 0.6

func needs_drink() -> bool:
	return thirst > 0.6

func needs_social() -> bool:
	return social < 0.3

func needs_facility() -> bool:
	return bladder > 0.7

func is_in_critical_state() -> bool:
	return health < 0.2 or stun > 0.5 or fear > 0.8 or fatigue > 0.9

func get_needs_summary() -> Dictionary:
	return {
		"fatigue": fatigue,
		"stress": stress,
		"fear": fear,
		"confusion": confusion,
		"stun": stun,
		"health": health,
		"hunger": hunger,
		"thirst": thirst,
		"social": social,
		"boredom": boredom,
		"bladder": bladder,
		"dominant": get_dominant_need(),
		"critical": is_in_critical_state()
	}