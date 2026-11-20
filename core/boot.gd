class_name Boot
extends RefCounted

const EventBusScript = preload("res://core/event_bus.gd")
const ModLoaderScript = preload("res://core/mod_loader.gd")
const MapRegistryScript = preload("res://core/maps/map_registry.gd")
const MapLoaderScript = preload("res://core/maps/map_loader.gd")
const ContentRegistryScript = preload("res://core/game/content_registry.gd")

var bus
var mod_registry
var mod_loader
var map_registry
var map_loader
var content_registry


func _init() -> void:
	_reset()


func run(mods_dir: String, maps_dir: String) -> Dictionary:
	_reset()
	var mods_report := _run_mods(mods_dir)
	var maps_report := _run_maps(maps_dir)
	return {
		"mods": mods_report,
		"maps": maps_report,
		"ok": bool(mods_report.get("ok", false)) and _maps_ok(maps_report),
	}


func _reset() -> void:
	bus = EventBusScript.new()
	mod_loader = ModLoaderScript.new(bus)
	mod_registry = mod_loader.get_registry()
	map_registry = MapRegistryScript.new()
	map_loader = MapLoaderScript.new()
	content_registry = ContentRegistryScript.instance()


func _run_mods(mods_dir: String) -> Dictionary:
	if mods_dir.is_empty():
		return _mods_failure(mods_dir, "ruta de mods vacia")
	if not _is_dir(mods_dir):
		return _mods_failure(mods_dir, "directorio de mods inexistente: " + mods_dir)
	return mod_loader.load_all(mods_dir)


func _run_maps(maps_dir: String) -> Dictionary:
	if maps_dir.is_empty():
		return _maps_failure(maps_dir, "ruta de mapas vacia")
	if not _is_dir(maps_dir):
		return _maps_failure(maps_dir, "directorio de mapas inexistente: " + maps_dir)
	return map_loader.load_dir(maps_dir, map_registry)


func _mods_failure(path: String, reason: String) -> Dictionary:
	return {
		"ok": false,
		"loaded": [],
		"rejected": {path: reason},
		"order": [],
	}


func _maps_failure(path: String, reason: String) -> Dictionary:
	return {
		"registered": [],
		"rejected": [{"file": path, "id": "", "reason": reason, "motivo": reason}],
	}


func _is_dir(path: String) -> bool:
	var dir := DirAccess.open(path)
	if dir == null:
		return false
	return true


func _maps_ok(report: Dictionary) -> bool:
	if report.has("ok"):
		return bool(report["ok"])
	var rejected: Variant = report.get("rejected", [])
	if rejected is Array:
		return (rejected as Array).is_empty()
	return false


func shutdown() -> void:
	# Limpiar registro de contenido si existe
	if content_registry != null and content_registry.has_method("clear"):
		content_registry.clear()
	# Limpiar referencias
	bus = null
	mod_registry = null
	mod_loader = null
	map_registry = null
	map_loader = null
	content_registry = null
