class_name SfxBank
extends RefCounted

const CATEGORIES := ["sfx", "voices", "ambience", "music"]
const BUS_PREFIX := "G12_"
const REVERB_PREFIX := "G12_rev_"
const ENVIRONMENTS := ["exterior", "interior", "street"]
const DISTANCE_BUS := "G12_distance"
const ATTENUATION_INVERSE := 0
const ATTENUATION_DISABLED := 3
const SYNTH_PATH := "res://core/game/audio_synth.gd"
const SOUND_SPEED := 343.0
const MAX_DISTANCE_DELAY := 0.5
const CUTOFF_NEAR := 20000.0
const CUTOFF_FAR := 800.0
const CUTOFF_DISTANCE := 250.0
const LAYER_KEYS := ["shot", "body", "crack", "mechanism"]
const LAYER_GAINS := {"shot": 0.58, "body": 0.24, "crack": 0.10, "mechanism": 0.08}
const ENV_PARAMS := {
	"exterior": {"size": 8.0, "wet": 0.05, "predelay": 10.0},
	"interior": {"size": 26.0, "wet": 0.18, "predelay": 18.0},
	"street": {"size": 42.0, "wet": 0.14, "predelay": 34.0},
}
const WEAPON_LAYERS := {
	"pistol": {"shot": "bank:shot_pistol", "body": "bank:body_pistol", "crack": "bank:crack_rifle", "mechanism": "bank:reload_slide", "environment": "exterior"},
	"smg": {"shot": "bank:shot_smg", "body": "bank:body_smg", "crack": "bank:crack_rifle", "mechanism": "bank:reload_mag", "environment": "street"},
	"rifle": {"shot": "bank:shot_rifle", "body": "bank:body_rifle", "crack": "bank:crack_rifle", "mechanism": "bank:reload_bolt", "environment": "exterior"},
	"shotgun": {"shot": "user:shotgun:fire", "body": "bank:body_shotgun", "crack": "bank:crack_rifle", "mechanism": "user:shotgun:pump", "environment": "exterior"},
	"sniper": {"shot": "bank:shot_sniper", "body": "bank:body_sniper", "crack": "bank:crack_sniper", "mechanism": "bank:reload_bolt", "environment": "exterior"},
	"assault_rifle": {"shot": "user:assault_rifle:fire", "body": "bank:body_assault_rifle", "crack": "bank:crack_rifle", "mechanism": "bank:reload_mag", "environment": "street"},
}
const ALIASES := {"ak47": "assault_rifle", "ak-47": "assault_rifle", "escopeta": "shotgun"}

const Synth = preload("res://core/game/audio_synth.gd")
const Recorded = preload("res://core/game/recorded_sfx.gd")

static var _volumes: Dictionary = {"sfx": 1.0, "voices": 1.0, "ambience": 0.7, "music": 0.6}
static var _reverbs: Dictionary = {}
static var _environment_effects: Dictionary = {}
static var _distance_filter = null
static var _limiter = null


static func bus_name(category: String) -> String:
	var key := category if CATEGORIES.has(category) else "sfx"
	return BUS_PREFIX + key


static func ensure_buses() -> Dictionary:
	var result: Dictionary = {}
	for category in CATEGORIES:
		var name := bus_name(category)
		var index := AudioServer.get_bus_index(name)
		if index < 0:
			index = AudioServer.bus_count
			AudioServer.add_bus(index)
			AudioServer.set_bus_name(index, name)
			AudioServer.set_bus_send(index, "Master")
		AudioServer.set_bus_volume_linear(index, clampf(float(_volumes.get(category, 1.0)), 0.0, 1.0))
		result[category] = index
	ensure_environment_buses()
	ensure_distance_bus()
	ensure_master_limiter()
	return result


static func set_volume(category: String, linear: float) -> void:
	var key := category if CATEGORIES.has(category) else "sfx"
	_volumes[key] = clampf(linear, 0.0, 1.0)
	var index := AudioServer.get_bus_index(bus_name(key))
	if index >= 0:
		AudioServer.set_bus_volume_linear(index, float(_volumes[key]))


static func volume(category: String) -> float:
	var key := category if CATEGORIES.has(category) else "sfx"
	return clampf(float(_volumes.get(key, 1.0)), 0.0, 1.0)


static func set_room_size(size_m: float, category: String = "sfx") -> void:
	var key := category if CATEGORIES.has(category) else "sfx"
	ensure_buses()
	var index := AudioServer.get_bus_index(bus_name(key))
	if index < 0:
		return
	var effect: AudioEffectReverb = null
	if _reverbs.has(key) and is_instance_valid(_reverbs[key]):
		effect = _reverbs[key]
	else:
		for i in range(AudioServer.get_bus_effect_count(index)):
			var candidate := AudioServer.get_bus_effect(index, i)
			if candidate is AudioEffectReverb:
				effect = candidate
				break
		if effect == null:
			effect = AudioEffectReverb.new()
			AudioServer.add_bus_effect(index, effect, 0)
		_reverbs[key] = effect
	var size := clampf(size_m, 0.0, 120.0)
	var amount := clampf(size / 40.0, 0.0, 1.0)
	effect.room_size = amount
	effect.damping = clampf(0.35 + amount * 0.35, 0.0, 1.0)
	effect.spread = clampf(0.4 + amount * 0.2, 0.0, 1.0)
	effect.wet = 0.0 if size_m <= 0.0 else 0.04 + amount * 0.16
	effect.dry = 1.0 - effect.wet * 0.4
	effect.hipass = 220.0
	effect.predelay_msec = 12.0 + amount * 22.0
	effect.predelay_feedback = 0.1
	AudioServer.set_bus_effect_enabled(index, _effect_index(index, effect), size_m > 0.0)


static func configure_space(size_m: float, category: String = "sfx") -> Dictionary:
	set_room_size(size_m, category)
	var size := clampf(size_m, 0.0, 120.0)
	var amount := clampf(size / 40.0, 0.0, 1.0)
	return {"size": size, "room_size": amount, "wet": 0.0 if size_m <= 0.0 else 0.04 + amount * 0.16}


static func environment_bus(environment: String) -> String:
	var key := environment if ENVIRONMENTS.has(environment) else "exterior"
	return REVERB_PREFIX + key


static func ensure_environment_buses() -> Dictionary:
	var result: Dictionary = {}
	for environment in ENVIRONMENTS:
		var name := environment_bus(environment)
		var index := AudioServer.get_bus_index(name)
		if index < 0:
			index = AudioServer.bus_count
			AudioServer.add_bus(index)
			AudioServer.set_bus_name(index, name)
			AudioServer.set_bus_send(index, bus_name("sfx"))
		AudioServer.set_bus_volume_linear(index, 1.0)
		var effect: AudioEffectReverb = null
		if _environment_effects.has(environment) and is_instance_valid(_environment_effects[environment]):
			effect = _environment_effects[environment]
		else:
			for i in range(AudioServer.get_bus_effect_count(index)):
				var candidate := AudioServer.get_bus_effect(index, i)
				if candidate is AudioEffectReverb:
					effect = candidate
					break
			if effect == null:
				effect = AudioEffectReverb.new()
				AudioServer.add_bus_effect(index, effect, 0)
			_environment_effects[environment] = effect
		var params: Dictionary = ENV_PARAMS[environment]
		var amount := clampf(float(params["size"]) / 42.0, 0.0, 1.0)
		effect.room_size = amount
		effect.damping = clampf(0.3 + amount * 0.4, 0.0, 1.0)
		effect.spread = clampf(0.4 + amount * 0.25, 0.0, 1.0)
		effect.wet = clampf(float(params["wet"]), 0.0, 0.5)
		effect.dry = 1.0 - effect.wet * 0.4
		effect.hipass = 260.0
		effect.predelay_msec = clampf(float(params["predelay"]), 0.0, 120.0)
		effect.predelay_feedback = 0.15
		AudioServer.set_bus_effect_enabled(index, _effect_index(index, effect), true)
		result[environment] = index
	return result


static func configure_environment(environment: String) -> Dictionary:
	var key := environment if ENVIRONMENTS.has(environment) else "exterior"
	ensure_environment_buses()
	var params: Dictionary = ENV_PARAMS[key]
	return {
		"environment": key,
		"bus": environment_bus(key),
		"size": float(params["size"]),
		"wet": float(params["wet"]),
		"predelay_msec": float(params["predelay"]),
	}


static func ensure_distance_bus() -> int:
	var index := AudioServer.get_bus_index(DISTANCE_BUS)
	if index < 0:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, DISTANCE_BUS)
		AudioServer.set_bus_send(index, bus_name("sfx"))
	AudioServer.set_bus_volume_linear(index, 1.0)
	if _distance_filter != null and is_instance_valid(_distance_filter):
		return index
	for i in range(AudioServer.get_bus_effect_count(index)):
		var candidate := AudioServer.get_bus_effect(index, i)
		if candidate is AudioEffectLowPassFilter:
			_distance_filter = candidate
			break
	if _distance_filter == null:
		_distance_filter = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(index, _distance_filter, 0)
	_distance_filter.cutoff_hz = CUTOFF_NEAR
	AudioServer.set_bus_effect_enabled(index, _effect_index(index, _distance_filter), true)
	return index


static func cutoff_for_distance(distance_m: float) -> float:
	var t := clampf(maxf(distance_m, 0.0) / CUTOFF_DISTANCE, 0.0, 1.0)
	return clampf(lerpf(CUTOFF_NEAR, CUTOFF_FAR, t), CUTOFF_FAR, CUTOFF_NEAR)


static func set_distance(distance_m: float) -> float:
	ensure_distance_bus()
	var cutoff := cutoff_for_distance(distance_m)
	if _distance_filter != null and is_instance_valid(_distance_filter):
		_distance_filter.cutoff_hz = cutoff
	return cutoff


static func distance_filter_cutoff() -> float:
	ensure_distance_bus()
	if _distance_filter == null or not is_instance_valid(_distance_filter):
		return 0.0
	return float(_distance_filter.cutoff_hz)


static func delay_for_distance(distance_m: float) -> float:
	return clampf(maxf(distance_m, 0.0) / SOUND_SPEED, 0.0, MAX_DISTANCE_DELAY)


static func ensure_master_limiter() -> bool:
	var index := AudioServer.get_bus_index("Master")
	if index < 0:
		return false
	for i in range(AudioServer.get_bus_effect_count(index)):
		var effect := AudioServer.get_bus_effect(index, i)
		if effect is AudioEffectHardLimiter or effect is AudioEffectLimiter:
			_limiter = effect
			AudioServer.set_bus_effect_enabled(index, i, true)
			return true
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.5
	AudioServer.add_bus_effect(index, limiter, 0)
	_limiter = limiter
	return true


static func has_master_limiter() -> bool:
	var index := AudioServer.get_bus_index("Master")
	if index < 0:
		return false
	for i in range(AudioServer.get_bus_effect_count(index)):
		var effect := AudioServer.get_bus_effect(index, i)
		if effect is AudioEffectHardLimiter or effect is AudioEffectLimiter:
			return true
	return false


static func normalize_weapon(weapon_id: String) -> String:
	var id := Recorded.normalize_id(weapon_id)
	return ALIASES.get(id, id)


static func _stream_for_descriptor(descriptor: String) -> AudioStream:
	if descriptor.begins_with("bank:"):
		return Recorded.random_stream(descriptor.substr(5))
	if descriptor.begins_with("user:"):
		var parts := descriptor.split(":")
		if parts.size() >= 3:
			return Recorded.stream_for(parts[1], parts[2])
	return null


static func _peak_for_descriptor(descriptor: String) -> float:
	if descriptor.begins_with("bank:"):
		return Recorded.bank_peak(descriptor.substr(5))
	if descriptor.begins_with("user:"):
		var parts := descriptor.split(":")
		if parts.size() >= 3:
			var samples: Dictionary = Recorded.SAMPLES.get(parts[1], {})
			var path := str(samples.get(parts[2], ""))
			if not path.is_empty():
				var peak := Recorded.manifest_peak(path.get_file())
				return peak if peak > 0.0 else 0.92
	return 0.9


static func resolve_layers(weapon_id: String) -> Dictionary:
	var id := normalize_weapon(weapon_id)
	var spec: Dictionary = WEAPON_LAYERS.get(id, WEAPON_LAYERS["pistol"])
	var result: Dictionary = {"weapon": id, "environment": str(spec.get("environment", "exterior"))}
	for key in LAYER_KEYS:
		var descriptor := str(spec.get(key, ""))
		var stream := _stream_for_descriptor(descriptor)
		var peak := _peak_for_descriptor(descriptor)
		if stream == null:
			stream = Synth.shot(id) if key == "shot" or key == "body" or key == "crack" else Synth.reload_sfx(id)
			peak = 0.9
		result[key] = {
			"descriptor": descriptor,
			"stream": stream,
			"gain": float(LAYER_GAINS[key]),
			"peak": peak,
			"real": not descriptor.is_empty() and stream != null and not (stream is AudioStreamWAV),
		}
	return result


static func layers_for(weapon_id: String) -> Dictionary:
	return resolve_layers(weapon_id)


static func layer_peak_total(layers: Dictionary) -> float:
	var total := 0.0
	for key in LAYER_KEYS:
		var info: Dictionary = layers.get(key, {})
		total += float(LAYER_GAINS[key]) * float(info.get("peak", 0.0))
	return total


static func _play_layer_now(parent: Node, stream: AudioStream, position: Vector3, target_bus: String, volume_db: float) -> AudioStreamPlayer3D:
	var player := play_3d(parent as Node3D, stream, position, "sfx", {
		"bus": target_bus,
		"volume_db": volume_db,
		"max_distance": 160.0,
		"max_db": -6.0,
	})
	if player != null:
		player.pitch_scale = Recorded.pitch_variation()
	return player


static func _play_layer_delayed(parent: Node, stream: AudioStream, position: Vector3, target_bus: String, volume_db: float, wait: float, out: Dictionary, key: String) -> void:
	var timer := Timer.new()
	timer.name = "G12DelayedLayer"
	timer.one_shot = true
	timer.wait_time = maxf(wait, 0.001)
	parent.add_child(timer)
	timer.timeout.connect(_on_delayed_layer.bind(parent, stream, position, target_bus, volume_db, out, key), CONNECT_ONE_SHOT)
	timer.start()


static func _on_delayed_layer(parent: Node, stream: AudioStream, position: Vector3, target_bus: String, volume_db: float, out: Dictionary, key: String) -> void:
	out[key] = _play_layer_now(parent, stream, position, target_bus, volume_db)


static func play_layered(parent: Node3D, weapon_id: String, position: Vector3, context: Dictionary = {}) -> Dictionary:
	ensure_buses()
	var layers := resolve_layers(weapon_id)
	var environment := str(layers.get("environment", "exterior"))
	var distance := float(context.get("distance", 0.0))
	var delay := delay_for_distance(distance)
	set_distance(distance)
	var players: Dictionary = {}
	for key in LAYER_KEYS:
		var info: Dictionary = layers[key]
		var stream: AudioStream = info["stream"]
		if stream == null:
			continue
		var target_bus := bus_name("sfx")
		if key == "body" or key == "crack":
			target_bus = environment_bus(environment)
		elif key == "mechanism":
			target_bus = DISTANCE_BUS
		var volume_db := linear_to_db(float(info["gain"])) + clampf(float(context.get("volume_db", 0.0)), -24.0, 12.0)
		var wait := delay + (0.05 if key == "mechanism" else 0.0)
		if wait > 0.001:
			_play_layer_delayed(parent, stream, position, target_bus, volume_db, wait, players, key)
		else:
			players[key] = _play_layer_now(parent, stream, position, target_bus, volume_db)
	return players


static func play_2d(parent: Node, audio: AudioStream, category: String = "sfx", volume_db: float = 0.0, loop: bool = false) -> AudioStreamPlayer:
	if parent == null or audio == null:
		return null
	ensure_buses()
	var player := AudioStreamPlayer.new()
	player.name = "G12Audio2D"
	player.stream = audio
	player.bus = bus_name(category)
	player.volume_db = clampf(volume_db, -60.0, 24.0)
	if loop and audio is AudioStreamWAV:
		(audio as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	parent.add_child(player)
	player.play()
	return player


static func play_3d(parent: Node3D, audio: AudioStream, position: Vector3, category: String = "sfx", options: Dictionary = {}) -> AudioStreamPlayer3D:
	if parent == null or audio == null:
		return null
	ensure_buses()
	var player := AudioStreamPlayer3D.new()
	player.name = "G12Audio3D"
	player.stream = audio
	player.bus = str(options.get("bus", bus_name(category)))
	player.position = position
	player.attenuation_model = int(options.get("attenuation", ATTENUATION_INVERSE))
	player.max_distance = clampf(float(options.get("max_distance", 60.0)), 1.0, 500.0)
	player.max_db = clampf(float(options.get("max_db", -12.0)), -60.0, 24.0)
	player.panning_strength = clampf(float(options.get("panning", 1.0)), 0.0, 2.0)
	player.volume_db = clampf(float(options.get("volume_db", 0.0)), -60.0, 24.0)
	parent.add_child(player)
	player.play()
	return player


static func play_synth(parent: Node3D, kind: String, variant: String, position: Vector3, category: String = "sfx", a_seed: int = -1) -> AudioStreamPlayer3D:
	var audio := Synth.stream(kind, variant, a_seed)
	return play_3d(parent, audio, position, category)


static func reset() -> void:
	_reverbs.clear()
	_environment_effects.clear()
	_distance_filter = null
	_limiter = null
	for category in CATEGORIES:
		_volumes[category] = 1.0 if category == "sfx" or category == "voices" else (0.7 if category == "ambience" else 0.6)
	ensure_buses()


static func _effect_index(bus_index: int, effect: AudioEffect) -> int:
	for i in range(AudioServer.get_bus_effect_count(bus_index)):
		if AudioServer.get_bus_effect(bus_index, i) == effect:
			return i
	return 0
