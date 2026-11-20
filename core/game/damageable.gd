class_name Damageable
extends Node

signal damaged(amount: float, point: Vector3, normal: Vector3)
signal died

@export var health: float = 100.0
@export var max_health: float = 100.0

var zone_multipliers: Dictionary = {
	"head": 2.0,
	"neck": 2.0,
	"torso": 1.0,
	"body": 1.0,
	"limb": 0.55,
	"leg": 0.55,
	"arm": 0.55,
	"hand": 0.45,
	"foot": 0.45,
}
var last_source: Node = null
var last_zone: String = ""

var _dead: bool = false


func _ready() -> void:
	if max_health <= 0.0:
		max_health = maxf(health, 1.0)
	health = clampf(health, 0.0, max_health)
	if health <= 0.0:
		_dead = true


func is_dead() -> bool:
	return _dead


func reset(value: float = -1.0) -> void:
	_dead = false
	health = max_health if value < 0.0 else clampf(value, 0.0, max_health)
	last_source = null
	last_zone = ""


func multiplier_for(zone: String) -> float:
	var key := zone.strip_edges().to_lower()
	if zone_multipliers.has(key):
		return maxf(float(zone_multipliers[key]), 0.0)
	return 1.0


func get_hit_zone() -> String:
	if not last_zone.is_empty():
		return last_zone
	if has_meta("hit_zone"):
		return str(get_meta("hit_zone")).strip_edges().to_lower()
	return ""


func can_dismember() -> bool:
	return bool(get_meta("dismemberable", true)) and zone_multipliers.size() > 0


func take_damage(amount: float, point: Vector3, normal: Vector3, source: Node = null) -> void:
	if _dead or amount <= 0.0:
		return
	var applied: float = mini(amount, health)
	health = maxf(health - amount, 0.0)
	last_source = source
	damaged.emit(applied, point, normal)
	if health <= 0.0:
		_dead = true
		died.emit()


func take_zone_damage(zone: String, amount: float, point: Vector3, normal: Vector3, source: Node = null) -> void:
	if _dead or amount <= 0.0:
		return
	last_zone = zone.strip_edges().to_lower()
	take_damage(amount * multiplier_for(last_zone), point, normal, source)
