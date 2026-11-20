class_name GameSession
extends RefCounted

const WORLD_SCENE: String = "res://scenes/world/game_world.tscn"

static var map_meta: Dictionary = {}
static var platform: String = ""
static var gore_enabled: bool = true
static var seed: int = 0
static var start_override: Callable = Callable()


static func detect_platform() -> String:
	var xr := Engine.get_singleton("XRServer")
	if xr != null and xr.has_method("get_interface_count"):
		if int(xr.call("get_interface_count")) > 0:
			return "vr"
	if OS.get_name() == "Android":
		return "android"
	return "pc"


static func start(meta: Dictionary, tree: SceneTree) -> Error:
	map_meta = meta.duplicate(true)
	seed = int(meta.get("seed", 0))
	platform = detect_platform()
	if start_override.is_valid():
		start_override.call(map_meta.duplicate(true))
		return OK
	if tree == null:
		return ERR_INVALID_PARAMETER
	if not ResourceLoader.exists(WORLD_SCENE):
		return ERR_FILE_NOT_FOUND
	return tree.change_scene_to_file(WORLD_SCENE)
