class_name AudioSynth
extends RefCounted

const RATE := 22050
const MAX_SECONDS := 2.0
const MAX_FRAMES := RATE * 2
const CACHE_LIMIT_BYTES := 3 * 1024 * 1024
const WEAPONS := ["pistol", "smg", "rifle", "shotgun", "sniper"]
const SURFACES := ["metal", "wood", "concrete", "flesh", "glass", "water"]
const AMBIENCES := ["wind", "room", "street", "rain"]

static var _cache: Dictionary = {}
static var _lru: Array = []
static var _cache_bytes := 0
static var _seed := 20240517


static func set_seed(value: int) -> void:
	_seed = value


static func get_seed() -> int:
	return _seed


static func clear_cache() -> void:
	_cache.clear()
	_lru.clear()
	_cache_bytes = 0


static func cache_bytes() -> int:
	return _cache_bytes


static func cached_count() -> int:
	return _cache.size()


static func weapon_variant(weapon_id: String) -> String:
	match weapon_id:
		"assault_rifle", "rifle":
			return "rifle"
		"sniper_rifle", "sniper":
			return "sniper"
		"submachine_gun", "smg":
			return "smg"
		"shotgun":
			return "shotgun"
		_:
			return "pistol"


static func stream(kind: String, variant: String = "", a_seed: int = -1) -> AudioStreamWAV:
	var use_seed := _seed if a_seed < 0 else a_seed
	var key := "%s|%s|%d" % [kind, variant, use_seed]
	if _cache.has(key):
		_lru.erase(key)
		_lru.append(key)
		return (_cache[key] as Dictionary)["stream"]
	var rng := _rng(_hash_text(key))
	var samples := _render(kind, variant, rng)
	var audio := wav_from_samples(samples, kind == "engine" or kind == "ambience")
	audio.resource_name = key
	var bytes := audio.data.size()
	_cache[key] = {"stream": audio, "bytes": bytes}
	_lru.append(key)
	_cache_bytes += bytes
	while _cache_bytes > CACHE_LIMIT_BYTES and not _lru.is_empty():
		var old_key: String = str(_lru.pop_front())
		var old: Dictionary = _cache.get(old_key, {})
		if old.is_empty():
			continue
		_cache_bytes -= int(old.get("bytes", 0))
		_cache.erase(old_key)
	return audio


static func shot(weapon_id: String, a_seed: int = -1) -> AudioStreamWAV:
	return stream("shot", weapon_variant(weapon_id), a_seed)


static func reload_sfx(weapon_id: String = "pistol", a_seed: int = -1) -> AudioStreamWAV:
	return stream("reload", weapon_variant(weapon_id), a_seed)


static func impact(surface: String, a_seed: int = -1) -> AudioStreamWAV:
	return stream("impact", surface, a_seed)


static func footstep(surface: String, a_seed: int = -1) -> AudioStreamWAV:
	return stream("footstep", surface, a_seed)


static func explosion(size: String = "medium", a_seed: int = -1) -> AudioStreamWAV:
	return stream("explosion", size, a_seed)


static func engine(rpm: float, a_seed: int = -1) -> AudioStreamWAV:
	var bucket := int(round(clampf(rpm, 300.0, 8000.0) / 100.0)) * 100
	return stream("engine", "rpm_%d" % bucket, a_seed)


static func ambience(name: String = "wind", a_seed: int = -1) -> AudioStreamWAV:
	return stream("ambience", name, a_seed)


static func wav_from_samples(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var frames := clampi(samples.size(), 1, MAX_FRAMES)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in range(frames):
		var value := int(round(clampf(samples[i], -1.0, 1.0) * 32767.0))
		bytes[i * 2] = value & 0xFF
		bytes[i * 2 + 1] = (value >> 8) & 0xFF
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = RATE
	audio.stereo = false
	audio.data = bytes
	if loop:
		audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
		audio.loop_begin = 0
		audio.loop_end = frames
	return audio


static func _render(kind: String, variant: String, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var seconds := _seconds_for(kind, variant)
	var count := clampi(int(seconds * RATE), 64, MAX_FRAMES)
	var out := PackedFloat32Array()
	out.resize(count)
	match kind:
		"shot":
			_fill_shot(out, variant, rng)
		"reload":
			_fill_reload(out, rng)
		"impact":
			_fill_impact(out, variant, 0.16, 1.0, rng)
		"footstep":
			_fill_impact(out, variant, 0.11, 0.55, rng)
		"explosion":
			_fill_explosion(out, variant, rng)
		"engine":
			_fill_engine(out, variant, rng)
		"ambience":
			_fill_ambience(out, variant, rng)
		_:
			_fill_ambience(out, variant, rng)
	_normalize(out, _peak_for(kind))
	_fade(out, kind == "engine" or kind == "ambience")
	return out


static func _seconds_for(kind: String, variant: String) -> float:
	var seconds := 0.3
	match kind:
		"shot":
			match variant:
				"smg":
					seconds = 0.2
				"shotgun":
					seconds = 0.55
				"sniper":
					seconds = 1.1
				"rifle":
					seconds = 0.4
				_:
					seconds = 0.28
		"reload":
			seconds = 0.6
		"impact":
			seconds = 0.32
		"footstep":
			seconds = 0.28
		"explosion":
			seconds = 0.9 if variant == "small" else 1.6
		"engine":
			seconds = 0.5
		"ambience":
			seconds = 1.8
	return clampf(seconds, 0.05, MAX_SECONDS)


static func _peak_for(kind: String) -> float:
	match kind:
		"ambience", "engine":
			return 0.35
		"footstep":
			return 0.62
		_:
			return 0.9


static func _fill_shot(out: PackedFloat32Array, variant: String, rng: RandomNumberGenerator) -> void:
	var decay := 28.0
	var tone := 420.0
	var grit := 0.8
	match variant:
		"smg":
			decay = 38.0
			tone = 620.0
			grit = 0.9
		"rifle":
			decay = 22.0
			tone = 520.0
			grit = 0.85
		"shotgun":
			decay = 13.0
			tone = 260.0
			grit = 1.0
		"sniper":
			decay = 5.5
			tone = 340.0
			grit = 0.95
	var drift := rng.randf_range(-0.02, 0.02)
	var lowpass := 0.0
	for i in range(out.size()):
		var t := float(i) / float(RATE)
		var white := rng.randf_range(-1.0, 1.0)
		lowpass = lerpf(lowpass, white, 0.55)
		var body := (white * 0.55 + lowpass * 0.45) * exp(-t * decay)
		var thump := sin(TAU * tone * (1.0 + drift) * t) * exp(-t * decay * 0.7)
		out[i] = body * grit + thump * (1.0 - grit * 0.35)
	if variant == "sniper":
		var base := out.duplicate()
		var first := int(0.12 * float(RATE))
		var second := int(0.30 * float(RATE))
		var third := int(0.58 * float(RATE))
		for i in range(first, out.size()):
			out[i] += base[i - first] * 0.42
		for i in range(second, out.size()):
			out[i] += base[i - second] * 0.26
		for i in range(third, out.size()):
			out[i] += base[i - third] * 0.14


static func _fill_reload(out: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var clicks := [0.03, 0.16, 0.34, 0.47]
	for i in range(clicks.size()):
		clicks[i] = float(clicks[i]) + rng.randf_range(-0.012, 0.012)
	for i in range(out.size()):
		var t := float(i) / float(RATE)
		var value := 0.0
		for click_time in clicks:
			var u := t - float(click_time)
			if u >= 0.0 and u < 0.14:
				var metal := sin(TAU * 1750.0 * u) + 0.6 * sin(TAU * 2670.0 * u) + 0.35 * sin(TAU * 3910.0 * u)
				value += (metal * 0.25 + rng.randf_range(-1.0, 1.0) * 0.35) * exp(-u * 55.0)
		out[i] = value


static func _fill_impact(out: PackedFloat32Array, surface: String, decay_time: float, gain: float, rng: RandomNumberGenerator) -> void:
	var key := surface if SURFACES.has(surface) else "concrete"
	var lowpass := 0.0
	for i in range(out.size()):
		var t := float(i) / float(RATE)
		var white := rng.randf_range(-1.0, 1.0)
		lowpass = lerpf(lowpass, white, 0.35)
		var local := t
		var amount := gain
		if decay_time < 0.13 and t >= 0.16:
			local = t - 0.16
			amount = gain * 0.65 * exp(-(t - 0.16) * 3.0)
		out[i] = _surface_sample(key, local, white, lowpass) * amount


static func _surface_sample(surface: String, t: float, white: float, lowpass: float) -> float:
	match surface:
		"metal":
			return (sin(TAU * 1560.0 * t) * 0.5 + sin(TAU * 2410.0 * t) * 0.3 + white * 0.4) * exp(-t * 14.0)
		"wood":
			return (sin(TAU * 190.0 * t) * 0.6 + lowpass * 0.4) * exp(-t * 24.0) + white * exp(-t * 90.0) * 0.3
		"flesh":
			return (sin(TAU * 95.0 * t) * 0.7 + lowpass * 0.5) * exp(-t * 20.0)
		"glass":
			return ((sin(TAU * 2100.0 * t) + sin(TAU * 3300.0 * t) * 0.6 + sin(TAU * 4700.0 * t) * 0.4) * 0.3 + white * 0.4) * exp(-t * 12.0)
		"water":
			return lowpass * exp(-t * 9.0) * (0.6 + 0.4 * sin(TAU * 220.0 * t)) + white * exp(-t * 55.0) * 0.25
		_:
			return lowpass * exp(-t * 18.0) + white * exp(-t * 60.0) * 0.2


static func _fill_explosion(out: PackedFloat32Array, variant: String, rng: RandomNumberGenerator) -> void:
	var decay := 2.2
	if variant == "small":
		decay = 4.0
	elif variant == "large":
		decay = 1.5
	var lowpass := 0.0
	for i in range(out.size()):
		var t := float(i) / float(RATE)
		var white := rng.randf_range(-1.0, 1.0)
		lowpass = lerpf(lowpass, white, 0.12 + 0.2 * exp(-t * 2.0))
		var sweep := sin(TAU * (70.0 - 35.0 * minf(t / 1.4, 1.0)) * t)
		out[i] = (lowpass * 1.1 + sweep * 0.5) * exp(-t * decay) + white * exp(-t * 16.0) * 0.35


static func _fill_engine(out: PackedFloat32Array, variant: String, rng: RandomNumberGenerator) -> void:
	var rpm := 900.0
	var parts := variant.split("_")
	if parts.size() >= 2 and parts[1].is_valid_int():
		rpm = float(int(parts[1]))
	var fundamental := clampf(rpm / 30.0, 8.0, 260.0)
	var cycles := maxi(1, int(round(fundamental * float(out.size()) / float(RATE))))
	for i in range(out.size()):
		var phase := TAU * float(cycles * i) / float(out.size())
		var wave := sin(phase) * 0.5 + sin(phase * 2.0) * 0.28 + sin(phase * 3.0) * 0.14 + sin(phase * 0.5) * 0.1
		out[i] = wave + rng.randf_range(-1.0, 1.0) * 0.06


static func _fill_ambience(out: PackedFloat32Array, variant: String, rng: RandomNumberGenerator) -> void:
	var lowpass := 0.0
	var deep := 0.0
	for i in range(out.size()):
		var t := float(i) / float(RATE)
		var white := rng.randf_range(-1.0, 1.0)
		lowpass = lerpf(lowpass, white, 0.03)
		deep = lerpf(deep, lowpass, 0.08)
		var mod := 0.6 + 0.4 * sin(TAU * 0.35 * t)
		match variant:
			"rain":
				out[i] = (deep * 0.5 + white * 0.2) * mod
			"street":
				out[i] = deep * 0.6 * mod + sin(TAU * 60.0 * t) * 0.03
			"room":
				out[i] = deep * 0.4 + sin(TAU * 48.0 * t) * 0.02
			_:
				out[i] = deep * 0.8 * mod


static func _normalize(out: PackedFloat32Array, peak: float) -> void:
	var maximum := 0.0
	for i in range(out.size()):
		maximum = maxf(maximum, absf(out[i]))
	if maximum <= 0.00001:
		return
	var scale := peak / maximum
	for i in range(out.size()):
		out[i] = clampf(out[i] * scale, -1.0, 1.0)


static func _fade(out: PackedFloat32Array, loop: bool) -> void:
	var edge := clampi(out.size() / 20, 16, 256)
	for i in range(edge):
		var factor := float(i) / float(edge)
		out[i] *= factor
		if not loop:
			out[out.size() - 1 - i] *= factor


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _hash_text(text: String) -> int:
	var value := text.hash()
	if value < 0:
		value = -value
	return value % 2147483646 + 1
