extends SceneTree

const RigScript = preload("res://core/vr/vr_rig.gd")
const MAP_PATH := "res://openxr_action_map.tres"
const SOURCES := [
	"res://core/vr/vr_rig.gd", "res://core/vr/vr_weapon_hand.gd", "res://core/vr/vr_grab.gd",
	"res://core/vr/vr_reload_gestures.gd", "res://core/vr/vr_vehicle_input.gd", "res://scenes/vr/vr_boot.gd",
	"res://core/vr/vr_action_map.gd", "res://core/vr/vr_hand_pose.gd",
]

# Imita XRController3D: solo responde a acciones que existen en el action map real.
class FakeController extends Node3D:
	var known: Array = []
	var values: Dictionary = {}
	func is_button_pressed(action: StringName) -> bool:
		return known.has(String(action)) and float(values.get(String(action), 0.0)) > 0.5
	func get_vector2(action: StringName) -> Vector2:
		return values.get(String(action), Vector2.ZERO) if known.has(String(action)) else Vector2.ZERO
	func get_float(action: StringName) -> float:
		return float(values.get(String(action), 0.0)) if known.has(String(action)) else 0.0

class FakeWs extends Node:
	var calls := 0
	func fire(_id, _o, _d, _s, _e) -> Dictionary:
		calls += 1
		return {"fired": true}

var _n := 0
var _fail := 0


func _expect(c: bool, m: String) -> void:
	_n += 1
	if not c:
		_fail += 1
		print("FAIL: " + m)


func _initialize() -> void:
	await process_frame
	var map = load(MAP_PATH)
	_expect(map != null and map is OpenXRActionMap, "el action map carga")
	var names: Array = []
	var sets: Array = map.get_action_sets()
	_expect(sets.size() == 1 and sets[0].resource_name == "godot", "un set de acciones 'godot'")
	for action in sets[0].get_actions():
		names.append(str(action.resource_name))
	var used: Dictionary = {}
	var regex := RegEx.new()
	regex.compile("(?:is_button_pressed|get_vector2|get_float|_controller_button)[^&\\n]*&\"([a-z_]+)\"")
	for path in SOURCES:
		for m in regex.search_all(FileAccess.get_file_as_string(path)):
			used[m.get_string(1)] = path
	_expect(used.size() >= 5, "se detectan acciones usadas por el codigo: %s" % str(used.keys()))
	for action_name in used.keys():
		_expect(names.has(action_name), "accion usada '%s' existe en el action map" % action_name)
	for needed in ["trigger", "grip", "thumbstick", "a", "x", "menu", "haptic", "aim_pose", "grip_pose"]:
		_expect(names.has(needed), "accion basica " + needed)
	var profiles: Array = []
	for profile in map.get_interaction_profiles():
		profiles.append(str(profile.interaction_profile_path))
		var paths: Array = []
		for binding in profile.get_bindings():
			paths.append(str(binding.binding_path))
		for hand in ["left", "right"]:
			_expect(paths.has("/user/hand/%s/input/thumbstick" % hand) and paths.has("/user/hand/%s/input/trigger/value" % hand) \
				and paths.has("/user/hand/%s/input/squeeze/value" % hand), "%s: stick, gatillo y agarre en %s" % [profile.interaction_profile_path, hand])
		_expect(paths.has("/user/hand/right/input/a/click") and paths.has("/user/hand/left/input/x/click") and paths.has("/user/hand/left/input/menu/click"), "botones A/X/menu")
	_expect(profiles.has("/interaction_profiles/oculus/touch_controller") and profiles.has("/interaction_profiles/meta/touch_plus_controller"), "perfiles Touch y Touch Plus (Quest 3)")
	var rig_source: String = FileAccess.get_file_as_string("res://core/vr/vr_rig.gd")
	_expect(rig_source.contains('"tracker", &"left_hand"') and rig_source.contains('"tracker", &"right_hand"'), "trackers left_hand/right_hand")
	var build: String = FileAccess.get_file_as_string("res://tools/build_vr.sh")
	_expect(build.contains("openxr_action_map.tres"), "build_vr.sh instala el action map")
	await _end_to_end(names)
	if _fail == 0:
		print("PASS (%d assertions)" % _n)
		quit(0)
	else:
		print("FAIL (%d assertions, %d failures)" % [_n, _fail])
		quit(1)


func _end_to_end(names: Array) -> void:
	var rig = RigScript.new()
	rig.auto_process = false
	rig.move_speed = 2.0
	rig.xr_availability_override = func() -> bool: return true
	rig.floor_fix_delay = 1000.0
	root.add_child(rig)
	await process_frame
	var ws := FakeWs.new()
	root.add_child(ws)
	rig.set_weapon_system(ws)
	var left := FakeController.new()
	var right := FakeController.new()
	left.known = names
	right.known = names
	rig.left_controller.get_parent().add_child(left)
	rig.right_controller.get_parent().add_child(right)
	rig.left_controller = left
	rig.right_controller = right
	left.values["thumbstick"] = Vector2(0.0, -1.0)
	var before: Vector3 = rig.xr_origin.global_position
	rig.step(0.5)
	_expect((rig.xr_origin.global_position - before).length() > 0.9, "el stick izquierdo (accion 'thumbstick') mueve el origen XR")
	left.values["thumbstick"] = Vector2.ZERO
	right.values["trigger"] = 1.0
	rig.right_hand.weapon_id = "pistol"
	rig.right_hand.bind_weapon_system(ws)
	rig.step(0.016)
	_expect(ws.calls == 1, "el gatillo (accion 'trigger') dispara el arma en mano")
	right.values["trigger"] = 0.0
	left.values["menu"] = 1.0
	var menus := [0]
	rig.menu_pressed.connect(func(): menus[0] += 1)
	rig.step(0.016)
	_expect(menus[0] == 1, "boton menu emite menu_pressed")
	rig.queue_free()
	ws.queue_free()
