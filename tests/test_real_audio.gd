extends SceneTree

const Recorded = preload("res://core/game/recorded_sfx.gd")
const SfxBankScript = preload("res://core/game/sfx_bank.gd")
const VoiceSystemScript = preload("res://core/game/voice_system.gd")
const AudioSynthScript = preload("res://core/game/audio_synth.gd")

var _n := 0
var _f := 0
var _case := ""
var _root: Node3D = null
var _voice = null
var _subtitles: Array = []
var _tts_record: Array = []


func _initialize() -> void:
	_root = Node3D.new()
	root.add_child(_root)
	_voice = VoiceSystemScript.new()
	_voice.set_process(false)
	_voice.set_cooldown(0.0)
	_voice.subtitle.connect(_on_subtitle)
	_root.add_child(_voice)
	VoiceSystemScript.reset_tts_test_hooks()
	await process_frame
	await process_frame

	_case = "bancos reales cargables"
	var banks: Array = Recorded.bank_names()
	_expect(banks.size() >= 40, "al menos 40 bancos de grabaciones reales")
	for bank in banks:
		_expect(Recorded.has_bank(bank), "banco presente: %s" % bank)
		var stream := Recorded.stream_at(bank, 0)
		_expect(stream is AudioStreamOggVorbis, "muestra OGG cargable: %s" % bank)
		if stream != null:
			_expect(stream.get_length() > 0.02 and stream.get_length() <= 8.0, "duracion razonable: %s" % bank)

	_case = "variantes y tono"
	for bank in ["voice_pain_male", "voice_fear_male", "voice_death_male", "shot_rifle", "impact_metal"]:
		_expect(Recorded.variant_count(bank) >= 1, "variantes en %s" % bank)
	_expect(Recorded.variant_count("voice_pain_male") >= 8, "muchos gritos de dolor")
	_expect(Recorded.variant_count("voice_fear_male") >= 8, "muchos gritos de miedo")
	_expect(Recorded.variant_count("voice_death_male") >= 6, "muchas muertes")
	_expect(Recorded.stream_at("voice_pain_male", 0) != Recorded.stream_at("voice_pain_male", 1), "variantes distintas")
	var pitch_rng := RandomNumberGenerator.new()
	pitch_rng.seed = 4242
	for i in range(24):
		var pitch := Recorded.pitch_variation(pitch_rng)
		_expect(pitch >= 0.96 and pitch <= 1.04, "variacion de tono dentro de +/-4 %")

	_case = "respaldo sintetizado"
	_expect(Recorded.stream_at("banco_inexistente", 0) == null, "banco ausente no inventa muestra")
	_expect(not Recorded.has_bank("banco_inexistente"), "has_bank rechaza banco ausente")
	_expect(AudioSynthScript.shot("pistol") is AudioStreamWAV, "disparo sintetico de respaldo")
	_expect(AudioSynthScript.reload_sfx("rifle") is AudioStreamWAV, "recarga sintetica de respaldo")
	_expect(AudioSynthScript.impact("metal") is AudioStreamWAV, "impacto sintetico de respaldo")
	_expect(SfxBankScript._stream_for_descriptor("bank:banco_inexistente") == null, "descriptor ausente sin stream")

	_case = "manifest, duraciones y presupuesto"
	var manifest: Dictionary = Recorded.manifest()
	_expect(manifest.size() >= 150, "inventario de grabaciones reales")
	var total_bytes := 0
	for bank in banks:
		for file_name in Recorded.bank_files(bank):
			var name := str(file_name)
			var entry: Dictionary = manifest.get(name, {})
			_expect(not entry.is_empty(), "archivo en manifest: %s" % name)
			_expect(float(entry.get("duration", 0.0)) > 0.02 and float(entry.get("duration", 0.0)) <= 6.1, "duracion declarada razonable: %s" % name)
			var path := Recorded.REAL_DIR + name
			_expect(FileAccess.file_exists(path), "archivo OGG presente: %s" % name)
			_expect(FileAccess.file_exists(path + ".import"), "import generado: %s" % name)
			if FileAccess.file_exists(path):
				total_bytes += int(FileAccess.get_size(path))
	_expect(total_bytes > 0 and total_bytes <= 30 * 1024 * 1024, "presupuesto de 30 MB respetado (%d bytes)" % total_bytes)
	_expect(FileAccess.file_exists("res://assets/audio/AUDIO_CREDITS.md"), "creditos de audio presentes")
	var credits_file := FileAccess.open("res://assets/audio/AUDIO_CREDITS.md", FileAccess.READ)
	var credits := credits_file.get_as_text() if credits_file != null else ""
	if credits_file != null:
		credits_file.close()
	_expect(credits.contains("opengameart.org") and credits.contains("CC BY"), "creditos con URL y licencia")

	_case = "capas de disparo"
	for weapon in ["pistol", "smg", "rifle", "shotgun", "sniper", "assault_rifle", "ak47"]:
		var layers: Dictionary = SfxBankScript.resolve_layers(weapon)
		for key in SfxBankScript.LAYER_KEYS:
			var info: Dictionary = layers.get(key, {})
			_expect(info.get("stream") != null, "capa %s de %s resuelta" % [key, weapon])
			_expect(float(info.get("gain", 0.0)) > 0.0, "ganancia de capa %s de %s" % [key, weapon])
		_expect(layers.has("environment"), "entorno de reverberacion de %s" % weapon)
		_expect(SfxBankScript.layer_peak_total(layers) <= 1.0, "sin clipping al sumar capas de %s" % weapon)
	var shotgun_layers: Dictionary = SfxBankScript.resolve_layers("shotgun")
	_expect(shotgun_layers["shot"]["stream"] == Recorded.stream_for("shotgun", "fire"), "escopeta conserva muestra del usuario como capa (a)")
	var ak_layers: Dictionary = SfxBankScript.resolve_layers("ak47")
	_expect(ak_layers["shot"]["stream"] == Recorded.stream_for("assault_rifle", "fire"), "AK47 conserva muestra del usuario como capa (a)")
	_expect(str(ak_layers["weapon"]) == "assault_rifle", "alias ak47 normalizado")
	_expect(SfxBankScript.layer_peak_total(shotgun_layers) > 0.0, "pico de capas medido sobre muestras reales")

	_case = "reproduccion por capas"
	var players: Dictionary = SfxBankScript.play_layered(_root, "shotgun", Vector3.ZERO, {"distance": 0.0})
	for key in ["shot", "body", "crack"]:
		_expect(players.get(key) is AudioStreamPlayer3D, "reproductor de capa %s" % key)
	_expect(not players.has("mechanism"), "mecanismo se programa en segundo plano")
	if players["shot"] is AudioStreamPlayer3D:
		_expect(str((players["shot"] as AudioStreamPlayer3D).bus) == SfxBankScript.bus_name("sfx"), "estampido en bus sfx")
	if players["body"] is AudioStreamPlayer3D:
		_expect(str((players["body"] as AudioStreamPlayer3D).bus) == SfxBankScript.environment_bus("exterior"), "cuerpo en bus de entorno")
	var distant: Dictionary = SfxBankScript.play_layered(_root, "sniper", Vector3.ZERO, {"distance": 500.0})
	_expect(distant.is_empty(), "disparo lejano se programa con retardo")

	_case = "buses de entorno y limitador"
	var buses: Dictionary = SfxBankScript.ensure_buses()
	for category in SfxBankScript.CATEGORIES:
		_expect(int(buses.get(category, -1)) >= 0, "bus de categoria %s" % category)
	for environment in SfxBankScript.ENVIRONMENTS:
		var bus := SfxBankScript.environment_bus(environment)
		var index := AudioServer.get_bus_index(bus)
		_expect(index >= 0, "bus de entorno %s" % environment)
		var has_reverb := false
		for i in range(AudioServer.get_bus_effect_count(index)):
			if AudioServer.get_bus_effect(index, i) is AudioEffectReverb:
				has_reverb = true
		_expect(has_reverb, "AudioEffectReverb en %s" % environment)
		_expect(float(SfxBankScript.configure_environment(environment).get("wet", 0.0)) > 0.0, "cola humeda en %s" % environment)
	_expect(AudioServer.get_bus_index(SfxBankScript.DISTANCE_BUS) >= 0, "bus de filtro por distancia")
	_expect(SfxBankScript.has_master_limiter(), "limitador en bus master")
	_expect(SfxBankScript.ensure_master_limiter(), "limitador maestro idempotente")

	_case = "retardo y filtro por distancia"
	var near_delay := SfxBankScript.delay_for_distance(10.0)
	var far_delay := SfxBankScript.delay_for_distance(100.0)
	_expect(far_delay > near_delay, "mas lejos, mas retardo")
	_expect(absf(near_delay - 10.0 / SfxBankScript.SOUND_SPEED) < 0.001, "retardo a 343 m/s")
	_expect(SfxBankScript.delay_for_distance(100000.0) <= SfxBankScript.MAX_DISTANCE_DELAY, "tope de retardo")
	var near_cutoff := SfxBankScript.cutoff_for_distance(10.0)
	var far_cutoff := SfxBankScript.cutoff_for_distance(200.0)
	_expect(near_cutoff > far_cutoff, "mas lejos, menos agudos")
	_expect(absf(SfxBankScript.set_distance(200.0) - far_cutoff) < 1.0, "filtro sigue la distancia")
	_expect(absf(SfxBankScript.distance_filter_cutoff() - far_cutoff) < 1.0, "AudioEffectLowPassFilter configurado")

	_case = "voces reales por defecto"
	_expect(not _voice.subtitles_enabled, "subtitulos apagados por defecto")
	_expect(not _voice.tts_enabled, "TTS apagado por defecto")
	for cue in ["pain", "fear", "death", "effort", "pant", "cough", "cry", "hey", "laugh", "phrase"]:
		var voice: AudioStream = _voice.voice_stream("probe_%s" % cue, cue)
		_expect(voice is AudioStreamOggVorbis, "voz grabada para %s" % cue)
	_expect(_voice.voice_variant_count("pain", {"gender": 0.1}) >= 8, "varios timbres masculinos de dolor")
	_expect(_voice.voice_variant_count("death", {"gender": 0.9}) >= 4, "varios timbres femeninos de muerte")
	var heard := {}
	for i in range(12):
		var repeated: AudioStream = _voice.voice_stream("repeater", "pain", {}, i)
		heard[str(repeated.resource_name)] = true
	_expect(heard.size() >= 3, "los gritos no se repiten siempre igual")

	_case = "TTS y subtitulos"
	VoiceSystemScript.tts_voices_override = ["voz_prueba"]
	VoiceSystemScript.tts_speak_hook = Callable(self, "_record_tts")
	_tts_record.clear()
	_expect(_voice.speak_phrase("offline", "alert"), "frase sin TTS activo usa grabacion")
	_expect(VoiceSystemScript.tts_calls.is_empty(), "TTS no se llama si el usuario no lo activo")
	_voice.set_tts_enabled(true)
	VoiceSystemScript.tts_prefer = true
	_voice.advance(1.0)
	_expect(_voice.speak_phrase("online", "alert"), "frase con TTS activo")
	_expect(VoiceSystemScript.tts_calls.size() == 1, "una llamada TTS con la opcion activa")
	_expect(_tts_record.size() >= 1 and str(_tts_record[0]) == "¡Alerta!", "TTS recibe la frase")
	VoiceSystemScript.reset_tts_test_hooks()
	_voice.set_subtitles_enabled(true)
	_subtitles.clear()
	_voice.set_cooldown(0.0)
	_voice.register_npc("dummy_5", {})
	_expect(_voice.play_cue("dummy_5", "pain"), "NPC con nombre interno habla")
	_expect(_subtitles.size() == 1, "subtitulo emitido solo con la opcion activa")
	var entry: Dictionary = _subtitles[0]
	_expect(not str(entry.get("npc", "")).contains("dummy") and not str(entry.get("npc", "")).contains("5"), "nombre interno nunca visible")
	_voice.set_subtitles_enabled(false)
	_subtitles.clear()
	_voice.advance(1.0)
	_expect(_voice.play_cue("dummy_5", "pain"), "voz sin subtitulos")
	_expect(_subtitles.is_empty(), "subtitulos desactivados no emiten nada")

	_case = "limite de voces simultaneas"
	_voice.reset()
	_voice.set_process(false)
	_voice.set_cooldown(0.0)
	var started := 0
	for i in range(7):
		var npc := "crowd_%d" % i
		_voice.register_npc(npc)
		if _voice.play_cue(npc, "fear"):
			started += 1
	_expect(started == VoiceSystemScript.MAX_VOICES, "limite de voces simultaneas")
	_expect(_voice.dropped_count() >= 3, "voces sobrantes descartadas")
	_voice.advance(3.0)
	_expect(_voice.active_count() == 0, "canales liberados al terminar")

	_voice.reset()
	VoiceSystemScript.reset_tts_test_hooks()
	SfxBankScript.reset()
	Recorded.clear_cache()
	AudioSynthScript.clear_cache()
	_root.queue_free()
	await process_frame
	if _f == 0:
		print("PASS (%d assertions)" % _n)
		quit(0)
	else:
		print("FAIL (%d/%d assertions fallidas)" % [_f, _n])
		quit(1)


func _on_subtitle(text: String, npc: String) -> void:
	_subtitles.append({"text": text, "npc": npc})


func _record_tts(text = "", voice = "", volume = 1.0, pitch = 1.0, rate = 1.0, utterance = 0, interrupt = false) -> void:
	_tts_record.append(str(text))


func _expect(condition: bool, message: String) -> void:
	_n += 1
	if not condition:
		_f += 1
		print("FAIL: [%s] %s" % [_case, message])
