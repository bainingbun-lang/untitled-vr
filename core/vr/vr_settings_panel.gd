class_name VrSettingsPanel extends RefCounted

const VrComfortScript = preload("res://core/vr/vr_comfort.gd")
const VrRigScript = preload("res://core/vr/vr_rig.gd")
const GameSettingsScript = preload("res://core/game/game_settings.gd")

signal settings_changed(key: String, value: Variant)

var _rig: VrRig = null
var _settings: GameSettings = null
var _profile: Dictionary = VrComfortScript.default_profile()

func init(rig: VrRig = null, settings: GameSettings = null) -> void:
	_rig = rig
	_settings = settings
	if _settings != null and _settings.has("vr_comfort"):
		_load_from_settings()
	else:
		_profile = VrComfortScript.default_profile()
	if _rig != null:
		_apply_to_rig()


func _load_from_settings() -> void:
	var data: Dictionary = _settings.get_value("vr_comfort", {})
	var validated := VrComfortScript.validate_profile(data)
	if bool(validated["ok"]):
		_profile = validated["profile"]
	else:
		_profile = VrComfortScript.default_profile()
		_save_to_settings()


func _save_to_settings() -> void:
	if _settings != null:
		_settings.set_value("vr_comfort", _profile)
		_settings.save()


func _apply_to_rig() -> void:
	if _rig == null:
		return
	var keys := [
		"turn_mode", "smooth_turn_speed", "snap_turn_degrees", "snap_cooldown",
		"stick_deadzone", "snap_threshold", "move_speed", "comfort_vignette_enabled",
		"vignette_intensity", "vignette_speed_ref", "vignette_angular_ref",
		"teleport_enabled", "teleport_max_distance", "seated_mode", "height_offset"
	]
	for key in keys:
		if _rig.has_property(key):
			_rig.set(key, _profile[key])


func get_profile() -> Dictionary:
	return _profile.duplicate(true)


func set_value(key: String, value: Variant) -> bool:
	if not _profile.has(key):
		return false
	_profile[key] = value
	var validated := VrComfortScript.validate_profile(_profile)
	if not bool(validated["ok"]):
		_profile = VrComfortScript.default_profile()
		return false
	_save_to_settings()
	if _rig != null:
		_apply_to_rig()
	settings_changed.emit(key, value)
	return true


func get_value(key: String) -> Variant:
	if _profile.has(key):
		return _profile[key]
	return null


func apply_comfort_profile(profile_name: String) -> bool:
	var presets := _get_presets()
	if not presets.has(profile_name):
		return false
	_profile = presets[profile_name].duplicate(true)
	_save_to_settings()
	if _rig != null:
		_apply_to_rig()
	for key in _profile.keys():
		settings_changed.emit(key, _profile[key])
	return true


func _get_presets() -> Dictionary:
	return {
		"default": VrComfortScript.default_profile(),
		"comfort": {
			"version": VrComfortScript.VERSION,
			"turn_mode": "snap",
			"smooth_turn_speed": 1.6,
			"snap_turn_degrees": 45.0,
			"snap_cooldown": 0.3,
			"stick_deadzone": 0.25,
			"snap_threshold": 0.75,
			"move_speed": 1.8,
			"comfort_vignette_enabled": true,
			"vignette_intensity": 1.0,
			"vignette_speed_ref": 2.5,
			"vignette_angular_ref": 1.5,
			"teleport_enabled": true,
			"teleport_max_distance": 4.0,
			"seated_mode": false,
			"height_offset": 0.0,
		},
		"performance": {
			"version": VrComfortScript.VERSION,
			"turn_mode": "smooth",
			"smooth_turn_speed": 2.0,
			"snap_turn_degrees": 30.0,
			"snap_cooldown": 0.2,
			"stick_deadzone": 0.15,
			"snap_threshold": 0.65,
			"move_speed": 2.5,
			"comfort_vignette_enabled": false,
			"vignette_intensity": 0.5,
			"vignette_speed_ref": 4.0,
			"vignette_angular_ref": 3.0,
			"teleport_enabled": false,
			"teleport_max_distance": 6.0,
			"seated_mode": false,
			"height_offset": 0.0,
		},
		"seated": {
			"version": VrComfortScript.VERSION,
			"turn_mode": "smooth",
			"smooth_turn_speed": 1.8,
			"snap_turn_degrees": 30.0,
			"snap_cooldown": 0.25,
			"stick_deadzone": 0.2,
			"snap_threshold": 0.7,
			"move_speed": 1.5,
			"comfort_vignette_enabled": true,
			"vignette_intensity": 0.9,
			"vignette_speed_ref": 2.0,
			"vignette_angular_ref": 1.8,
			"teleport_enabled": true,
			"teleport_max_distance": 3.5,
			"seated_mode": true,
			"height_offset": -0.3,
		},
	}