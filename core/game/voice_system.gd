class_name VoiceSystem
extends Node

signal subtitle(text: String, npc: String)

const MAX_VOICES := 4
const VOICE_CACHE_LIMIT_BYTES := 1536 * 1024
const AudioSynthScript = preload("res://core/game/audio_synth.gd")
const SfxBankScript = preload("res://core/game/sfx_bank.gd")
const Recorded = preload("res://core/game/recorded_sfx.gd")

const CUES := {
	"fear": {"text": "¡Aaaaah!", "duration": 0.9, "noise": 0.32, "jitter": 0.055},
	"pain": {"text": "¡Aay!, ¡duele!", "duration": 0.65, "noise": 0.24, "jitter": 0.04},
	"effort": {"text": "¡Hff!", "duration": 0.35, "noise": 0.22, "jitter": 0.03},
	"pant": {"text": "Jadeos", "duration": 0.75, "noise": 0.55, "jitter": 0.02},
	"cough": {"text": "Tos", "duration": 0.5, "noise": 0.48, "jitter": 0.04},
	"cry": {"text": "Llanto", "duration": 1.1, "noise": 0.3, "jitter": 0.07},
	"hey": {"text": "¡Eh!", "duration": 0.3, "noise": 0.18, "jitter": 0.03},
	"laugh": {"text": "Risa", "duration": 0.85, "noise": 0.28, "jitter": 0.06},
	"death": {"text": "¡Gorgoteo!", "duration": 1.3, "noise": 0.62, "jitter": 0.12},
	"phrase": {"text": "", "duration": 0.6, "noise": 0.2, "jitter": 0.02},
}

const PHRASES := {
	"alert": "¡Alerta!",
	"halt": "¡Alto!",
	"help": "¡Ayuda!",
	"surrender": "Me rindo",
	"shots": "¡Disparos!",
	"cover": "¡Cúbrete!",
	"reloading": "Recargando",
}

const VOICE_BANKS := {
	"fear": {"male": "voice_fear_male", "female": "voice_fear_female"},
	"pain": {"male": "voice_pain_male", "female": "voice_pain_female"},
	"effort": {"male": "voice_effort_male", "female": "voice_effort_female"},
	"pant": {"male": "voice_pant", "female": "voice_pant"},
	"cough": {"male": "voice_cough", "female": "voice_cough"},
	"cry": {"male": "voice_cry", "female": "voice_cry"},
	"hey": {"male": "voice_alert", "female": "voice_alert"},
	"laugh": {"male": "voice_laugh", "female": "voice_laugh"},
	"death": {"male": "voice_death_male", "female": "voice_death_female"},
	"phrase": {"male": "voice_phrase", "female": "voice_phrase"},
}

static var tts_voices_override = null
static var tts_speak_hook: Callable = Callable()
static var tts_calls: Array = []
static var tts_prefer := false
static var _tts_counter := 0

var subtitles_enabled := false
var tts_enabled := false
var cooldown := 0.45
var _now := 0.0
var _active: Array = []
var _profiles: Dictionary = {}
var _last_at: Dictionary = {}
var _selection_count: Dictionary = {}
var _voice_variant_count: Dictionary = {}
var _voice_cache: Dictionary = {}
var _voice_lru: Array = []
var _voice_bytes := 0
var _dropped := 0
var _subtitle_count := 0
var _last_subtitle := ""


func _ready() -> void:
	SfxBankScript.ensure_buses()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	_now += maxf(delta, 0.0)
	_retire_finished()


func reset() -> void:
	for item in _active:
		var player = item.get("player", null)
		if player != null and is_instance_valid(player) and not (player as Node).is_queued_for_deletion():
			(player as Node).queue_free()
	_active.clear()
	_profiles.clear()
	_last_at.clear()
	_selection_count.clear()
	_voice_variant_count.clear()
	_dropped = 0
	_subtitle_count = 0
	_last_subtitle = ""
	_now = 0.0
	clear_voice_cache()


func clear_voice_cache() -> void:
	_voice_cache.clear()
	_voice_lru.clear()
	_voice_bytes = 0


func voice_cache_bytes() -> int:
	return _voice_bytes


func cached_voice_count() -> int:
	return _voice_cache.size()


func active_count() -> int:
	_retire_finished()
	return _active.size()


func dropped_count() -> int:
	return _dropped


func subtitle_count() -> int:
	return _subtitle_count


func last_subtitle() -> String:
	return _last_subtitle


func set_cooldown(seconds: float) -> void:
	cooldown = clampf(seconds, 0.0, 30.0)


func register_npc(npc_id: String, options: Dictionary = {}) -> void:
	var profile := _derive_profile(npc_id)
	for key in options.keys():
		var value = options[key]
		if key == "gender" and typeof(value) == TYPE_STRING:
			var text := str(value).to_lower()
			value = 0.8 if text == "female" or text == "mujer" or text == "woman" else 0.2
		profile[key] = value
	profile["pitch"] = clampf(float(profile.get("pitch", 1.0)), 0.5, 2.0)
	profile["timbre"] = clampf(float(profile.get("timbre", 1.0)), 0.5, 2.0)
	profile["gender"] = clampf(float(profile.get("gender", 0.5)), 0.0, 1.0)
	profile["age"] = clampf(float(profile.get("age", 0.5)), 0.0, 1.0)
	profile["mood"] = clampf(float(profile.get("mood", 0.5)), 0.0, 1.0)
	profile["fear"] = clampf(float(profile.get("fear", 0.2)), 0.0, 1.0)
	profile["bravery"] = clampf(float(profile.get("bravery", 0.5)), 0.0, 1.0)
	profile["relation"] = clampf(float(profile.get("relation", 0.0)), -1.0, 1.0)
	profile["health"] = clampf(float(profile.get("health", 100.0)), 0.0, 100.0)
	profile["volume"] = clampf(float(profile.get("volume", 1.0)), 0.0, 1.0)
	_profiles[npc_id] = profile


func set_npc_state(npc_id: String, state: Dictionary) -> void:
	var profile := _profile(npc_id)
	for key in state.keys():
		profile[key] = state[key]
	profile["health"] = clampf(float(profile.get("health", 100.0)), 0.0, 100.0)
	profile["fear"] = clampf(float(profile.get("fear", 0.2)), 0.0, 1.0)
	profile["mood"] = clampf(float(profile.get("mood", 0.5)), 0.0, 1.0)
	profile["relation"] = clampf(float(profile.get("relation", 0.0)), -1.0, 1.0)
	_profiles[npc_id] = profile


func profile_for(npc_id: String) -> Dictionary:
	return _profile(npc_id).duplicate()


func voice_stream(npc_id: String, cue: String, profile: Dictionary = {}, variant_round: int = 0) -> AudioStream:
	var p: Dictionary = profile if not profile.is_empty() else _profile(npc_id)
	var cue_id := cue if CUES.has(cue) else "effort"
	var bank := voice_bank_for(cue_id, p)
	var count := Recorded.variant_count(bank) if Recorded.has_bank(bank) else 0
	var round_index := maxi(variant_round, 0)
	var index := 0
	var file_name := ""
	if count > 0:
		var seed_value := int(p.get("seed", 1)) + cue_id.hash() + round_index * 7919
		index = Recorded.variant_index(bank, seed_value)
		file_name = str((Recorded.bank_files(bank) as Array)[index])
	var key := "%s|%s|%s|%d|%d" % [npc_id, cue_id, bank, round_index, index]
	if _voice_cache.has(key):
		_voice_lru.erase(key)
		_voice_lru.append(key)
		return (_voice_cache[key] as Dictionary)["stream"]
	var audio: AudioStream = null
	var bytes := 0
	if count > 0:
		var path := Recorded.REAL_DIR + file_name
		audio = Recorded.stream_at(bank, index)
		if audio != null:
			bytes = int(FileAccess.get_size(path)) if FileAccess.file_exists(path) else 16384
	if audio == null:
		var samples := _synth_voice(p, cue_id)
		audio = AudioSynthScript.wav_from_samples(samples)
		bytes = (audio as AudioStreamWAV).data.size()
	audio.resource_name = key
	_voice_cache[key] = {"stream": audio, "bytes": bytes}
	_voice_lru.append(key)
	_voice_bytes += bytes
	while _voice_bytes > VOICE_CACHE_LIMIT_BYTES and not _voice_lru.is_empty():
		var old_key: String = str(_voice_lru.pop_front())
		var old: Dictionary = _voice_cache.get(old_key, {})
		if old.is_empty():
			continue
		_voice_bytes -= int(old.get("bytes", 0))
		_voice_cache.erase(old_key)
	return audio


func voice_bank_for(cue: String, profile: Dictionary = {}) -> String:
	var cue_id := cue if VOICE_BANKS.has(cue) else "effort"
	var mapping: Dictionary = VOICE_BANKS[cue_id]
	var gender := clampf(float(profile.get("gender", 0.5)), 0.0, 1.0)
	var key := "female" if gender >= 0.5 else "male"
	return str(mapping.get(key, mapping.get("male", "")))


func voice_variant_count(cue: String, profile: Dictionary = {}) -> int:
	return Recorded.variant_count(voice_bank_for(cue, profile))


func display_name_for(npc_id: String) -> String:
	var relation := clampf(float(_profile(npc_id).get("relation", 0.0)), -1.0, 1.0)
	if relation > 0.2:
		return "Aliado"
	if relation < -0.2:
		return "Enemigo"
	return "NPC"


func set_subtitles_enabled(value: bool) -> void:
	subtitles_enabled = value


func set_tts_enabled(value: bool) -> void:
	tts_enabled = value


func can_play(npc_id: String) -> bool:
	_retire_finished()
	var last := float(_last_at.get(npc_id, -1000.0))
	return _now - last >= cooldown


func play_cue(npc_id: String, cue: String, context: Dictionary = {}) -> bool:
	if not CUES.has(cue):
		return false
	var profile := _profile(npc_id)
	if not _begin(npc_id):
		return false
	var text := str((CUES[cue] as Dictionary).get("text", cue))
	_emit_subtitle(text, npc_id)
	if _active.size() >= MAX_VOICES:
		_dropped += 1
		return false
	var audio := voice_stream(npc_id, cue, profile, _next_variant(npc_id, cue))
	_spawn_player(npc_id, cue, audio, profile, context)
	return true


func speak_phrase(npc_id: String, phrase_id: String, context: Dictionary = {}) -> bool:
	if not PHRASES.has(phrase_id):
		return false
	var profile := _profile(npc_id)
	if not _begin(npc_id):
		return false
	var text := str(PHRASES[phrase_id])
	_emit_subtitle(text, npc_id)
	if _active.size() >= MAX_VOICES:
		_dropped += 1
		return false
	if (tts_prefer or not Recorded.has_bank("voice_phrase")) and _speak_tts(text, npc_id, profile):
		_active.append({"npc": npc_id, "cue": "phrase", "end_at": _now + 0.9, "player": null})
		return true
	var audio := voice_stream(npc_id, "phrase", profile, _next_variant(npc_id, "phrase"))
	_spawn_player(npc_id, "phrase", audio, profile, context)
	return true


func select_cue(npc_id: String, context: Dictionary = {}) -> String:
	var p := _profile(npc_id)
	var health := clampf(float(context.get("health", p.get("health", 100.0))), 0.0, 100.0)
	var fear := clampf(float(context.get("fear", p.get("fear", 0.2))), 0.0, 1.0)
	var bravery := clampf(float(context.get("bravery", p.get("bravery", 0.5))), 0.0, 1.0)
	var relation := clampf(float(context.get("relation", p.get("relation", 0.0))), -1.0, 1.0)
	var mood := clampf(float(context.get("mood", p.get("mood", 0.5))), 0.0, 1.0)
	var index := int(_selection_count.get(npc_id, 0))
	_selection_count[npc_id] = index + 1
	var rng := _rng(int(p.get("seed", 1)) + index * 7919)
	if health <= 0.0:
		return "death"
	if health < 20.0:
		return "pant" if rng.randf() < 0.5 else "pain"
	if fear > 0.65 and bravery < 0.7:
		return "fear" if rng.randf() < 0.75 else "hey"
	if bool(context.get("under_fire", false)):
		return "fear"
	if bool(context.get("hurt", false)):
		return "pain"
	if bool(context.get("attacking", false)) or bool(context.get("effort", false)):
		return "effort"
	if health < 45.0 and rng.randf() < 0.35:
		return "cough"
	if mood < 0.25:
		return "cry"
	if mood > 0.8 and relation > 0.0:
		return "laugh"
	if relation < -0.2 and fear > 0.35:
		return "hey"
	return "effort" if rng.randf() < 0.4 else "hey"


func select_phrase(npc_id: String, context: Dictionary = {}) -> String:
	var p := _profile(npc_id)
	var health := clampf(float(context.get("health", p.get("health", 100.0))), 0.0, 100.0)
	var fear := clampf(float(context.get("fear", p.get("fear", 0.2))), 0.0, 1.0)
	var relation := clampf(float(context.get("relation", p.get("relation", 0.0))), -1.0, 1.0)
	if health <= 0.0:
		return ""
	if health < 25.0:
		return "surrender" if relation > 0.2 else "help"
	if fear > 0.7:
		return "shots" if bool(context.get("under_fire", false)) else "cover"
	if bool(context.get("enemy_seen", false)):
		return "halt"
	if bool(context.get("reloading", false)):
		return "reloading"
	return "alert"


func react(npc_id: String, context: Dictionary = {}) -> String:
	var cue := select_cue(npc_id, context)
	play_cue(npc_id, cue, context)
	return cue


func react_phrase(npc_id: String, context: Dictionary = {}) -> String:
	var phrase := select_phrase(npc_id, context)
	if phrase.is_empty():
		return phrase
	speak_phrase(npc_id, phrase, context)
	return phrase


static func tts_available() -> bool:
	if tts_voices_override != null and tts_voices_override is Array:
		return not (tts_voices_override as Array).is_empty()
	if not DisplayServer.has_method("tts_get_voices"):
		return false
	var voices = DisplayServer.call("tts_get_voices")
	if voices == null:
		return false
	return voices.size() > 0


static func tts_diagnostic() -> Dictionary:
	return {"available": tts_available(), "calls": tts_calls.size()}


static func reset_tts_test_hooks() -> void:
	tts_voices_override = null
	tts_speak_hook = Callable()
	tts_calls.clear()
	tts_prefer = false
	_tts_counter = 0


func _next_variant(npc_id: String, cue: String) -> int:
	var slot := npc_id + "|" + cue
	var value := int(_voice_variant_count.get(slot, 0))
	_voice_variant_count[slot] = value + 1
	return value


func _begin(npc_id: String) -> bool:
	_retire_finished()
	var last := float(_last_at.get(npc_id, -1000.0))
	if _now - last < cooldown:
		return false
	_last_at[npc_id] = _now
	return true


func _emit_subtitle(text: String, npc_id: String) -> void:
	if not subtitles_enabled:
		return
	_last_subtitle = text
	_subtitle_count += 1
	subtitle.emit(text, display_name_for(npc_id))


func _retire_finished() -> void:
	for i in range(_active.size() - 1, -1, -1):
		var item: Dictionary = _active[i]
		if float(item.get("end_at", 0.0)) > _now:
			continue
		var player = item.get("player", null)
		if player != null and is_instance_valid(player) and not (player as Node).is_queued_for_deletion():
			(player as Node).queue_free()
		_active.remove_at(i)


func _spawn_player(npc_id: String, cue: String, audio: AudioStream, profile: Dictionary, context: Dictionary) -> void:
	var player = null
	var position = context.get("position", null)
	var parent := get_parent()
	if position is Vector3 and parent is Node3D:
		player = SfxBankScript.play_3d(parent, audio, position, "voices", {
			"max_distance": float(context.get("max_distance", 45.0)),
			"volume_db": float(profile.get("volume", 1.0)) - 1.0,
		})
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = "G12Voice"
		player.stream = audio
		player.bus = SfxBankScript.bus_name("voices")
		player.volume_db = clampf((float(profile.get("volume", 1.0)) - 1.0) * 12.0 + float(context.get("volume_db", 0.0)), -40.0, 12.0)
		add_child(player)
		player.play()
	_active.append({"npc": npc_id, "cue": cue, "end_at": _now + audio.get_length(), "player": player})


func _profile(npc_id: String) -> Dictionary:
	if not _profiles.has(npc_id):
		register_npc(npc_id)
	return _profiles[npc_id]


func _derive_profile(npc_id: String) -> Dictionary:
	var seed_value := _hash_text(npc_id)
	var rng := _rng(seed_value)
	return {
		"seed": seed_value,
		"pitch": rng.randf_range(0.82, 1.24),
		"timbre": rng.randf_range(0.8, 1.25),
		"gender": rng.randf_range(0.0, 1.0),
		"age": rng.randf_range(0.0, 1.0),
		"mood": rng.randf_range(0.2, 0.9),
		"fear": rng.randf_range(0.0, 0.4),
		"bravery": rng.randf_range(0.2, 0.9),
		"relation": 0.0,
		"health": 100.0,
		"volume": 1.0,
	}


func _speak_tts(text: String, npc_id: String, profile: Dictionary) -> bool:
	if not (subtitles_enabled or tts_enabled):
		return false
	if not tts_available():
		return false
	var argc := _tts_arg_count()
	var voice_name := _tts_voice_name()
	var rate := clampf(0.85 + (1.0 - float(profile.get("age", 0.5))) * 0.2 + float(profile.get("mood", 0.5)) * 0.1, 0.6, 1.6)
	var pitch := clampf(float(profile.get("pitch", 1.0)) * (1.0 + (float(profile.get("gender", 0.5)) - 0.5) * 0.08), 0.5, 2.0)
	var volume := clampf(float(profile.get("volume", 1.0)), 0.0, 1.0)
	var utterance := _next_tts_id()
	var args: Array = []
	if argc >= 7:
		args = [text, voice_name, volume, pitch, rate, utterance, true]
	elif argc >= 6:
		args = [text, voice_name, volume, pitch, rate, utterance]
	elif argc >= 5:
		args = [text, voice_name, rate, pitch, volume]
	else:
		args = [text]
	tts_calls.append({"npc": npc_id, "text": text, "args": args})
	if tts_speak_hook.is_valid():
		tts_speak_hook.callv(args)
	else:
		DisplayServer.callv("tts_speak", args)
	return true


static func _tts_arg_count() -> int:
	if not DisplayServer.has_method("tts_speak"):
		return 0
	for method in DisplayServer.get_method_list():
		if str(method.name) == "tts_speak":
			return int((method.args as Array).size())
	return 0


static func _tts_voice_name() -> String:
	var voices = tts_voices_override
	if voices == null and DisplayServer.has_method("tts_get_voices"):
		voices = DisplayServer.call("tts_get_voices")
	if voices == null or voices.size() == 0:
		return ""
	var first = voices[0]
	if typeof(first) == TYPE_STRING:
		return str(first)
	if first is Dictionary:
		return str((first as Dictionary).get("name", ""))
	return str(first)


static func _next_tts_id() -> int:
	_tts_counter += 1
	return _tts_counter


func _synth_voice(profile: Dictionary, cue: String) -> PackedFloat32Array:
	var def: Dictionary = CUES[cue]
	var duration := clampf(float(def.get("duration", 0.6)), 0.05, AudioSynthScript.MAX_SECONDS - 0.2)
	var count := int(duration * float(AudioSynthScript.RATE))
	var seed_value := int(profile.get("seed", 1)) + cue.hash()
	var rng := _rng(seed_value)
	var age := clampf(float(profile.get("age", 0.5)), 0.0, 1.0)
	var gender := clampf(float(profile.get("gender", 0.5)), 0.0, 1.0)
	var mood := clampf(float(profile.get("mood", 0.5)), 0.0, 1.0)
	var age_pitch := 1.22 if age < 0.22 else (0.9 if age > 0.8 else 1.0)
	var base_f0 := lerpf(96.0, 205.0, gender) * clampf(float(profile.get("pitch", 1.0)), 0.5, 2.0) * age_pitch
	base_f0 *= 0.92 + mood * 0.16
	base_f0 = clampf(base_f0, 55.0, 480.0)
	var timbre := clampf(float(profile.get("timbre", 1.0)), 0.5, 2.0)
	var noise_mix := clampf(float(def.get("noise", 0.25)) * (0.85 + age * 0.4), 0.0, 0.85)
	var jitter := float(def.get("jitter", 0.03))
	var vowel_a := [800.0 * timbre, 1200.0 * timbre, 2800.0 * timbre]
	var vowel_e := [350.0 * timbre, 2200.0 * timbre, 3000.0 * timbre]
	var vowel_o := [500.0 * timbre, 900.0 * timbre, 2500.0 * timbre]
	var targets := [vowel_a, vowel_e, vowel_o]
	var current := [vowel_a[0], vowel_a[1], vowel_a[2]]
	var coeff_a := [0.0, 0.0, 0.0]
	var coeff_b := [0.0, 0.0, 0.0]
	var coeff_c := [0.0, 0.0, 0.0]
	var y1 := [0.0, 0.0, 0.0]
	var y2 := [0.0, 0.0, 0.0]
	var weights := [1.0, 0.6, 0.32]
	var bandwidths := [110.0, 170.0, 240.0]
	var phase := 0.0
	var out := PackedFloat32Array()
	out.resize(count)
	for i in range(count):
		var t := float(i) / float(AudioSynthScript.RATE)
		var progress := clampf(t / duration, 0.0, 1.0)
		var vowel_index := 0
		match cue:
			"hey":
				vowel_index = 1
			"death":
				vowel_index = 2
			"laugh":
				vowel_index = int(floor(t / 0.19)) % 3
			"cry":
				vowel_index = 1 if sin(TAU * 3.0 * t) > 0.0 else 0
			"pant", "cough":
				vowel_index = 2
			_:
				vowel_index = int(floor(t / 0.22)) % 3
		for j in range(3):
			current[j] = lerpf(current[j], float(targets[vowel_index][j]), 0.045)
		if i % 8 == 0:
			for j in range(3):
				var radius: float = exp(-PI * float(bandwidths[j]) / float(AudioSynthScript.RATE))
				coeff_a[j] = 1.0 - radius
				coeff_b[j] = 2.0 * radius * cos(TAU * float(current[j]) / float(AudioSynthScript.RATE))
				coeff_c[j] = radius * radius
		var contour := 1.0
		if cue == "hey" or cue == "fear":
			contour = 1.0 + 0.28 * sin(PI * progress)
		elif cue == "death":
			contour = 1.0 - 0.45 * progress
		var f0 := base_f0 * contour * (1.0 + jitter * rng.randf_range(-1.0, 1.0))
		phase += f0 / float(AudioSynthScript.RATE)
		if phase >= 1.0:
			phase -= 1.0
		var voiced := sin(TAU * phase) * 0.6 + sin(TAU * phase * 2.0) * 0.25 + sin(TAU * phase * 3.0) * 0.15
		var breath := rng.randf_range(-1.0, 1.0)
		var source := voiced * (1.0 - noise_mix) + breath * noise_mix
		var resonant := 0.0
		for j in range(3):
			var y: float = float(coeff_a[j]) * source + float(coeff_b[j]) * float(y1[j]) - float(coeff_c[j]) * float(y2[j])
			y2[j] = y1[j]
			y1[j] = y
			resonant += y * weights[j]
		out[i] = resonant * _cue_envelope(cue, t, duration, rng)
	_normalize_samples(out, 0.82)
	_fade_samples(out)
	return out


func _cue_envelope(cue: String, t: float, duration: float, rng: RandomNumberGenerator) -> float:
	var attack := clampf(t / 0.035, 0.0, 1.0)
	var tail := 1.0 - clampf((t - duration * 0.8) / maxf(duration * 0.2, 0.01), 0.0, 1.0)
	match cue:
		"fear", "pain":
			return attack * (0.6 + 0.4 * tail)
		"effort":
			return attack * exp(-t * 4.5)
		"pant":
			return attack * pow(maxf(0.0, sin(TAU * 2.6 * t)), 2.0)
		"cough":
			var dx1 := (t - 0.08) / 0.045
			var dx2 := (t - 0.28) / 0.06
			return attack * (exp(-dx1 * dx1) + 0.7 * exp(-dx2 * dx2))
		"cry":
			return attack * tail * (0.72 + 0.28 * sin(TAU * 5.0 * t))
		"hey":
			return attack * exp(-t * 7.0)
		"laugh":
			return attack * pow(maxf(0.0, sin(TAU * 4.2 * t)), 1.4) * tail
		"death":
			var rattle := 0.55 + 0.45 * sin(TAU * 1.7 * t)
			if rng.randf() < 0.008:
				rattle += 0.8
			return attack * (1.0 - 0.75 * clampf(t / duration, 0.0, 1.0)) * rattle
		_:
			return attack * pow(maxf(0.0, sin(TAU * 3.2 * t)), 1.2) * tail


func _normalize_samples(out: PackedFloat32Array, peak: float) -> void:
	var maximum := 0.0
	for i in range(out.size()):
		maximum = maxf(maximum, absf(out[i]))
	if maximum <= 0.00001:
		return
	var scale := peak / maximum
	for i in range(out.size()):
		out[i] = clampf(out[i] * scale, -1.0, 1.0)


func _fade_samples(out: PackedFloat32Array) -> void:
	var edge := clampi(out.size() / 12, 32, 256)
	for i in range(edge):
		var factor := float(i) / float(edge)
		out[i] *= factor
		out[out.size() - 1 - i] *= factor


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _hash_text(text: String) -> int:
	var value := text.hash()
	if value < 0:
		value = -value
	return value % 2147483646 + 1
