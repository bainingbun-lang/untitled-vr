class_name NPCPerception
extends RefCounted

# Percepcion pura (sin escenas): solo matematica sobre posiciones y estimulos.
# Adaptaciones documentadas (interfaces existentes sin modificar):
# - NPCMemory.add_event(event: Variant) no esta tipado: el adaptador escribe
#   Dictionary con {type, kind, source_id, channel, intensity, severity,
#   position, distance, priority, tick}. NPCBehavior._memory_danger ya lee
#   "type"/"kind" y "severity"/"intensity", por lo que los estimulos de peligro
#   quedan compatibles sin tocar NPCMemory.
# - La linea de vista se inyecta como Callable(from, to) -> bool returning
#   true si hay vision despejada; por defecto se considera despejada.
# - Todo determinista: sin azar, orden por prioridad y desempate estable.

const DEFAULT_VISION_RANGE: float = 25.0
const DEFAULT_VISION_HALF_ANGLE_DEG: float = 55.0
const DEFAULT_HEARING_RANGE: float = 25.0
const DEFAULT_MAX_STIMULI_PER_TICK: int = 8
const TIE_EPSILON: float = 0.000001

var vision_range: float = DEFAULT_VISION_RANGE
var vision_half_angle_deg: float = DEFAULT_VISION_HALF_ANGLE_DEG
var hearing_range: float = DEFAULT_HEARING_RANGE
var max_stimuli_per_tick: int = DEFAULT_MAX_STIMULI_PER_TICK
var line_of_sight: Callable = Callable()

var _tick: int = 0


func _init(p_options: Dictionary = {}) -> void:
	vision_range = maxf(0.0, float(p_options.get("vision_range", vision_range)))
	vision_half_angle_deg = clampf(float(p_options.get("vision_half_angle_deg", vision_half_angle_deg)), 0.0, 180.0)
	hearing_range = maxf(0.0, float(p_options.get("hearing_range", hearing_range)))
	max_stimuli_per_tick = maxi(0, int(p_options.get("max_stimuli_per_tick", max_stimuli_per_tick)))
	var los_value: Variant = p_options.get("line_of_sight", p_options.get("los", null))
	if los_value is Callable:
		line_of_sight = los_value as Callable


func set_line_of_sight(callback: Callable) -> void:
	line_of_sight = callback


func get_tick() -> int:
	return _tick


func configure(p_options: Dictionary = {}) -> void:
	if p_options.has("vision_range"):
		vision_range = maxf(0.0, float(p_options["vision_range"]))
	if p_options.has("vision_half_angle_deg"):
		vision_half_angle_deg = clampf(float(p_options["vision_half_angle_deg"]), 0.0, 180.0)
	if p_options.has("hearing_range"):
		hearing_range = maxf(0.0, float(p_options["hearing_range"]))
	if p_options.has("max_stimuli_per_tick"):
		max_stimuli_per_tick = maxi(0, int(p_options["max_stimuli_per_tick"]))
	if p_options.has("line_of_sight") and p_options["line_of_sight"] is Callable:
		line_of_sight = p_options["line_of_sight"] as Callable


# Apunta el cono de vision. Acepta Vector2 (x,y) o Vector3 (x,z).
func facing_value(value: Variant) -> Vector2:
	var direction: Vector2 = _as_2d(value)
	if direction.length_squared() <= TIE_EPSILON:
		return Vector2.RIGHT
	return direction.normalized()


# position/facing/target estilo 2D o 3D; en 3D se usa el plano XZ.
func can_see(position: Variant, facing: Variant, target: Variant, options: Dictionary = {}) -> Dictionary:
	var origin: Vector2 = _as_2d(position)
	var direction: Vector2 = facing_value(facing)
	var target_2d: Vector2 = _as_2d(target)
	var offset: Vector2 = target_2d - origin
	var distance: float = offset.length()
	var range_value: float = float(options.get("vision_range", vision_range))
	var angle_value: float = clampf(float(options.get("vision_half_angle_deg", vision_half_angle_deg)), 0.0, 180.0)
	var half_angle_rad: float = deg_to_rad(angle_value)
	var result: Dictionary = {
		"visible": false,
		"reason": "",
		"distance": distance,
		"angle_deg": 0.0,
		"range": range_value,
	}
	if distance <= TIE_EPSILON:
		result["visible"] = true
		result["reason"] = "coincident"
		return result
	if distance > range_value:
		result["reason"] = "out_of_range"
		return result
	var angle_rad: float = absf(direction.angle_to(offset / distance))
	if angle_rad > half_angle_rad + TIE_EPSILON:
		result["angle_deg"] = rad_to_deg(angle_rad)
		result["reason"] = "out_of_cone"
		return result
	result["angle_deg"] = rad_to_deg(angle_rad)
	if not _has_line_of_sight(position, target, options):
		result["reason"] = "occluded"
		return result
	result["visible"] = true
	result["reason"] = "clear"
	return result


# Evalua un estimulo {id|source_id, kind|type, position, noise|loudness|radius,
# priority, channel, visible}. distance se calcula desde observer_position.
func evaluate_stimulus(stimulus: Dictionary, observer_position: Variant, observer_facing: Variant, options: Dictionary = {}) -> Dictionary:
	var target: Variant = stimulus.get("position", stimulus.get("target", Vector2.ZERO))
	var distance: float = _distance(observer_position, target)
	var kind: String = str(stimulus.get("kind", stimulus.get("type", ""))).to_lower()
	var channel: String = str(stimulus.get("channel", "")).to_lower()
	var base_priority: float = float(stimulus.get("priority", stimulus.get("severity", 0.5)))
	var evaluated: Dictionary = {
		"id": str(stimulus.get("id", stimulus.get("source_id", ""))),
		"source_id": str(stimulus.get("source_id", stimulus.get("id", ""))),
		"kind": kind,
		"type": kind,
		"channel": channel,
		"position": target,
		"distance": distance,
		"priority": 0.0,
		"base_priority": base_priority,
		"intensity": 0.0,
		"visible": false,
		"heard": false,
		"reason": "ignored",
	}

	var perception_channel: String = channel
	if perception_channel.is_empty():
		perception_channel = str(stimulus.get("sense", "")).to_lower()
	if perception_channel.is_empty():
		perception_channel = "vision" if noise_value(stimulus) <= 0.0 else "hearing"

	var explicitly_visible: bool = bool(stimulus.get("visible", false))
	if perception_channel == "vision" or perception_channel == "sight":
		var vision_check: Dictionary = can_see(observer_position, observer_facing, target, options)
		evaluated["visible"] = bool(vision_check["visible"]) or explicitly_visible
		evaluated["angle_deg"] = float(vision_check.get("angle_deg", 0.0))
		if evaluated["visible"]:
			evaluated["channel"] = "vision"
			evaluated["intensity"] = clampf(base_priority * _distance_attenuation(distance, float(options.get("vision_range", vision_range))), 0.0, 1.0)
			evaluated["priority"] = evaluated["intensity"]
			evaluated["reason"] = str(vision_check["reason"])
		else:
			evaluated["reason"] = str(vision_check["reason"])
	elif perception_channel == "gunshot" or perception_channel == "disparo" or kind == "gunshot" or kind == "disparo":
		var gunshot: Dictionary = can_hear_gunshot(stimulus, observer_position, options)
		evaluated["heard"] = bool(gunshot["heard"])
		evaluated["channel"] = "gunshot"
		evaluated["reason"] = str(gunshot["reason"])
		if evaluated["heard"]:
			evaluated["intensity"] = clampf(float(gunshot["intensity"]), 0.0, 1.0)
			evaluated["priority"] = evaluated["intensity"] * 2.0
	elif perception_channel == "hearing" or perception_channel == "sound" or perception_channel == "noise":
		var hearing: Dictionary = can_hear(stimulus, observer_position, options)
		evaluated["heard"] = bool(hearing["heard"])
		evaluated["channel"] = "hearing"
		evaluated["reason"] = str(hearing["reason"])
		if evaluated["heard"]:
			evaluated["intensity"] = clampf(float(hearing["intensity"]), 0.0, 1.0)
			evaluated["priority"] = evaluated["intensity"]
	return evaluated


# Radio de ruido con atenuacion lineal: intensity = loudness * (1 - d/radius).
func can_hear(stimulus: Dictionary, observer_position: Variant, options: Dictionary = {}) -> Dictionary:
	var loudness: float = noise_value(stimulus, options)
	var radius: float = noise_radius(stimulus, options)
	var distance: float = _distance(observer_position, stimulus.get("position", stimulus.get("target", Vector2.ZERO)))
	var result: Dictionary = {
		"heard": false,
		"distance": distance,
		"loudness": loudness,
		"radius": radius,
		"intensity": 0.0,
		"reason": "",
	}
	if loudness <= 0.0 or radius <= 0.0:
		result["reason"] = "silent"
		return result
	if distance > radius:
		result["reason"] = "out_of_range"
		return result
	var attenuation: float = 1.0 - distance / radius
	var intensity: float = clampf(loudness * attenuation, 0.0, 1.0)
	result["intensity"] = intensity
	result["heard"] = intensity > 0.0
	result["reason"] = "heard" if result["heard"] else "silent"
	return result


# Disparo: sonido muy fuerte audible a mayor distancia (hasta 50m por defecto).
# Usa channel "gunshot" o kind "gunshot"/"disparo".
func can_hear_gunshot(stimulus: Dictionary, observer_position: Variant, options: Dictionary = {}) -> Dictionary:
	var base_loudness: float = 1.0
	var base_radius: float = float(options.get("gunshot_range", 50.0))
	var distance: float = _distance(observer_position, stimulus.get("position", stimulus.get("target", Vector2.ZERO)))
	var result: Dictionary = {
		"heard": false,
		"distance": distance,
		"loudness": base_loudness,
		"radius": base_radius,
		"intensity": 0.0,
		"reason": "",
	}
	if distance > base_radius:
		result["reason"] = "out_of_range"
		return result
	var attenuation: float = 1.0 - distance / base_radius
	var intensity: float = clampf(base_loudness * attenuation * 1.5, 0.0, 1.0)
	result["intensity"] = intensity
	result["heard"] = intensity > 0.0
	result["reason"] = "gunshot_heard" if result["heard"] else "out_of_range"
	return result


# Procesa una lista de estimulos: evalua, filtra relevantes, ordena por
# prioridad (desempate estable) y limita el numero por tick.
func perceive(stimuli: Array, observer_position: Variant, observer_facing: Variant, options: Dictionary = {}) -> Dictionary:
	var evaluated: Array = []
	for item in stimuli:
		if not (item is Dictionary):
			continue
		var entry: Dictionary = evaluate_stimulus(item, observer_position, observer_facing, options)
		if bool(entry["visible"]) or bool(entry["heard"]):
			evaluated.append(entry)
	var limit_value: int = int(options.get("max_stimuli_per_tick", max_stimuli_per_tick))
	evaluated.sort_custom(Callable(self, "_compare_stimuli"))
	var relevant_count: int = evaluated.size()
	if limit_value <= 0:
		evaluated.clear()
	elif evaluated.size() > limit_value:
		evaluated.resize(limit_value)
	_tick += 1
	return {
		"tick": _tick,
		"stimuli": evaluated,
		"count": evaluated.size(),
		"relevant": relevant_count,
		"dropped": relevant_count - evaluated.size(),
	}


# Adaptador: escribe los estimulos relevantes en NPCMemory usando add_event.
func write_to_memory(memory, perception_result: Dictionary) -> int:
	if memory == null or not memory.has_method("add_event"):
		return 0
	var written: int = 0
	var tick: int = int(perception_result.get("tick", _tick))
	for item in perception_result.get("stimuli", []):
		if not (item is Dictionary):
			continue
		var entry: Dictionary = item
		memory.add_event({
			"type": str(entry.get("kind", "perceived")),
			"kind": str(entry.get("channel", "vision")),
			"source_id": str(entry.get("source_id", entry.get("id", ""))),
			"channel": str(entry.get("channel", "vision")),
			"intensity": clampf(float(entry.get("intensity", 0.0)), 0.0, 1.0),
			"severity": clampf(float(entry.get("intensity", 0.0)), 0.0, 1.0),
			"position": entry.get("position", Vector2.ZERO),
			"distance": float(entry.get("distance", 0.0)),
			"priority": float(entry.get("priority", 0.0)),
			"tick": tick,
		})
		written += 1
	return written


func _compare_stimuli(a: Dictionary, b: Dictionary) -> bool:
	var priority_a: float = float(a.get("priority", 0.0))
	var priority_b: float = float(b.get("priority", 0.0))
	if not is_equal_approx(priority_a, priority_b):
		return priority_a > priority_b
	var intensity_a: float = float(a.get("intensity", 0.0))
	var intensity_b: float = float(b.get("intensity", 0.0))
	if not is_equal_approx(intensity_a, intensity_b):
		return intensity_a > intensity_b
	var id_a: String = str(a.get("id", a.get("source_id", "")))
	var id_b: String = str(b.get("id", b.get("source_id", "")))
	if id_a != id_b:
		return id_a < id_b
	var kind_a: String = str(a.get("kind", "")) + str(a.get("channel", ""))
	var kind_b: String = str(b.get("kind", "")) + str(b.get("channel", ""))
	return kind_a < kind_b


func _has_line_of_sight(from_value: Variant, to_value: Variant, options: Dictionary) -> bool:
	var callback: Callable = line_of_sight
	if options.has("line_of_sight") and options["line_of_sight"] is Callable:
		callback = options["line_of_sight"] as Callable
	if not callback.is_valid():
		return true
	if callback.get_argument_count() == 2:
		return bool(callback.call(from_value, to_value))
	return bool(callback.call())


func noise_value(stimulus: Dictionary, options: Dictionary = {}) -> float:
	var raw: Variant = stimulus.get("noise", stimulus.get("loudness", stimulus.get("volume", stimulus.get("intensity", 0.0))))
	if raw is Dictionary:
		var nested: Dictionary = raw
		raw = nested.get("value", nested.get("intensity", 0.0))
	return clampf(float(raw), 0.0, float(options.get("max_loudness", 1.0)))


func noise_radius(stimulus: Dictionary, options: Dictionary = {}) -> float:
	var raw: Variant = stimulus.get("radius", stimulus.get("noise_radius", stimulus.get("noise_range", null)))
	if raw == null:
		return maxf(0.0, float(options.get("hearing_range", hearing_range)))
	return maxf(0.0, float(raw))


func _distance(from_value: Variant, to_value: Variant) -> float:
	return (_as_2d(to_value) - _as_2d(from_value)).length()


func _distance_attenuation(distance: float, range_value: float) -> float:
	if range_value <= 0.0:
		return 1.0 if distance <= TIE_EPSILON else 0.0
	return clampf(1.0 - distance / range_value, 0.0, 1.0)


func _as_2d(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Vector3:
		var vector: Vector3 = value
		return Vector2(vector.x, vector.z)
	if value is Vector2i:
		var vector_i: Vector2i = value
		return Vector2(vector_i)
	if value is Vector3i:
		var vector_i3: Vector3i = value
		return Vector2(vector_i3.x, vector_i3.z)
	if value is Dictionary:
		var entry: Dictionary = value
		var x_value: Variant = entry.get("x", entry.get("position", null))
		var y_value: Variant = entry.get("y", entry.get("z", null))
		if x_value is Vector2 or x_value is Vector3:
			return _as_2d(x_value)
		if x_value != null and y_value != null:
			return Vector2(float(x_value), float(y_value))
	return Vector2.ZERO
