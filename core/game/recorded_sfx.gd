class_name RecordedSfx

# Sonidos grabados aportados por el usuario (ver assets/audio/AUDIO_CREDITS.md).
# El AK47 es el arma "assault_rifle" (alias "ak47").
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

static var _cache: Dictionary = {}


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
