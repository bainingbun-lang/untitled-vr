class_name GameSettings extends RefCounted

const SETTINGS_PATH := "user://game_settings.json"

signal setting_changed(key: String, value: Variant)

var _data: Dictionary = {}
var _dirty: bool = false

func _init() -> void:
	_load()


func _load() -> void:
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		_data = {}
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_data = parsed
	else:
		_data = {}


func _save() -> void:
	var dir = FileAccess.open("user://", FileAccess.READ)
	if dir == null:
		DirAccess.make_dir_recursive_absolute("user://")
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	var text: String = JSON.stringify(_data, "\t")
	file.store_string(text)
	file.close()
	_dirty = false


func get_value(key: String, default: Variant = null) -> Variant:
	if _data.has(key):
		return _data[key]
	return default


func set_value(key: String, value: Variant) -> void:
	_data[key] = value
	_dirty = true
	setting_changed.emit(key, value)


func has(key: String) -> bool:
	return _data.has(key)


func erase(key: String) -> void:
	if _data.has(key):
		_data.erase(key)
		_dirty = true


func save() -> void:
	if _dirty:
		_save()


func get_all() -> Dictionary:
	return _data.duplicate(true)


func reset() -> void:
	_data = {}
	_dirty = true
	_save()