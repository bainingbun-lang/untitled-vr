extends SceneTree

const AudioSynthScript = preload("res://core/game/audio_synth.gd")
const VoiceSystemScript = preload("res://core/game/voice_system.gd")
const SfxBankScript = preload("res://core/game/sfx_bank.gd")

var _failures: Array = []
var _checks := 0
var _case := ""
var _root: Node3D = null
var _voice = null
var _subtitles: Array = []
var _tts_record: Array = []

const NONVERBAL_CUES := ["fear", "pain", "effort", "pant", "cough", "cry", "hey", "laugh", "death"]
const SURFACES := ["metal", "wood", "concrete", "flesh", "glass", "water"]
const WEAPONS := ["pistol", "smg", "rifle", "shotgun", "sniper"]


func _initialize() -> void:
	_root = Node3D.new()
	root.add_child(_root)
	_voice = VoiceSystemScript.new()
	_voice.set_process(false)
	_voice.set_cooldown(0.0)
	_voice.subtitle.connect(_on_subtitle)
	_root.add_child(_voice)
	VoiceSystemScript.reset_tts_test_hooks()
	AudioSynthScript.clear_cache()
	AudioSynthScript.set_seed(12345)
	await process_frame
	await process_frame

	_case = "streams PCM generados por codigo"
	for weapon in WEAPONS:
		var audio := AudioSynthScript.shot(weapon)
		_check_stream(audio, "disparo %s" % weapon)
	_expect(AudioSynthScript.shot("sniper").get_length() > AudioSynthScript.shot("pistol").get_length(), "francotirador con cola mas larga")
	_expect(_tail_energy(AudioSynthScript.shot("sniper")) > 0.005, "francotirador con eco al final")
	_check_stream(AudioSynthScript.reload_sfx("pistol"), "recarga metalica")
	_check_stream(AudioSynthScript.reload_sfx("rifle"), "recarga de rifle")
	for surface in SURFACES:
		_check_stream(AudioSynthScript.impact(surface), "impacto %s" % surface)
		_check_stream(AudioSynthScript.footstep(surface), "paso %s" % surface)
	for size in ["small", "medium", "large"]:
		_check_stream(AudioSynthScript.explosion(size), "explosion %s" % size)
	for rpm in [800.0, 2200.0, 6500.0]:
		_check_stream(AudioSynthScript.engine(rpm), "motor %d rpm" % int(rpm))
	for place in AudioSynthScript.AMBIENCES:
		var ambient := AudioSynthScript.ambience(place)
		_check_stream(ambient, "ambiente %s" % place)
		_expect_eq(ambient.loop_mode, AudioStreamWAV.LOOP_FORWARD, "ambiente %s en bucle" % place)
	_expect(not _bytes_equal(AudioSynthScript.engine(800.0).data, AudioSynthScript.engine(3000.0).data), "motor cambia segun rpm")
	_expect(not _bytes_equal(AudioSynthScript.impact("metal").data, AudioSynthScript.impact("water").data), "impactos distintos por superficie")

	_case = "determinismo por semilla y cache"
	AudioSynthScript.set_seed(777)
	var first_shot := AudioSynthScript.shot("rifle")
	AudioSynthScript.set_seed(777)
	var same_shot := AudioSynthScript.shot("rifle")
	AudioSynthScript.set_seed(778)
	var other_shot := AudioSynthScript.shot("rifle")
	_expect(_bytes_equal(first_shot.data, same_shot.data), "misma semilla produce la misma onda")
	_expect(not _bytes_equal(first_shot.data, other_shot.data), "semilla distinta cambia la onda")
	_expect(first_shot == same_shot, "cache reutiliza el stream")
	_expect(_bytes_equal(AudioSynthScript.shot("pistol", 42).data, AudioSynthScript.shot("pistol", 42).data), "semilla explicita determinista")
	AudioSynthScript.clear_cache()
	_expect_eq(AudioSynthScript.cache_bytes(), 0, "limpieza de cache de audio")
	for i in range(320):
		AudioSynthScript.stream("shot", "pistol", 9000 + i)
	_expect(AudioSynthScript.cache_bytes() <= AudioSynthScript.CACHE_LIMIT_BYTES, "tope de memoria de audio respetado")
	_expect(AudioSynthScript.cache_bytes() > 0, "cache de audio sigue sirviendo streams")
	_expect(AudioSynthScript.cached_count() < 320, "entradas antiguas desalojadas")
	AudioSynthScript.clear_cache()
	AudioSynthScript.set_seed(12345)

	_case = "voces sintetizadas y variacion por NPC"
	_voice.register_npc("alpha", {"pitch": 0.82, "gender": 0.1, "age": 0.8, "mood": 0.25, "timbre": 0.9})
	_voice.register_npc("beta", {"pitch": 1.32, "gender": 0.9, "age": 0.15, "mood": 0.85, "timbre": 1.3})
	_voice.register_npc("gamma", {"pitch": 1.05, "gender": 0.5, "age": 0.5, "mood": 0.5})
	var alpha_fear: AudioStreamWAV = _voice.voice_stream("alpha", "fear")
	var beta_fear: AudioStreamWAV = _voice.voice_stream("beta", "fear")
	var gamma_fear: AudioStreamWAV = _voice.voice_stream("gamma", "fear")
	_check_stream(alpha_fear, "grito de miedo alpha")
	_check_stream(beta_fear, "grito de miedo beta")
	_expect(not _bytes_equal(alpha_fear.data, beta_fear.data), "voces distintas entre NPC")
	_expect(not _bytes_equal(beta_fear.data, gamma_fear.data), "voces distintas entre beta y gamma")
	_expect(_bytes_equal(alpha_fear.data, _voice.voice_stream("alpha", "fear").data), "voz determinista por NPC y cue")
	for cue in NONVERBAL_CUES:
		_check_stream(_voice.voice_stream("alpha", cue), "voz %s" % cue)
	_expect(_voice.cached_voice_count() > 0, "voces cacheadas")
	_expect(_voice.voice_cache_bytes() <= VoiceSystemScript.VOICE_CACHE_LIMIT_BYTES, "tope de memoria de voces")

	_case = "seleccion de voz segun contexto"
	_voice.set_npc_state("alpha", {"health": 0.0})
	_expect_eq(_voice.select_cue("alpha"), "death", "salud cero selecciona estertor")
	_voice.set_npc_state("alpha", {"health": 12.0})
	_expect(["pain", "pant"].has(_voice.select_cue("alpha")), "salud baja selecciona dolor o jadeo")
	_voice.set_npc_state("alpha", {"health": 100.0, "fear": 0.95, "bravery": 0.1})
	_expect(["fear", "hey"].has(_voice.select_cue("alpha")), "miedo alto selecciona grito o alerta")
	_voice.set_npc_state("alpha", {"fear": 0.1, "mood": 0.1, "health": 100.0})
	_expect_eq(_voice.select_cue("alpha"), "cry", "animo bajo selecciona llanto")
	_expect_eq(_voice.select_phrase("alpha", {"health": 10.0, "relation": 0.8}), "surrender", "herido y aliado se rinde")
	_expect_eq(_voice.select_phrase("alpha", {"health": 100.0, "fear": 0.9, "under_fire": true}), "shots", "bajo fuego avisa de disparos")
	_expect_eq(_voice.select_phrase("alpha", {"health": 100.0, "enemy_seen": true}), "halt", "enemigo visible da el alto")
	_expect_eq(_voice.react("alpha", {"health": 0.0}), "death", "react usa el selector")
	_voice.reset()
	_voice.set_process(false)
	_voice.set_cooldown(0.0)
	_voice.register_npc("alpha", {"pitch": 0.82, "gender": 0.1})
	_voice.register_npc("beta", {"pitch": 1.32, "gender": 0.9})

	_case = "cooldown y subtitulos"
	_voice.set_cooldown(0.6)
	_subtitles.clear()
	_expect(_voice.play_cue("alpha", "pain"), "primera voz permitida")
	_expect(not _voice.play_cue("alpha", "pain"), "cooldown bloquea voz repetida")
	_expect_eq(_subtitles.size(), 1, "cooldown no emite subtitulos duplicados")
	_expect_eq(_voice.last_subtitle(), "¡Aay!, ¡duele!", "subtitulo de dolor")
	_voice.advance(0.65)
	_expect(_voice.play_cue("alpha", "pain"), "voz permitida tras cooldown")
	_expect(_voice.can_play("beta"), "cooldown es por NPC")

	_case = "limite de voces simultaneas"
	_voice.reset()
	_voice.set_process(false)
	_voice.set_cooldown(0.0)
	_subtitles.clear()
	var started := 0
	for i in range(6):
		var npc := "crowd_%d" % i
		_voice.register_npc(npc)
		if _voice.play_cue(npc, "fear"):
			started += 1
	_expect_eq(started, VoiceSystemScript.MAX_VOICES, "maximo cuatro voces simultaneas")
	_expect_eq(_voice.active_count(), VoiceSystemScript.MAX_VOICES, "activas contabilizadas")
	_expect(_voice.dropped_count() >= 2, "voces excedentes descartadas")
	_expect_eq(_subtitles.size(), 6, "subtitulos emitidos aunque falte canal de audio")
	_voice.advance(2.0)
	_expect_eq(_voice.active_count(), 0, "voces retiradas al terminar")

	_case = "TTS protegido y subtitulos de respaldo"
	VoiceSystemScript.tts_voices_override = []
	_subtitles.clear()
	_expect(not VoiceSystemScript.tts_available(), "sin voces TTS el sistema lo detecta")
	_expect(_voice.speak_phrase("alpha", "help"), "frase hablada sin TTS no rompe")
	_expect_eq(_voice.last_subtitle(), "¡Ayuda!", "subtitulo de ayuda siempre presente")
	_expect(_subtitles.size() == 1 and str((_subtitles[0] as Dictionary).get("npc", "")) == "alpha", "subtitulo identifica al NPC")
	_expect_eq(VoiceSystemScript.tts_calls.size(), 0, "sin voces no se llama a TTS")
	VoiceSystemScript.tts_voices_override = ["voz_prueba"]
	VoiceSystemScript.tts_speak_hook = Callable(self, "_record_tts")
	_tts_record.clear()
	_voice.advance(1.0)
	_expect(VoiceSystemScript.tts_available(), "override de TTS disponible para la prueba")
	_expect(_voice.speak_phrase("beta", "cover"), "frase con TTS disponible")
	_expect_eq(VoiceSystemScript.tts_calls.size(), 1, "una llamada TTS")
	_expect(_tts_record.size() >= 1 and str(_tts_record[0]) == "¡Cúbrete!", "TTS recibe el texto de la frase")
	_expect_eq(_voice.last_subtitle(), "¡Cúbrete!", "subtitulo tambien con TTS")
	_expect(not _voice.speak_phrase("beta", "unknown_phrase"), "frase desconocida rechazada")
	VoiceSystemScript.reset_tts_test_hooks()

	_case = "audio espacial y buses por categoria"
	var buses: Dictionary = SfxBankScript.ensure_buses()
	for category in SfxBankScript.CATEGORIES:
		_expect(buses.has(category) and int(buses[category]) >= 0, "bus disponible: %s" % category)
	SfxBankScript.set_volume("voices", 0.35)
	var voice_bus := AudioServer.get_bus_index(SfxBankScript.bus_name("voices"))
	_expect(_near(AudioServer.get_bus_volume_linear(voice_bus), 0.35, 0.02), "volumen de voces configurable")
	var space: Dictionary = SfxBankScript.configure_space(20.0, "sfx")
	_expect(space.has("room_size") and float(space["room_size"]) > 0.0, "reverberacion segun tamano")
	_expect(AudioServer.get_bus_effect_count(int(buses["sfx"])) > 0, "efecto de reverb barato en bus sfx")
	SfxBankScript.set_room_size(0.0, "sfx")
	_expect(_near(float(SfxBankScript.configure_space(0.0, "sfx")["wet"]), 0.0, 0.001), "sin reverb en espacio cerrado pequeno")
	var positional := SfxBankScript.play_3d(_root, AudioSynthScript.shot("pistol"), Vector3(3.0, 1.0, -2.0), "sfx")
	_expect(positional is AudioStreamPlayer3D, "helper 3D crea reproductor espacial")
	_expect_eq(str(positional.bus), SfxBankScript.bus_name("sfx"), "reproductor 3D usa bus sfx")
	_expect_eq(positional.position, Vector3(3.0, 1.0, -2.0), "posicion 3D aplicada")
	_expect(positional.max_distance >= 1.0, "atenuacion por distancia configurada")
	var planar := SfxBankScript.play_2d(_root, AudioSynthScript.ambience("wind"), "ambience", -3.0, true)
	_expect(planar is AudioStreamPlayer, "helper 2D crea reproductor")
	_expect_eq(str(planar.bus), SfxBankScript.bus_name("ambience"), "reproductor 2D usa bus ambiente")
	SfxBankScript.set_volume("voices", 1.0)

	_case = "tope de memoria acumulado"
	var before := AudioSynthScript.cache_bytes()
	var voice_before: int = int(_voice.voice_cache_bytes())
	for i in range(90):
		_voice.voice_stream("memory_%d" % i, "fear")
	_expect(_voice.voice_cache_bytes() <= VoiceSystemScript.VOICE_CACHE_LIMIT_BYTES, "cache de voces nunca excede el tope")
	_expect(_voice.voice_cache_bytes() >= voice_before, "cache de voces reutiliza entradas")
	_expect(AudioSynthScript.cache_bytes() <= AudioSynthScript.CACHE_LIMIT_BYTES, "cache de audio nunca excede el tope")
	_expect(before <= AudioSynthScript.CACHE_LIMIT_BYTES, "cache de audio previo dentro del limite")

	_voice.reset()
	VoiceSystemScript.reset_tts_test_hooks()
	AudioSynthScript.clear_cache()
	_planar_free(planar)
	_planar_free(positional)
	SfxBankScript.reset()
	await process_frame
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _on_subtitle(text: String, npc: String) -> void:
	_subtitles.append({"text": text, "npc": npc})


func _record_tts(text = "", voice = "", volume = 1.0, pitch = 1.0, rate = 1.0, utterance = 0, interrupt = false) -> void:
	_tts_record.append(str(text))


func _check_stream(audio, label: String) -> void:
	_expect(audio is AudioStreamWAV, "%s es AudioStreamWAV" % label)
	if not audio is AudioStreamWAV:
		return
	var wave := audio as AudioStreamWAV
	_expect(wave.data.size() > 64 and wave.data.size() % 2 == 0, "%s con muestras PCM validas" % label)
	_expect_eq(wave.mix_rate, AudioSynthScript.RATE, "%s sample rate" % label)
	_expect_eq(wave.format, AudioStreamWAV.FORMAT_16_BITS, "%s formato de 16 bits" % label)
	_expect(wave.get_length() > 0.0 and wave.get_length() <= AudioSynthScript.MAX_SECONDS, "%s duracion acotada" % label)
	_expect(absf(float(wave.data.size() / 2) - wave.get_length() * float(AudioSynthScript.RATE)) <= 1.0, "%s muestras coherentes" % label)
	_expect(_peak(_samples(wave)) > 0.05, "%s no es silencio" % label)


func _samples(wave: AudioStreamWAV) -> PackedFloat32Array:
	var count := wave.data.size() / 2
	var out := PackedFloat32Array()
	out.resize(count)
	for i in range(count):
		var low := int(wave.data[i * 2])
		var high := int(wave.data[i * 2 + 1])
		var value := low | (high << 8)
		if value >= 32768:
			value -= 65536
		out[i] = float(value) / 32768.0
	return out


func _peak(samples: PackedFloat32Array) -> float:
	var maximum := 0.0
	for i in range(samples.size()):
		maximum = maxf(maximum, absf(samples[i]))
	return maximum


func _tail_energy(wave: AudioStreamWAV) -> float:
	var samples := _samples(wave)
	var start := int(float(samples.size()) * 0.75)
	var energy := 0.0
	for i in range(start, samples.size()):
		energy += absf(samples[i])
	return energy / float(maxi(1, samples.size() - start))


func _bytes_equal(a: PackedByteArray, b: PackedByteArray) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i] != b[i]:
			return false
	return true


func _near(a: float, b: float, tolerance: float) -> bool:
	return absf(a - b) <= tolerance


func _planar_free(player) -> void:
	if player != null and is_instance_valid(player) and not (player as Node).is_queued_for_deletion():
		(player as Node).queue_free()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


func _expect_eq(actual, expected, message: String) -> void:
	_expect(actual == expected, "%s (esperado %s, obtenido %s)" % [message, str(expected), str(actual)])
