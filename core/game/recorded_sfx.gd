class_name RecordedSfx

# Grabaciones reales (ver assets/audio/AUDIO_CREDITS.md y real/manifest.json).
# Las muestras del usuario (escopeta y AK47) se conservan intactas como capa (a).
const SAMPLES := {
	"shotgun": {
		"fire": "res://assets/audio/shotgun_fire.wav",
		"pump": "res://assets/audio/shotgun_pump.wav",
	},
	"assault_rifle": {
		"fire": "res://assets/audio/ak47_single.wav",
		"burst": "res://assets/audio/ak47_burst.wav",
	},
}
const ALIASES := {"ak47": "assault_rifle", "ak-47": "assault_rifle", "escopeta": "shotgun"}
const REAL_DIR := "res://assets/audio/real/"
const MANIFEST_PATH := REAL_DIR + "manifest.json"

# Bancos de variantes reales. Las variantes se eligen al azar con tono +/-4 %.
const BANKS := {
	"shot_pistol": ["shot_pistol_01.ogg", "shot_pistol_02.ogg", "shot_pistol_03.ogg"],
	"shot_smg": ["shot_smg_01.ogg", "shot_smg_02.ogg"],
	"shot_rifle": ["shot_rifle_01.ogg", "shot_rifle_02.ogg", "shot_rifle_03.ogg"],
	"shot_sniper": ["shot_sniper_01.ogg", "shot_sniper_02.ogg"],
	"body_pistol": ["body_pistol_01.ogg", "body_pistol_02.ogg"],
	"body_smg": ["body_smg_01.ogg", "body_smg_02.ogg"],
	"body_rifle": ["body_rifle_01.ogg", "body_rifle_02.ogg"],
	"body_sniper": ["body_sniper_01.ogg", "body_sniper_02.ogg"],
	"body_shotgun": ["body_shotgun_01.ogg", "body_shotgun_02.ogg"],
	"body_assault_rifle": ["body_assault_rifle_01.ogg", "body_assault_rifle_02.ogg"],
	"crack_rifle": ["crack_rifle_01.ogg"],
	"crack_sniper": ["crack_sniper_01.ogg"],
	"reload_mag": ["reload_mag_01.ogg", "reload_mag_02.ogg"],
	"reload_bolt": ["reload_bolt_01.ogg", "reload_bolt_02.ogg"],
	"reload_slide": ["reload_slide_01.ogg", "reload_slide_02.ogg"],
	"impact_metal": ["impact_metal_01.ogg", "impact_metal_02.ogg", "impact_metal_03.ogg"],
	"impact_wood": ["impact_wood_01.ogg", "impact_wood_02.ogg", "impact_wood_03.ogg"],
	"impact_concrete": ["impact_concrete_01.ogg", "impact_concrete_02.ogg", "impact_concrete_03.ogg"],
	"impact_dirt": ["impact_dirt_01.ogg", "impact_dirt_02.ogg", "impact_dirt_03.ogg"],
	"impact_glass": ["impact_glass_01.ogg", "impact_glass_02.ogg", "impact_glass_03.ogg"],
	"impact_water": ["impact_water_01.ogg", "impact_water_02.ogg"],
	"impact_flesh": ["impact_flesh_01.ogg", "impact_flesh_02.ogg", "impact_flesh_03.ogg"],
	"step_metal": ["step_metal_01.ogg", "step_metal_02.ogg"],
	"step_wood": ["step_wood_01.ogg", "step_wood_02.ogg", "step_wood_03.ogg"],
	"step_concrete": ["step_concrete_01.ogg", "step_concrete_02.ogg"],
	"step_dirt": ["step_dirt_01.ogg", "step_dirt_02.ogg", "step_dirt_03.ogg"],
	"step_grass": ["step_grass_01.ogg", "step_grass_02.ogg"],
	"step_water": ["step_water_01.ogg", "step_water_02.ogg"],
	"melee": ["melee_01.ogg", "melee_02.ogg", "melee_03.ogg", "melee_04.ogg"],
	"voice_pain_male": ["voice_pain_male_01.ogg", "voice_pain_male_02.ogg", "voice_pain_male_03.ogg", "voice_pain_male_04.ogg", "voice_pain_male_05.ogg", "voice_pain_male_06.ogg", "voice_pain_male_07.ogg", "voice_pain_male_08.ogg", "voice_pain_male_09.ogg", "voice_pain_male_10.ogg", "voice_pain_male_11.ogg"],
	"voice_pain_female": ["voice_pain_female_01.ogg", "voice_pain_female_02.ogg", "voice_pain_female_03.ogg", "voice_pain_female_04.ogg"],
	"voice_fear_male": ["voice_fear_male_01.ogg", "voice_fear_male_02.ogg", "voice_fear_male_03.ogg", "voice_fear_male_04.ogg", "voice_fear_male_05.ogg", "voice_fear_male_06.ogg", "voice_fear_male_07.ogg", "voice_fear_male_08.ogg", "voice_fear_male_09.ogg", "voice_fear_male_10.ogg", "voice_fear_male_11.ogg"],
	"voice_fear_female": ["voice_fear_female_01.ogg", "voice_fear_female_02.ogg", "voice_fear_female_03.ogg"],
	"voice_death_male": ["voice_death_male_01.ogg", "voice_death_male_02.ogg", "voice_death_male_03.ogg", "voice_death_male_04.ogg", "voice_death_male_05.ogg", "voice_death_male_06.ogg", "voice_death_male_07.ogg", "voice_death_male_08.ogg"],
	"voice_death_female": ["voice_death_female_02.ogg", "voice_death_female_03.ogg", "voice_death_female_04.ogg", "voice_death_female_05.ogg", "voice_death_female_06.ogg"],
	"voice_effort_male": ["voice_effort_male_01.ogg", "voice_effort_male_02.ogg", "voice_effort_male_03.ogg", "voice_effort_male_04.ogg"],
	"voice_effort_female": ["voice_effort_female_01.ogg", "voice_effort_female_02.ogg", "voice_effort_female_03.ogg"],
	"voice_pant": ["voice_pant_01.ogg", "voice_pant_02.ogg", "voice_pant_03.ogg"],
	"voice_growl": ["voice_growl_01.ogg", "voice_growl_02.ogg", "voice_growl_03.ogg", "voice_growl_04.ogg", "voice_growl_05.ogg", "voice_growl_06.ogg", "voice_growl_07.ogg", "voice_growl_08.ogg", "voice_growl_09.ogg", "voice_growl_10.ogg", "voice_growl_11.ogg", "voice_growl_12.ogg"],
	"voice_laugh": ["voice_laugh_01.ogg", "voice_laugh_02.ogg", "voice_laugh_03.ogg", "voice_laugh_04.ogg", "voice_laugh_05.ogg", "voice_laugh_06.ogg"],
	"voice_cough": ["voice_cough_01.ogg", "voice_cough_02.ogg", "voice_cough_03.ogg"],
	"voice_cry": ["voice_cry_01.ogg", "voice_cry_02.ogg", "voice_cry_03.ogg"],
	"voice_alert": ["voice_alert_01.ogg", "voice_alert_02.ogg", "voice_alert_03.ogg", "voice_alert_04.ogg", "voice_alert_05.ogg", "voice_alert_06.ogg"],
	"voice_phrase": ["voice_phrase_01.ogg", "voice_phrase_02.ogg", "voice_phrase_03.ogg", "voice_phrase_04.ogg"],
	"glass_break": ["glass_break_01.ogg", "glass_break_02.ogg", "glass_break_03.ogg", "glass_break_04.ogg"],
	"explosion": ["explosion_01.ogg", "explosion_02.ogg", "explosion_03.ogg"],
	"engine": ["engine_01.ogg", "engine_02.ogg", "engine_03.ogg"],
	"horn": ["horn_01.ogg"],
	"amb_wind": ["amb_wind_01.ogg", "amb_wind_02.ogg"],
	"amb_city": ["amb_city_01.ogg"],
	"amb_birds": ["amb_birds_01.ogg"],
	"amb_crickets": ["amb_crickets_01.ogg"],
}

static var _cache: Dictionary = {}
static var _manifest: Dictionary = {}


static func normalize_id(weapon_id: String) -> String:
	return ALIASES.get(weapon_id, weapon_id)


static func has_sample(weapon_id: String, kind: String) -> bool:
	return SAMPLES.get(normalize_id(weapon_id), {}).has(kind)


static func stream_for(weapon_id: String, kind: String) -> AudioStream:
	var id := normalize_id(weapon_id)
	var path: String = SAMPLES.get(id, {}).get(kind, "")
	if path.is_empty():
		return null
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	_cache[path] = s
	return s


static func clear_cache() -> void:
	_cache.clear()


static func bank_names() -> Array:
	return BANKS.keys()


static func has_bank(bank: String) -> bool:
	return BANKS.has(bank) and not (BANKS[bank] as Array).is_empty()


static func variant_count(bank: String) -> int:
	return (BANKS.get(bank, []) as Array).size()


static func bank_files(bank: String) -> Array:
	return (BANKS.get(bank, []) as Array).duplicate()


static func stream_at(bank: String, index: int) -> AudioStream:
	var files := BANKS.get(bank, []) as Array
	if files.is_empty():
		return null
	var i := absi(index) % files.size()
	var path := REAL_DIR + str(files[i])
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	_cache[path] = s
	return s


static func variant_index(bank: String, seed_value: int) -> int:
	var count := variant_count(bank)
	if count <= 0:
		return 0
	return positive_modulo(seed_value, count)


static func random_stream(bank: String, rng: RandomNumberGenerator = null) -> AudioStream:
	var count := variant_count(bank)
	if count <= 0:
		return null
	var index := (rng.randi() if rng != null else randi()) % count
	return stream_at(bank, index)


static func pitch_variation(rng: RandomNumberGenerator = null) -> float:
	var value := rng.randf_range(-0.04, 0.04) if rng != null else randf_range(-0.04, 0.04)
	return 1.0 + value


static func positive_modulo(value: int, modulus: int) -> int:
	if modulus <= 0:
		return 0
	var result := value % modulus
	return result if result >= 0 else result + modulus


static func manifest() -> Dictionary:
	if not _manifest.is_empty():
		return _manifest
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_manifest = parsed as Dictionary
		if _manifest.has("files") and _manifest["files"] is Dictionary:
			_manifest = _manifest["files"] as Dictionary
	return _manifest


static func manifest_peak(file_name: String) -> float:
	var data: Dictionary = manifest().get(file_name, {})
	return clampf(float(data.get("peak", 0.0)), 0.0, 1.0)


static func bank_peak(bank: String) -> float:
	var maximum := 0.0
	for file_name in bank_files(bank):
		maximum = maxf(maximum, manifest_peak(str(file_name)))
	return maximum


static func play_bank(bank: String, parent: Node, pos: Vector3, rng: RandomNumberGenerator = null, bus: String = "", options: Dictionary = {}) -> AudioStreamPlayer3D:
	var audio := random_stream(bank, rng)
	if audio == null or parent == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.name = "G12RealAudio"
	p.stream = audio
	p.bus = bus if not bus.is_empty() else "Master"
	p.pitch_scale = pitch_variation(rng)
	p.max_distance = clampf(float(options.get("max_distance", 120.0)), 1.0, 500.0)
	p.unit_size = clampf(float(options.get("unit_size", 12.0)), 0.1, 100.0)
	p.volume_db = clampf(float(options.get("volume_db", 0.0)), -60.0, 24.0)
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
	return p


# Reproduce en 3D con variacion de tono para que no suene repetido. Devuelve el player o null.
static func play(weapon_id: String, kind: String, parent: Node, pos: Vector3, rng: RandomNumberGenerator = null) -> AudioStreamPlayer3D:
	var s := stream_for(weapon_id, kind)
	if s == null or parent == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.max_distance = 120.0
	p.unit_size = 12.0
	var r := rng.randf_range(-0.04, 0.04) if rng != null else randf_range(-0.04, 0.04)
	p.pitch_scale = 1.0 + r
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
	return p
