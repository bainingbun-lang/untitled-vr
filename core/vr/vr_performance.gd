class_name VrPerformance
extends Node

const MODE_72 := "quest_72"
const MODE_90 := "quest_90"

const DEFAULT_PROFILES := {
	MODE_72: {
		"mode": MODE_72,
		"refresh_hz": 72.0,
		"frame_budget_ms": 13.888,
		"msaa": 2,
		"foveation": 1,
		"render_scale": 1.0,
		"shadow_distance": 18.0,
		"particles": 120,
		"npcs": 12,
		"decals": 48,
	},
	MODE_90: {
		"mode": MODE_90,
		"refresh_hz": 90.0,
		"frame_budget_ms": 11.111,
		"msaa": 2,
		"foveation": 1,
		"render_scale": 1.0,
		"shadow_distance": 16.0,
		"particles": 96,
		"npcs": 10,
		"decals": 40,
	},
}

const MIN_SETTINGS := {
	"msaa": 0,
	"foveation": 0,
	"render_scale": 0.7,
	"shadow_distance": 6.0,
	"particles": 24,
	"npcs": 4,
	"decals": 8,
}

const MAX_SETTINGS := {
	"msaa": 4,
	"foveation": 4,
	"render_scale": 1.0,
	"shadow_distance": 24.0,
	"particles": 160,
	"npcs": 16,
	"decals": 64,
}

var target_mode: String = MODE_72
var profile: Dictionary = {}
var degrade_level: int = 0
var max_degrade_level: int = 4
var below_budget_frames: int = 0
var above_budget_frames: int = 0
var downshift_frames: int = 8
var upshift_frames: int = 24
var downshift_margin_ms: float = 1.0
var upshift_margin_ms: float = 1.5
var xr_available: bool = false
var _built: bool = false


func _init(mode: String = MODE_72) -> void:
	set_target_mode(mode)


func build() -> bool:
	_built = true
	xr_available = detect_openxr_available()
	return true


func is_built() -> bool:
	return _built


func set_target_mode(mode: String) -> void:
	if not DEFAULT_PROFILES.has(mode):
		mode = MODE_72
	target_mode = mode
	profile = profile_for_mode(mode, degrade_level)
	below_budget_frames = 0
	above_budget_frames = 0


func current_profile() -> Dictionary:
	return profile.duplicate(true)


func observe_frame(frame_ms: float, delta_s: float = -1.0) -> Dictionary:
	var budget: float = float(profile.get("frame_budget_ms", profile_for_mode(target_mode, 0).get("frame_budget_ms", 13.888)))
	var sample_ms: float = frame_ms
	if sample_ms <= 0.0 and delta_s > 0.0:
		sample_ms = delta_s * 1000.0
	var over_limit: bool = sample_ms > budget + downshift_margin_ms
	var under_limit: bool = sample_ms < budget - upshift_margin_ms
	var changed := false
	if over_limit:
		below_budget_frames += 1
		above_budget_frames = 0
	elif under_limit:
		above_budget_frames += 1
		below_budget_frames = 0
	else:
		below_budget_frames = 0
		above_budget_frames = 0

	if below_budget_frames >= downshift_frames and degrade_level < max_degrade_level:
		degrade_level += 1
		below_budget_frames = 0
		changed = true
	elif above_budget_frames >= upshift_frames and degrade_level > 0:
		degrade_level -= 1
		above_budget_frames = 0
		changed = true

	if changed:
		profile = profile_for_mode(target_mode, degrade_level)

	return {
		"mode": target_mode,
		"degrade_level": degrade_level,
		"changed": changed,
		"frame_ms": sample_ms,
		"budget_ms": budget,
		"profile": profile.duplicate(true),
		"below_72fps": is_below_72fps(sample_ms),
	}


static func profile_for_mode(mode: String, level: int = 0) -> Dictionary:
	var base_mode := mode if DEFAULT_PROFILES.has(mode) else MODE_72
	var base: Dictionary = (DEFAULT_PROFILES[base_mode] as Dictionary).duplicate(true)
	return apply_degrade_level(base, level)


static func apply_degrade_level(base: Dictionary, level: int) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	var steps := clampi(level, 0, 8)
	for i in range(steps):
		out["render_scale"] = maxf(float(out.get("render_scale", 1.0)) - 0.08, float(MIN_SETTINGS["render_scale"]))
		out["shadow_distance"] = maxf(float(out.get("shadow_distance", 12.0)) - 3.0, float(MIN_SETTINGS["shadow_distance"]))
		out["particles"] = maxi(int(round(float(out.get("particles", 64)) * 0.72)), int(MIN_SETTINGS["particles"]))
		out["npcs"] = maxi(int(out.get("npcs", 8)) - 2, int(MIN_SETTINGS["npcs"]))
		out["decals"] = maxi(int(round(float(out.get("decals", 32)) * 0.7)), int(MIN_SETTINGS["decals"]))
		if i >= 1:
			out["msaa"] = maxi(int(out.get("msaa", 2)) - 2, int(MIN_SETTINGS["msaa"]))
		if i >= 2:
			out["foveation"] = mini(int(out.get("foveation", 1)) + 1, int(MAX_SETTINGS["foveation"]))
	out["render_scale"] = clampf(float(out.get("render_scale", 1.0)), float(MIN_SETTINGS["render_scale"]), float(MAX_SETTINGS["render_scale"]))
	out["shadow_distance"] = clampf(float(out.get("shadow_distance", 12.0)), float(MIN_SETTINGS["shadow_distance"]), float(MAX_SETTINGS["shadow_distance"]))
	out["particles"] = clampi(int(out.get("particles", 64)), int(MIN_SETTINGS["particles"]), int(MAX_SETTINGS["particles"]))
	out["npcs"] = clampi(int(out.get("npcs", 8)), int(MIN_SETTINGS["npcs"]), int(MAX_SETTINGS["npcs"]))
	out["decals"] = clampi(int(out.get("decals", 32)), int(MIN_SETTINGS["decals"]), int(MAX_SETTINGS["decals"]))
	out["msaa"] = clampi(int(out.get("msaa", 2)), int(MIN_SETTINGS["msaa"]), int(MAX_SETTINGS["msaa"]))
	out["foveation"] = clampi(int(out.get("foveation", 1)), int(MIN_SETTINGS["foveation"]), int(MAX_SETTINGS["foveation"]))
	out["degrade_level"] = steps
	return out


static func is_below_72fps(frame_ms: float) -> bool:
	return frame_ms > 13.888


static func detect_openxr_available() -> bool:
	if not ClassDB.class_exists("XRServer"):
		return false
	if not ClassDB.class_exists("OpenXRInterface"):
		return false
	var iface = XRServer.find_interface("OpenXR")
	if iface == null:
		return false
	if iface.has_method("is_initialized"):
		return bool(iface.call("is_initialized"))
	return true
