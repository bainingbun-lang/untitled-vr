class_name SfxBank
extends RefCounted

const CATEGORIES := ["sfx", "voices", "ambience", "music"]
const BUS_PREFIX := "G12_"
const ATTENUATION_INVERSE := 0
const ATTENUATION_DISABLED := 3
const SYNTH_PATH := "res://core/game/audio_synth.gd"

const Synth = preload("res://core/game/audio_synth.gd")

static var _volumes: Dictionary = {"sfx": 1.0, "voices": 1.0, "ambience": 0.7, "music": 0.6}
static var _reverbs: Dictionary = {}


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
	player.bus = bus_name(category)
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
	for category in CATEGORIES:
		_volumes[category] = 1.0 if category == "sfx" or category == "voices" else (0.7 if category == "ambience" else 0.6)
	ensure_buses()


static func _effect_index(bus_index: int, effect: AudioEffect) -> int:
	for i in range(AudioServer.get_bus_effect_count(bus_index)):
		if AudioServer.get_bus_effect(bus_index, i) == effect:
			return i
	return 0
