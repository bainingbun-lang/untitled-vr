extends SceneTree

# Genera res://openxr_action_map.tres con EXACTAMENTE las acciones que lee el codigo VR.
# Uso: grun <godot> --headless --path ~/UNTITLED --script res://tools/gen_action_map.gd

var HANDS: Array = ["/user/hand/left", "/user/hand/right"]
var PROFILES: Array = [
	"/interaction_profiles/oculus/touch_controller",
	"/interaction_profiles/meta/touch_plus_controller",
]
# nombre -> [tipo, ruta de entrada por mano o por una sola mano]
var ACTIONS: Array = [
	["aim_pose", 3, "Aim pose", {"both": "/input/aim/pose"}],
	["grip_pose", 3, "Grip pose", {"both": "/input/grip/pose"}],
	["trigger", 1, "Gatillo", {"both": "/input/trigger/value"}],
	["squeeze", 1, "Agarre", {"both": "/input/squeeze/value"}],
	["thumbstick", 2, "Stick", {"both": "/input/thumbstick"}],
	["thumbstick_click", 0, "Stick pulsado", {"both": "/input/thumbstick/click"}],
	["a", 0, "A", {"right": "/input/a/click"}],
	["b", 0, "B", {"right": "/input/b/click"}],
	["x", 0, "X", {"left": "/input/x/click"}],
	["y", 0, "Y", {"left": "/input/y/click"}],
	["menu", 0, "Menu", {"left": "/input/menu/click"}],
	["haptic", 4, "Haptica", {"both": "/output/haptic"}],
]


func _initialize() -> void:
	var map := OpenXRActionMap.new()
	var set_ := OpenXRActionSet.new()
	set_.resource_name = "godot"
	set_.localized_name = "Godot action set"
	set_.priority = 0
	var actions: Dictionary = {}
	for entry in ACTIONS:
		var action := OpenXRAction.new()
		action.resource_name = entry[0]
		action.localized_name = entry[2]
		action.action_type = entry[1]
		action.toplevel_paths = PackedStringArray(HANDS)
		set_.add_action(action)
		actions[entry[0]] = action
	map.add_action_set(set_)
	for profile_path in PROFILES:
		var profile := OpenXRInteractionProfile.new()
		profile.interaction_profile_path = profile_path
		var bindings: Array = []
		for entry in ACTIONS:
			var spec: Dictionary = entry[3]
			for hand in HANDS:
				var side: String = "left" if hand.ends_with("left") else "right"
				var path: String = ""
				if spec.has("both"):
					path = hand + str(spec["both"])
				elif spec.has(side):
					path = hand + str(spec[side])
				if path.is_empty():
					continue
				var binding := OpenXRIPBinding.new()
				binding.action = actions[entry[0]]
				binding.binding_path = path
				bindings.append(binding)
		profile.set_bindings(bindings)
		map.add_interaction_profile(profile)
	var err := ResourceSaver.save(map, "res://openxr_action_map.tres")
	print("GUARDADO err=%d" % err)
	quit(err)
