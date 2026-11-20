class_name Damageable
extends Node

const ModHooksScript = preload("res://core/game/mod_hooks.gd")

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
	last_source = source
	var event := ModHooksScript.emit("damage_dealt", ModHooksScript.payload_for("damage_dealt", {
		"target": str(get_instance_id()), "zone": last_zone, "amount": amount,
		"point": point, "source": str(source.get_instance_id()) if source != null else "",
		"lethal": amount >= health,
	}))
	var payload: Dictionary = event.get("payload", {})
	var final_amount: float = maxf(float(payload.get("amount", amount)), 0.0)
	var applied: float = mini(final_amount, health)
	health = maxf(health - final_amount, 0.0)
	damaged.emit(applied, point, normal)
	if health <= 0.0:
		_dead = true
		_emit_death_hooks(point, payload)
		died.emit()
	elif applied >= 10.0 and not last_zone.is_empty():
		ModHooksScript.emit("wound_created", {
			"target": str(get_instance_id()), "zone": last_zone,
			"severity": clampf(applied / maxf(max_health, 1.0), 0.0, 1.0),
			"point": point, "amount": applied,
		})


func _emit_death_hooks(point: Vector3, payload: Dictionary) -> void:
	var limbs := ["limb", "arm", "leg", "hand", "foot"]
	if can_dismember() and limbs.has(last_zone):
		ModHooksScript.emit("limb_severed", {
			"target": str(get_instance_id()), "limb": last_zone, "point": point,
			"severity": clampf(float(payload.get("amount", 0.0)) / maxf(max_health, 1.0), 0.0, 1.0),
		})
	if is_in_group("armed_npc"):
		var position: Variant = get("global_position") if has_method("get_global_transform") else point
		if not position is Vector3:
			position = point
		ModHooksScript.emit("npc_died", {
			"npc_id": str(get_instance_id()),
			"npc_type": str(get_meta("npc_type", "")),
			"killer": str(payload.get("source", "")), "position": position,
		})


func take_zone_damage(zone: String, amount: float, point: Vector3, normal: Vector3, source: Node = null) -> void:
	if _dead or amount <= 0.0:
		return
	last_zone = zone.strip_edges().to_lower()
	take_damage(amount * multiplier_for(last_zone), point, normal, source)
