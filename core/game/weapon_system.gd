class_name WeaponSystem
extends Node

signal empty(weapon_id: String)
signal reload_started(weapon_id: String)
signal reload_finished(weapon_id: String)
signal reload_cancelled(weapon_id: String)
signal impact(info: Dictionary)
signal cycled(weapon_id: String)

const DbScript = preload("res://core/game/weapon_db.gd")
const GoreFxScript = preload("res://core/game/gore_fx.gd")
const SurfaceScript = preload("res://core/game/surface_material.gd")
const ImpactFxScript = preload("res://core/game/impact_fx.gd")
const ModHooksScript = preload("res://core/game/mod_hooks.gd")

const CYCLE_REASON := "montar arma"
const CYCLE_BACK := 0.06
const MAX_PROJECTILES := 16
const MAX_DEBRIS := 20
const MAX_BROKEN := 32
const MAX_PENETRATIONS := 2
const MAX_RICOCHETS := 2
const VERY_FAR := 1.0e30

var spread_scale: float = 1.0
var damage_scale: float = 1.0
var impulse_scale: float = 1.0
var projectile_mode: String = "auto"
var dismember_on_kill: bool = false
var effects_enabled: bool = true

var _time: float = 0.0
var _next_allowed: Dictionary = {}
var _magazines: Dictionary = {}
var _reserves: Dictionary = {}
var _reload_ready: Dictionary = {}
var _reload_total: Dictionary = {}
var _manual_locks: Dictionary = {}
var _cycle_pending: Dictionary = {}
var _stroke_back: Dictionary = {}
var manual_cycle: bool = false
var _log: Array = []
var _projectiles: Array = []
var _projectile_events: Array = []
var _debris: Array = []
var _broken: Array = []


func _process(delta: float) -> void:
	advance(delta)


func current_time() -> float:
	return _time


func advance(delta: float) -> void:
	_time += maxf(delta, 0.0)
	_resolve_reloads()
	_step_projectiles(maxf(delta, 0.0))


func get_log() -> Array:
	return _log.duplicate()


func clear_log() -> void:
	_log.clear()


func ammo(weapon_id: String) -> int:
	var def: Dictionary = DbScript.get_def(weapon_id)
	if def.is_empty() or not bool(def.get("uses_ammo", true)):
		return -1
	return int(_magazines.get(weapon_id, int(def.get("mag", 0))))


func reserve(weapon_id: String) -> int:
	return maxi(int(_reserves.get(weapon_id, 0)), 0)


func set_ammo(weapon_id: String, loaded: int, reserve: int = -1) -> bool:
	var def: Dictionary = DbScript.get_def(weapon_id)
	if def.is_empty():
		return false
	if not bool(def.get("uses_ammo", true)):
		return true
	var mag: int = maxi(int(def.get("mag", 0)), 0)
	_magazines[weapon_id] = clampi(loaded, 0, mag)
	if reserve >= 0:
		_reserves[weapon_id] = reserve
	_reload_ready.erase(weapon_id)
	_reload_total.erase(weapon_id)
	return true


func is_reloading(weapon_id: String) -> bool:
	return _reload_ready.has(weapon_id) or _manual_locks.has(weapon_id)


# Escopeta (bombeo) y francotirador (cerrojo): con manual_cycle exigen accionar el mecanismo entre tiros.
func needs_cycle(weapon_id: String) -> bool:
	return _cycle_pending.has(weapon_id)


func clear_cycle(weapon_id: String) -> void:
	_cycle_pending.erase(weapon_id)
	_stroke_back.erase(weapon_id)


func cycle(weapon_id: String) -> bool:
	if not _cycle_pending.has(weapon_id):
		return false
	clear_cycle(weapon_id)
	cycled.emit(weapon_id)
	return true


# rel: desplazamiento de la mano libre respecto al reposo (negativo = hacia atras).
func cycle_stroke(weapon_id: String, rel: float) -> bool:
	if not _cycle_pending.has(weapon_id):
		return false
	if rel <= -CYCLE_BACK:
		_stroke_back[weapon_id] = true
	elif bool(_stroke_back.get(weapon_id, false)) and rel >= -CYCLE_BACK * 0.25:
		return cycle(weapon_id)
	return false


func set_manual_lock(weapon_id: String, reason: String = "recargando") -> void:
	if reason.is_empty():
		_manual_locks.erase(weapon_id)
	else:
		if not _manual_locks.has(weapon_id):
			var lower := reason.to_lower()
			if lower.contains("encasquill") or lower.contains("jam"):
				ModHooksScript.emit("weapon_jammed", {"weapon_id": weapon_id, "reason": reason})
		_manual_locks[weapon_id] = reason


func set_loaded_raw(weapon_id: String, loaded: int, reserve: int) -> void:
	_magazines[weapon_id] = maxi(loaded, 0)
	_reserves[weapon_id] = maxi(reserve, 0)


func reload_progress(weapon_id: String) -> float:
	if not _reload_ready.has(weapon_id):
		return 0.0
	var total: float = maxf(float(_reload_total.get(weapon_id, 0.0)), 0.0001)
	var left: float = maxf(float(_reload_ready[weapon_id]) - _time, 0.0)
	return clampf(1.0 - left / total, 0.0, 1.0)


func reload(weapon_id: String) -> bool:
	var def: Dictionary = DbScript.get_def(weapon_id)
	if def.is_empty() or not bool(def.get("uses_ammo", true)):
		return false
	_resolve_reloads()
	_ensure_loaded(weapon_id, def)
	if _reload_ready.has(weapon_id) or _manual_locks.has(weapon_id):
		return false
	var mag: int = maxi(int(def.get("mag", 0)), 0)
	if mag <= 0 or int(_magazines[weapon_id]) >= mag or reserve(weapon_id) <= 0:
		return false
	var duration := maxf(float(def.get("reload_time", 1.0)), 0.0)
	_reload_ready[weapon_id] = _time + duration
	_reload_total[weapon_id] = duration
	reload_started.emit(weapon_id)
	return true


func cancel_reload(weapon_id: String) -> bool:
	if not _reload_ready.has(weapon_id):
		return false
	_reload_ready.erase(weapon_id)
	_reload_total.erase(weapon_id)
	reload_cancelled.emit(weapon_id)
	_record("recarga cancelada: " + weapon_id)
	return true


func cancel_all_reloads() -> void:
	for key in _reload_ready.keys():
		cancel_reload(str(key))


func can_fire(weapon_id: String) -> bool:
	_resolve_reloads()
	return fire_block_reason(weapon_id).is_empty()


func fire_block_reason(weapon_id: String) -> String:
	var def: Dictionary = DbScript.get_def(weapon_id)
	if def.is_empty():
		return "arma desconocida: %s" % weapon_id
	if _reload_ready.has(weapon_id):
		return "recargando"
	if _manual_locks.has(weapon_id):
		return str(_manual_locks[weapon_id])
	if _cycle_pending.has(weapon_id):
		return CYCLE_REASON
	if bool(def.get("uses_ammo", true)):
		_ensure_loaded(weapon_id, def)
		if int(_magazines[weapon_id]) <= 0:
			return "sin municion"
	if _time < float(_next_allowed.get(weapon_id, 0.0)):
		return "cadencia"
	return ""


func fire_interval(weapon_id: String) -> float:
	var def: Dictionary = DbScript.get_def(weapon_id)
	return 1.0 / maxf(float(def.get("fire_rate", 1.0)), 0.001)


func ammo_info(weapon_id: String) -> Dictionary:
	var def: Dictionary = DbScript.get_def(weapon_id)
	var infinite := not bool(def.get("uses_ammo", true))
	return {
		"valid": not def.is_empty(),
		"weapon_id": weapon_id,
		"mag": ammo(weapon_id),
		"mag_size": maxi(int(def.get("mag", 0)), 0),
		"reserve": reserve(weapon_id),
		"infinite": infinite,
		"reloading": is_reloading(weapon_id),
		"reload_progress": reload_progress(weapon_id),
		"can_fire": can_fire(weapon_id),
		"block_reason": fire_block_reason(weapon_id),
		"needs_cycle": needs_cycle(weapon_id),
		"fire_interval": fire_interval(weapon_id),
	}


func fire(weapon_id: String, origin: Vector3, direction: Vector3, space: PhysicsDirectSpaceState3D, exclude: Array) -> Dictionary:
	var result := _make_result(weapon_id, origin)
	_resolve_reloads()
	var reason := fire_block_reason(weapon_id)
	if not reason.is_empty():
		result["error"] = reason
		result["block_reason"] = reason
		_record("disparo rechazado: " + reason)
		if reason.find("municion") >= 0:
			empty.emit(weapon_id)
		return result
	if space == null:
		result["error"] = "sin espacio fisico"
		_record(result["error"])
		return result
	var base_direction := direction.normalized()
	if base_direction.length_squared() < 0.0001:
		result["error"] = "direccion invalida"
		_record(result["error"])
		return result

	var def: Dictionary = DbScript.get_def(weapon_id)
	_next_allowed[weapon_id] = _time + fire_interval(weapon_id)
	if bool(def.get("uses_ammo", true)):
		_magazines[weapon_id] = maxi(int(_magazines.get(weapon_id, 0)) - 1, 0)
	result["fired"] = true
	if manual_cycle and int(_magazines.get(weapon_id, 0)) > 0:
		var tags: Array = def.get("tags", [])
		if tags.has("shotgun") or tags.has("sniper"):
			_cycle_pending[weapon_id] = true

	var count: int = maxi(int(def.get("pellets", 1)), 1)
	result["pellets"] = count
	var fired_event := ModHooksScript.emit("weapon_fired", {
		"weapon_id": weapon_id, "origin": origin, "direction": base_direction,
		"pellets": count, "damage": maxf(float(def.get("damage", 0.0)), 0.0),
		"ammo": int(_magazines.get(weapon_id, -1)), "projectile": false,
	})
	var fired_payload: Dictionary = fired_event.get("payload", {})
	var hooked_damage := maxf(
		float(fired_payload.get("damage", float(def.get("damage", 0.0)))) * damage_scale, 0.0
	)
	var excluded := _to_rids(exclude)
	if _use_projectile(def, origin, base_direction, space, excluded):
		_spawn_projectiles(weapon_id, def, origin, base_direction, excluded, space, result, hooked_damage)
		return result

	var damage: float = hooked_damage
	var shot_range: float = maxf(float(def.get("range", 10.0)), 0.01)
	var spread: float = maxf(float(def.get("spread", 0.0)), 0.0) * clampf(spread_scale, 0.0, 4.0)
	for i in range(count):
		var pellet_direction := _spread_direction(base_direction, spread)
		_trace_pellet(space, origin, pellet_direction, def, excluded, damage, shot_range, result)
	impact.emit(result.duplicate(true))
	return result


func _ensure_loaded(weapon_id: String, def: Dictionary) -> void:
	if not _magazines.has(weapon_id):
		_magazines[weapon_id] = maxi(int(def.get("mag", 0)), 0)
	if not _reserves.has(weapon_id):
		_reserves[weapon_id] = maxi(int(def.get("mag", 0)), 0) * 3


func _resolve_reloads() -> void:
	for key in _reload_ready.keys():
		var weapon_id := str(key)
		if _time < float(_reload_ready[key]):
			continue
		var def: Dictionary = DbScript.get_def(weapon_id)
		var duration := float(_reload_total.get(weapon_id, 0.0))
		_reload_ready.erase(key)
		_reload_total.erase(key)
		if def.is_empty():
			continue
		var mag: int = maxi(int(def.get("mag", 0)), 0)
		var need: int = mag - int(_magazines.get(weapon_id, 0))
		var stored: int = maxi(int(_reserves.get(weapon_id, 0)), 0)
		var taken: int = mini(need, stored)
		_magazines[weapon_id] = int(_magazines.get(weapon_id, 0)) + taken
		_reserves[weapon_id] = stored - taken
		ModHooksScript.emit("weapon_reloaded", {
			"weapon_id": weapon_id, "mag": int(_magazines[weapon_id]),
			"reserve": int(_reserves[weapon_id]), "duration": duration,
		})
		reload_finished.emit(weapon_id)


func _record(message: String) -> void:
	if not _log.has(message):
		_log.append(message)


func _make_result(weapon_id: String, origin: Vector3) -> Dictionary:
	return {
		"hit": false,
		"position": origin,
		"normal": Vector3.ZERO,
		"collider": null,
		"weapon_id": weapon_id,
		"fired": false,
		"hits": [],
		"damage": 0.0,
		"pellets": 0,
		"error": "",
		"surface": SurfaceScript.Type.CONCRETE,
		"surface_name": "concrete",
		"distance": 0.0,
		"falloff": 1.0,
		"penetrations": 0,
		"ricochets": 0,
		"projectile": false,
		"projectiles_spawned": 0,
		"stopped": false,
		"_best_distance": VERY_FAR,
	}


func _spread_direction(direction: Vector3, spread_degrees: float) -> Vector3:
	if spread_degrees <= 0.0:
		return direction
	var reference := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var right := direction.cross(reference).normalized()
	var up := right.cross(direction).normalized()
	var offset: float = tan(deg_to_rad(spread_degrees) * 0.5)
	return (direction + right * randf_range(-offset, offset) + up * randf_range(-offset, offset)).normalized()


func _to_rids(exclude: Array) -> Array[RID]:
	var result: Array[RID] = []
	if exclude == null:
		return result
	for entry in exclude:
		if typeof(entry) == TYPE_RID:
			result.append(entry)
		elif entry is CollisionObject3D:
			result.append((entry as CollisionObject3D).get_rid())
	return result


func _exclude_collider(excluded: Array[RID], collider) -> void:
	if collider == null:
		return
	if typeof(collider) == TYPE_RID:
		if not excluded.has(collider):
			excluded.append(collider)
	elif collider is CollisionObject3D:
		var rid := (collider as CollisionObject3D).get_rid()
		if not excluded.has(rid):
			excluded.append(rid)


func _falloff(distance: float, def: Dictionary) -> float:
	var start := maxf(float(def.get("falloff_start", 0.0)), 0.0)
	var end := maxf(float(def.get("falloff_end", start + 1.0)), start + 0.01)
	var minimum := clampf(float(def.get("falloff_min", 1.0)), 0.0, 1.0)
	if distance <= start:
		return 1.0
	if distance >= end:
		return minimum
	var t := (distance - start) / (end - start)
	return 1.0 + (minimum - 1.0) * clampf(t, 0.0, 1.0)


func _use_projectile(def: Dictionary, origin: Vector3, direction: Vector3, space: PhysicsDirectSpaceState3D, excluded: Array[RID]) -> bool:
	var speed := maxf(float(def.get("projectile_speed", 0.0)), 0.0)
	if speed <= 0.0:
		return false
	if projectile_mode == "always":
		return true
	if projectile_mode == "never":
		return false
	var minimum := maxf(float(def.get("projectile_min_distance", 40.0)), 0.0)
	var query := PhysicsRayQueryParameters3D.new()
	query.from = origin
	query.to = origin + direction * maxf(float(def.get("range", 100.0)), 0.01)
	query.exclude = excluded
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var probe: Dictionary = space.intersect_ray(query)
	if probe.is_empty():
		return false
	return origin.distance_to(probe.get("position", origin)) >= minimum


func _spawn_projectiles(weapon_id: String, def: Dictionary, origin: Vector3, direction: Vector3, excluded: Array[RID], space: PhysicsDirectSpaceState3D, result: Dictionary, base_damage: float = -1.0) -> void:
	var speed := float(def.get("projectile_speed", 0.0))
	var gravity := 9.81 * clampf(float(def.get("projectile_gravity", 0.0)), 0.0, 2.0)
	var damage := base_damage if base_damage >= 0.0 else maxf(float(def.get("damage", 0.0)), 0.0)
	var spread := maxf(float(def.get("spread", 0.0)), 0.0) * clampf(spread_scale, 0.0, 4.0)
	var shot_range := maxf(float(def.get("range", 100.0)), 0.01)
	var count: int = mini(maxi(int(def.get("pellets", 1)), 1), MAX_PROJECTILES)
	for i in range(count):
		if _projectiles.size() >= MAX_PROJECTILES:
			_projectiles.pop_front()
		var pellet_direction := _spread_direction(direction, spread)
		_projectiles.append({
			"weapon_id": weapon_id,
			"def": def,
			"position": origin,
			"origin": origin,
			"velocity": pellet_direction * speed,
			"gravity": Vector3(0.0, -gravity, 0.0),
			"exclude": excluded.duplicate(),
			"space": space,
			"damage": damage,
			"life": 0.0,
			"life_max": maxf(shot_range / speed, 0.05),
			"traveled": 0.0,
			"range": shot_range,
		})
	result["projectile"] = true
	result["projectiles_spawned"] = count


func _step_projectiles(delta: float) -> void:
	if _projectiles.is_empty() or delta <= 0.0:
		return
	var steps := clampi(ceili(delta / 0.05), 1, 8)
	var dt: float = delta / float(steps)
	for i in range(steps):
		_step_projectile_batch(dt)


func _step_projectile_batch(dt: float) -> void:
	var done: Array = []
	for projectile in _projectiles:
		var velocity: Vector3 = projectile["velocity"] + (projectile["gravity"] as Vector3) * dt
		projectile["velocity"] = velocity
		var from: Vector3 = projectile["position"]
		var to: Vector3 = from + velocity * dt
		var step_length := from.distance_to(to)
		if step_length <= 0.0001:
			continue
		var step_result := _make_result(str(projectile["weapon_id"]), from)
		_trace_pellet(
			projectile["space"] as PhysicsDirectSpaceState3D,
			from,
			(to - from).normalized(),
			projectile["def"] as Dictionary,
			projectile["exclude"] as Array,
			float(projectile["damage"]),
			step_length,
			step_result,
			float(projectile["traveled"])
		)
		projectile["position"] = to
		projectile["life"] = float(projectile["life"]) + dt
		projectile["traveled"] = float(projectile["traveled"]) + step_length
		if bool(step_result["stopped"]) or float(projectile["life"]) >= float(projectile["life_max"]) or float(projectile["traveled"]) >= float(projectile["range"]):
			done.append(projectile)
			_projectile_events.append({
				"weapon_id": projectile["weapon_id"],
				"hit": step_result["hit"],
				"position": step_result["position"],
				"damage": step_result["damage"],
				"penetrations": step_result["penetrations"],
				"ricochets": step_result["ricochets"],
			})
			if bool(step_result["hit"]):
				ModHooksScript.emit("projectile_hit", {
					"weapon_id": str(projectile["weapon_id"]), "hit": true,
					"position": step_result["position"], "damage": float(step_result["damage"]),
					"distance": float(step_result["distance"]),
					"surface": str(step_result.get("surface_name", "concrete")),
				})
	for projectile in done:
		_projectiles.erase(projectile)


func projectile_count() -> int:
	return _projectiles.size()


func projectile_events() -> Array:
	return _projectile_events.duplicate(true)


func clear_projectile_events() -> void:
	_projectile_events.clear()


func _trace_pellet(space: PhysicsDirectSpaceState3D, origin: Vector3, direction: Vector3, def: Dictionary, excluded: Array, base_damage: float, shot_range: float, result: Dictionary, distance_offset: float = 0.0) -> void:
	if space == null or shot_range <= 0.001:
		return
	var dir := direction.normalized()
	if dir.length_squared() < 0.0001:
		return
	var cursor := origin
	var remaining := shot_range
	var damage := base_damage
	var excluded_ids := _to_rids(excluded)
	var max_pen: int = mini(maxi(int(def.get("max_penetrations", 1)), 0), MAX_PENETRATIONS)
	var max_bounce: int = mini(maxi(int(def.get("max_ricochets", 1)), 0), MAX_RICOCHETS)
	var penetrations := 0
	var ricochets := 0
	var steps := 0
	var stopped := false
	while remaining > 0.01 and steps < 8:
		steps += 1
		var query := PhysicsRayQueryParameters3D.new()
		query.from = cursor
		query.to = cursor + dir * remaining
		query.exclude = excluded_ids
		query.collide_with_bodies = true
		query.collide_with_areas = false
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			break
		var hit_position: Vector3 = hit.get("position", cursor)
		var hit_normal: Vector3 = hit.get("normal", Vector3.ZERO)
		if hit_normal.length_squared() > 0.0001:
			hit_normal = hit_normal.normalized()
		var collider = hit.get("collider", null)
		var travelled: float = cursor.distance_to(hit_position)
		var full_distance: float = distance_offset + origin.distance_to(hit_position)
		var falloff := _falloff(full_distance, def)
		var dealt: float = maxf(damage * falloff, 0.0)
		var surface := SurfaceScript.from_collider(collider)
		var surface_def := SurfaceScript.props(surface)
		var zone := _zone_of(collider)
		var reflected := dir - 2.0 * dir.dot(hit_normal) * hit_normal
		if reflected.length_squared() > 0.0001:
			reflected = reflected.normalized()
		else:
			reflected = hit_normal
		_register_hit(result, hit_position, hit_normal, collider, zone, dealt, surface, full_distance, falloff)
		var target := _damageable_of(collider)
		if target != null:
			_damage_target(target, zone, dealt, hit_position, hit_normal, reflected)
		elif effects_enabled:
			ImpactFxScript.spawn(self, surface, hit_position, hit_normal, dealt, reflected)
		_apply_impulse(collider, dir, hit_position, dealt, def, surface_def)

		var power := clampf(float(def.get("penetration", 0.0)), 0.0, 1.0)
		var grazing: bool = hit_normal.length_squared() > 0.0001 and absf(dir.dot(hit_normal)) < 0.5
		if target == null and penetrations < max_pen and SurfaceScript.can_penetrate(surface, power):
			var transmitted: float = dealt * clampf(float(surface_def.get("transfer", 0.0)), 0.0, 1.0)
			transmitted *= 1.0 - clampf(float(surface_def.get("absorption", 0.0)), 0.0, 1.0) * 0.5
			if transmitted <= 0.01:
				stopped = true
				break
			damage = transmitted
			penetrations += 1
			result["penetrations"] = penetrations
			_exclude_collider(excluded_ids, collider)
			cursor = hit_position + dir * 0.02
			remaining = maxf(remaining - travelled - 0.02, 0.0)
			continue
		if target == null and grazing and float(surface_def.get("bounce", 0.0)) >= 0.5 and ricochets < max_bounce:
			dir = (reflected + Vector3(randf_range(-0.02, 0.02), randf_range(-0.02, 0.02), randf_range(-0.02, 0.02))).normalized()
			damage = dealt * 0.55
			ricochets += 1
			result["ricochets"] = ricochets
			_exclude_collider(excluded_ids, collider)
			cursor = hit_position + dir * 0.02
			remaining = maxf(remaining - travelled - 0.02, 0.0)
			continue
		stopped = true
		break
	result["stopped"] = stopped


func _register_hit(result: Dictionary, hit_position: Vector3, hit_normal: Vector3, collider, zone: String, dealt: float, surface: int, distance: float, falloff: float) -> void:
	var entry := {
		"position": hit_position,
		"normal": hit_normal,
		"collider": collider,
		"zone": zone,
		"damage": dealt,
		"surface": surface,
		"surface_name": SurfaceScript.type_name(surface),
		"distance": distance,
		"falloff": falloff,
	}
	(result["hits"] as Array).append(entry)
	result["damage"] = float(result["damage"]) + dealt
	if distance < float(result["_best_distance"]):
		result["_best_distance"] = distance
		result["hit"] = true
		result["position"] = hit_position
		result["normal"] = hit_normal
		result["collider"] = collider
		result["surface"] = surface
		result["surface_name"] = SurfaceScript.type_name(surface)
		result["distance"] = distance
		result["falloff"] = falloff


func _damage_target(target: Node, zone: String, damage: float, point: Vector3, normal: Vector3, flow: Vector3) -> void:
	if not zone.is_empty() and target.has_method("take_zone_damage"):
		target.call("take_zone_damage", zone, damage, point, normal, self)
	else:
		target.call("take_damage", damage, point, normal, self)
	if target.has_method("is_dead") and bool(target.call("is_dead")):
		GoreFxScript.on_death(self, point, 0.8)
		if dismember_on_kill and target.has_method("can_dismember") and bool(target.call("can_dismember")):
			var parts := GoreFxScript.dismember(self, point, 0.8, zone, 3)
			_record("desmembramiento: %d partes" % parts.size())
	else:
		GoreFxScript.blood_hit(self, point, flow, damage, flow, damage > 45.0)


func _zone_of(collider) -> String:
	var node := collider as Node
	if node == null:
		return ""
	if node.has_method("get_hit_zone"):
		var value = node.call("get_hit_zone")
		if typeof(value) == TYPE_STRING and not str(value).strip_edges().is_empty():
			return str(value).strip_edges().to_lower()
	for key in ["hit_zone", "zone", "damage_zone", "body_zone"]:
		if node.has_meta(key):
			var meta_value = node.get_meta(key)
			if typeof(meta_value) == TYPE_STRING and not str(meta_value).strip_edges().is_empty():
				return str(meta_value).strip_edges().to_lower()
		var property_value = node.get(key)
		if typeof(property_value) == TYPE_STRING and not str(property_value).strip_edges().is_empty():
			return str(property_value).strip_edges().to_lower()
	return ""


func _damageable_of(collider) -> Node:
	var node := collider as Node
	if node == null:
		return null
	var cursor := node
	var depth := 0
	while cursor != null and depth < 8:
		if cursor.has_method("take_damage"):
			return cursor
		cursor = cursor.get_parent()
		depth += 1
	for child in node.get_children():
		if child.has_method("take_damage"):
			return child
	return null


func _rigid_of(collider) -> Node:
	var cursor := collider as Node
	var depth := 0
	while cursor != null and depth < 8:
		if cursor is RigidBody3D:
			return cursor
		cursor = cursor.get_parent()
		depth += 1
	return null


func _break_energy(node) -> float:
	var cursor := node as Node
	var depth := 0
	while cursor != null and depth < 5:
		if cursor.has_meta("breakable") and not bool(cursor.get_meta("breakable")):
			return VERY_FAR
		if cursor.has_meta("break_energy"):
			return maxf(float(cursor.get_meta("break_energy")), 0.0)
		if cursor.has_meta("breakable") and bool(cursor.get_meta("breakable")):
			return 30.0
		if cursor.is_in_group("breakable"):
			return 30.0
		cursor = cursor.get_parent()
		depth += 1
	return VERY_FAR


func _apply_impulse(collider, direction: Vector3, hit_position: Vector3, damage: float, def: Dictionary, surface_def: Dictionary) -> void:
	var body := _rigid_of(collider)
	if body == null:
		return
	var rigid := body as RigidBody3D
	var mass := maxf(float(rigid.mass), 0.05)
	var speed := maxf(float(def.get("impact_speed", 60.0)), 1.0)
	var bullet_mass := 0.004 * clampf(float(def.get("weight", 1.0)), 0.25, 6.0)
	var energy := 0.5 * bullet_mass * speed * speed
	var transfer := clampf(float(def.get("impulse", 0.05)), 0.0, 1.0)
	transfer *= 0.4 + clampf(float(surface_def.get("transfer", 0.2)), 0.0, 1.0) * 0.6
	var strength := energy * transfer * clampf(impulse_scale, 0.0, 10.0) * clampf(2.0 / (mass + 1.0), 0.1, 2.0)
	if strength <= 0.0:
		return
	var offset := hit_position - rigid.global_position
	rigid.apply_impulse(direction.normalized() * strength, offset)
	if collider is Node and ((collider as Node).is_in_group("rollable") or (collider as Node).has_meta("rollable")):
		rigid.angular_velocity += direction.cross(Vector3.UP) * clampf(strength * 0.02, 0.0, 4.0)
	if _break_energy(collider) <= energy and energy > 0.0:
		_break_prop(rigid, energy)


func _break_prop(body: RigidBody3D, energy: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	var parent := body.get_parent()
	if parent == null:
		return
	var center := body.global_position
	while _debris.size() + 3 > MAX_DEBRIS:
		_retire_debris(_debris.pop_front())
	for i in range(3):
		var chunk := RigidBody3D.new()
		chunk.name = "Debris"
		chunk.mass = maxf(float(body.mass) / 3.0, 0.05)
		chunk.position = center + Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.4), randf_range(-0.3, 0.3))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.2, 0.2, 0.2)
		shape.shape = box
		chunk.add_child(shape)
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = box.size
		visual.mesh = mesh
		chunk.add_child(visual)
		parent.add_child(chunk)
		chunk.apply_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(0.3, 1.0), randf_range(-1.0, 1.0)).normalized() * clampf(energy * 0.02, 0.5, 8.0))
		_debris.append(chunk)
	body.set_meta("broken", true)
	_broken.append(body)
	while _broken.size() > MAX_BROKEN:
		_broken.pop_front()
	_record("prop roto")
	_retire_debris(body)


func debris_count() -> int:
	return _debris.size()


func broken_count() -> int:
	return _broken.size()


func clear_effects() -> void:
	ImpactFxScript.clear()
	GoreFxScript.clear()
	for node in _debris:
		_retire_debris(node)
	_debris.clear()
	_broken.clear()


func _retire_debris(node) -> void:
	if is_instance_valid(node) and not (node as Node).is_queued_for_deletion():
		(node as Node).queue_free()
