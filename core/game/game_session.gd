class_name GameSession
extends RefCounted

const WORLD_SCENE: String = "res://scenes/world/game_world.tscn"
const VR_GAME_MODE_PATH: String = "res://core/vr/vr_game_mode.gd"

static var map_meta: Dictionary = {}
static var platform: String = ""
static var platform_override: String = ""
static var gore_enabled: bool = true
static var seed: int = 0
static var start_override: Callable = Callable()
static var vr_menu_confirmed: bool = false


static func detect_platform() -> String:
	if not platform_override.is_empty():
		return platform_override
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
	if platform == "vr" and not vr_menu_confirmed and ResourceLoader.exists(VR_GAME_MODE_PATH):
		var mode_script: Script = load(VR_GAME_MODE_PATH) as Script
		if mode_script != null and mode_script.has_method("build_start_menu"):
			var menu = mode_script.call("build_start_menu", map_meta.duplicate(true), tree)
			if menu != null:
				vr_menu_confirmed = true
				return OK
	vr_menu_confirmed = false
	if not ResourceLoader.exists(WORLD_SCENE):
		return ERR_FILE_NOT_FOUND
	return tree.change_scene_to_file(WORLD_SCENE)
