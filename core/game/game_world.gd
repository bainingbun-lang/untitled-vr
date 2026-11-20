class_name GameWorld
extends Node3D

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const SESSION_SCRIPT: String = "res://core/game/game_session.gd"
const HOTBAR_SCENE: String = "res://scenes/ui/hotbar.tscn"
const HUD_SCRIPT: String = "res://core/game/game_hud.gd"
const DUMMY_SCRIPT: String = "res://core/game/target_dummy.gd"
const PAUSE_MENU_SCRIPT: String = "res://core/game/pause_menu.gd"
const CHARACTER_MODEL_PATH: String = "res://core/game/character_model.gd"
const VOICE_SYSTEM_PATH: String = "res://core/game/voice_system.gd"
const GORE_FX_PATH: String = "res://core/game/gore_fx.gd"
const VR_PERFORMANCE_PATH: String = "res://core/vr/vr_performance.gd"
const VR_GAME_MODE_PATH: String = "res://core/vr/vr_game_mode.gd"
const ARMED_NPC_PATH: String = "res://core/game/armed_npc.gd"
const CharacterModelScript = preload("res://core/game/character_model.gd")
const VoiceSystemScript = preload("res://core/game/voice_system.gd")
const GoreFxScript = preload("res://core/game/gore_fx.gd")
const VrPerformanceScript = preload("res://core/vr/vr_performance.gd")
const VrGameModeScript = preload("res://core/vr/vr_game_mode.gd")
const MapWorldBuilderScript = preload("res://core/maps/map_world_builder.gd")

const DUMMY_COUNT: int = 6

var actor: Node3D = null
var spawn_points: Array = []
var bounds: AABB = AABB()
var world_report: Dictionary = {}
var hud: Control = null
var hotbar: Control = null
var pause_menu: Node = null
var dummies: Array = []
var physics_props: Array = []

var _geometry_root: Node3D = null
var _hud_layer: CanvasLayer = null
var _dummies_root: Node3D = null
var _syncing_hotbar := false
var voice: Node = null
var performance: Node = null
var vr_state: Node = null
var vr_active: bool = false
var vr_result: Dictionary = {}
var _models: Dictionary = {}
var _skins: Dictionary = {}
var _impacts: Dictionary = {}
var _wired: Dictionary = {}
var _npc_scan_timer := 0.0


func _ready() -> void:
	var session := _safe_script(SESSION_SCRIPT)
	if session != null and str(session.get("platform")).is_empty() and session.has_method("detect_platform"):
		session.set("platform", session.call("detect_platform"))
	if world_report.is_empty():
		setup(_session_meta())


func setup(meta: Dictionary) -> void:
	_discard(_geometry_root)
	_discard(actor)
	_discard(_hud_layer)
	_discard(_dummies_root)
	for key in vr_result.keys():
		var old_node: Variant = vr_result.get(key)
		if old_node is Node:
			_discard(old_node as Node)
	_geometry_root = null
	actor = null
	hud = null
	hotbar = null
	pause_menu = null
	_dummies_root = null
	vr_state = null
	vr_active = false
	vr_result = {}
	spawn_points = []
	bounds = AABB()
	dummies = []
	physics_props = []

	world_report = MapWorldBuilderScript.build(meta, self)
	var first_point: Vector3 = Vector3.ZERO
	if not bool(world_report.get("ok", false)):
		actor = _create_actor(first_point)
	else:
		spawn_points = (world_report.get("spawn_points", []) as Array).duplicate()
		bounds = world_report.get("bounds", AABB())
		_geometry_root = get_node_or_null("WorldGeometry") as Node3D
		if not spawn_points.is_empty():
			first_point = spawn_points[0]
		actor = _create_actor(first_point)
	vr_active = actor != null and actor.has_method("is_active") and bool(actor.call("is_active"))
	if vr_active:
		vr_result = VrGameModeScript.setup(self, actor, meta)
		vr_state = vr_result.get("state", null) as Node

	_collect_physics_props()
	_setup_performance()
	_setup_voice()
	_spawn_dummies(first_point, meta)
	if not vr_active:
		_setup_hud()
		_setup_hotbar()
		_setup_pause_menu()
		_auto_equip()
		if actor != null and actor.has_signal("menu_pressed"):
			var callable := Callable(self, "_on_menu_pressed")
			if not actor.is_connected("menu_pressed", callable):
				actor.connect("menu_pressed", callable)
	_wire_targets()


func _process(delta: float) -> void:
	if vr_state != null and is_instance_valid(vr_state) and vr_state.has_method("tick"):
		vr_state.call("tick", maxf(delta, 0.0))
	if performance != null and is_instance_valid(performance) and performance.has_method("observe_frame"):
		var report: Variant = performance.call("observe_frame", maxf(delta, 0.0) * 1000.0, delta)
		if report is Dictionary and bool((report as Dictionary).get("changed", false)):
			GoreFxScript.apply_profile((report as Dictionary).get("profile", {}))
	_npc_scan_timer -= maxf(delta, 0.0)
	if _npc_scan_timer <= 0.0:
		_npc_scan_timer = 0.5
		_wire_existing_npcs()


func spawn_point_positions() -> Array:
	return spawn_points.duplicate()


func target_dummies() -> Array:
	return dummies.duplicate()


func props() -> Array:
	return physics_props.duplicate()


func _create_actor(spawn: Vector3) -> Node3D:
	var use_vr: bool = _session_platform() == "vr" and VrGameModeScript.xr_available()
	var result := VrGameModeScript.build(self, use_vr)
	if result == null:
		return null
	result.global_position = spawn
	if not use_vr and result is Camera3D:
		result.look_at(spawn + Vector3(0.0, 1.0, 0.0))
	return result


func _session_platform() -> String:
	var session := _safe_script(SESSION_SCRIPT)
	if session == null:
		return ""
	var platform: String = str(session.get("platform"))
	if platform.is_empty() and session.has_method("detect_platform"):
		platform = str(session.call("detect_platform"))
		session.set("platform", platform)
	return platform


func _collect_physics_props() -> void:
	physics_props = []
	for node in get_tree().get_nodes_in_group("physics_props"):
		if node.is_ancestor_of(self) or self.is_ancestor_of(node):
			physics_props.append(node)


func _spawn_dummies(center: Vector3, meta: Dictionary) -> void:
	_dummies_root = Node3D.new()
	_dummies_root.name = "Dummies"
	add_child(_dummies_root)
	var session := _safe_script(SESSION_SCRIPT)
	var fallback_seed: int = int(session.get("seed")) if session != null else 0
	var seed_value: int = int(meta.get("seed", fallback_seed))
	var count: int = DUMMY_COUNT
	if vr_active and performance != null and performance.has_method("current_profile"):
		var profile: Dictionary = performance.call("current_profile")
		count = clampi(int(profile.get("npcs", DUMMY_COUNT)), 1, DUMMY_COUNT)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x5EED
	for i in range(count):
		var angle := TAU * float(i) / float(maxi(count, 1)) + rng.randf_range(-0.16, 0.16)
		var radius: float = 5.0 + rng.randf_range(0.0, 1.8)
		var point := center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		point = _clamp_to_bounds(point, center)
		dummies.append(_create_dummy(point, i))


func _create_dummy(point: Vector3, id: int) -> Node3D:
	var script := _safe_script(DUMMY_SCRIPT)
	var dummy: Node3D
	if script != null:
		dummy = script.new() as Node3D
	if dummy == null:
		dummy = Node3D.new()
	dummy.name = "TargetDummy_%d" % id
	if "dummy_id" in dummy:
		dummy.set("dummy_id", id)
	_dummies_root.add_child(dummy)
	dummy.global_position = point
	var skins: Array = ["enemy", "civil", "soldier", "robot"]
	_attach_character_model(dummy, str(skins[id % skins.size()]), "dummy_%d" % id)
	return dummy


func _clamp_to_bounds(point: Vector3, fallback_center: Vector3) -> Vector3:
	var result := point
	if bounds.size.x > 0.0 and bounds.size.z > 0.0:
		var inset_x: float = mini(1.5, bounds.size.x * 0.25)
		var inset_z: float = mini(1.5, bounds.size.z * 0.25)
		result.x = clampf(result.x, bounds.position.x + inset_x, bounds.end.x - inset_x)
		result.z = clampf(result.z, bounds.position.z + inset_z, bounds.end.z - inset_z)
	if result.distance_to(fallback_center) < 3.0:
		var direction: Vector3 = result - fallback_center
		if direction.length_squared() < 0.0001:
			direction = Vector3.FORWARD
		result = fallback_center + direction.normalized() * 4.0
	result.y = fallback_center.y
	return result


func _setup_performance() -> void:
	var node: Node = VrPerformanceScript.new()
	if node == null:
		return
	performance = node
	node.name = "VrPerformance"
	add_child(node)
	if node.has_method("build"):
		node.call("build")
	if node.has_method("set_target_mode"):
		node.call("set_target_mode", VrPerformanceScript.MODE_72)
	var profile: Dictionary = node.call("current_profile") if node.has_method("current_profile") else {}
	GoreFxScript.apply_profile(profile)
	var npc_script := _safe_script(ARMED_NPC_PATH)
	if npc_script != null and profile.has("npcs"):
		var limits: Variant = npc_script.get("limits_override")
		var session := _safe_script(SESSION_SCRIPT)
		var platform: String = str(session.get("platform")) if session != null else "pc"
		if platform.is_empty():
			platform = "pc"
		if limits is Dictionary and platform in ["android", "pc", "vr"]:
			(limits as Dictionary)[platform] = clampi(int(profile["npcs"]), 1, 32)


func _setup_voice() -> void:
	var node: Node = VoiceSystemScript.new()
	if node == null:
		return
	voice = node
	node.name = "VoiceSystem"
	add_child(node)
	if node.has_signal("subtitle"):
		_connect_once(node, "subtitle", Callable(self, "_on_voice_subtitle"))


func _attach_character_model(target: Node3D, skin: String, voice_id: String) -> Node3D:
	if target == null or not is_instance_valid(target):
		return null
	var model: Node3D = CharacterModelScript.spawn(target, skin) as Node3D
	if model == null or not bool(model.call("is_loaded")):
		if model != null:
			model.queue_free()
		return null
	for mesh in target.find_children("*", "MeshInstance3D", true, false):
		if not model.is_ancestor_of(mesh):
			(mesh as MeshInstance3D).visible = false
	model.call("play", "idle")
	_models[target.get_instance_id()] = model
	_skins[target.get_instance_id()] = skin
	if voice != null and voice.has_method("register_npc"):
		voice.call("register_npc", voice_id, {"seed": absi(voice_id.hash()), "health": 100.0})
	return model


func _model_for(target: Node) -> Node3D:
	if target == null:
		return null
	var node: Variant = _models.get(target.get_instance_id(), null)
	if node is Node3D and is_instance_valid(node):
		return node as Node3D
	return null


func _wire_targets() -> void:
	for dummy in dummies:
		_wire_target(dummy as Node3D, "dummy_%d" % int(dummy.get("dummy_id")))
	_wire_existing_npcs()


func _wire_existing_npcs() -> void:
	for raw in get_tree().get_nodes_in_group("armed_npc"):
		var npc := raw as Node3D
		if npc == null or not is_instance_valid(npc):
			continue
		var key: String = "npc_%s" % str(npc.get("npc_id"))
		if _model_for(npc) == null:
			var role: String = str(npc.get("role"))
			var skin: String = "enemy" if role == "hostile" else ("civil" if role == "civilian" else "soldier")
			_attach_character_model(npc, skin, key)
		_wire_target(npc, key)
		_connect_once(npc, "action_changed", Callable(self, "_on_npc_action_changed").bind(npc, key))
		_connect_once(npc, "fired", Callable(self, "_on_npc_fired").bind(npc, key))


func _wire_target(target: Node3D, voice_id: String) -> void:
	if target == null:
		return
	var key := "%d|%s" % [target.get_instance_id(), voice_id]
	if _wired.has(key):
		return
	_wired[key] = true
	_connect_once(target, "damaged", Callable(self, "_on_target_damaged").bind(target, voice_id))
	_connect_once(target, "died", Callable(self, "_on_dummy_died").bind(target, voice_id))
	_connect_once(target, "respawned", Callable(self, "_on_target_respawned").bind(target, voice_id))
	_connect_once(target, "died_from", Callable(self, "_on_npc_died").bind(target, voice_id))


func _connect_once(target: Node, signal_name: String, callable: Callable) -> void:
	if target != null and target.has_signal(signal_name) and not target.is_connected(signal_name, callable):
		target.connect(signal_name, callable)


func _on_voice_subtitle(text: String, npc: String) -> void:
	if vr_state != null and is_instance_valid(vr_state) and vr_state.has_method("show_subtitle"):
		vr_state.call("show_subtitle", text, npc)
	elif hud != null and hud.has_method("show_subtitle"):
		hud.call("show_subtitle", text, npc)


func _on_target_damaged(amount: float, point: Vector3, normal: Vector3, target: Node3D, voice_id: String) -> void:
	_impacts[target.get_instance_id()] = {
		"point": point, "normal": normal, "amount": amount,
	}
	var model := _model_for(target)
	if model != null:
		model.call("play", "hit", false)
		model.call("apply_wound", "torso", normal, clampf(0.05 + amount * 0.002, 0.05, 0.3))
	if voice != null and voice.has_method("play_cue"):
		var hp: float = float(target.call("health")) if target.has_method("health") else 50.0
		voice.call("set_npc_state", voice_id, {"health": clampf(hp, 0.0, 100.0), "fear": 0.4})
		voice.call("play_cue", voice_id, "pain")


func _on_dummy_died(target: Node3D, voice_id: String) -> void:
	_finish_target_death(target, voice_id)


func _on_npc_died(_source: Node, target: Node3D, voice_id: String) -> void:
	_finish_target_death(target, voice_id)


func _finish_target_death(target: Node3D, voice_id: String) -> void:
	if target == null:
		return
	var impact: Dictionary = _impacts.get(target.get_instance_id(), {})
	var point: Vector3 = impact.get("point", target.global_position + Vector3.UP)
	var normal: Vector3 = impact.get("normal", Vector3.FORWARD)
	var amount: float = float(impact.get("amount", 40.0))
	var direction: Vector3 = -normal if normal.length_squared() > 0.0001 else -target.global_transform.basis.z
	var impulse: Vector3 = direction.normalized() * clampf(4.0 + amount * 0.2, 4.0, 24.0)
	var model := _model_for(target)
	if model != null:
		model.call("play", "die", false)
		model.call("make_ragdoll", impulse, point)
		model.call("detach_limb", "arm.r")
	GoreFxScript.on_death(self, point, 0.8)
	if voice != null and voice.has_method("play_cue"):
		voice.call("set_npc_state", voice_id, {"health": 0.0})
		var previous_cooldown: float = float(voice.get("cooldown"))
		voice.call("set_cooldown", 0.0)
		voice.call("play_cue", voice_id, "death")
		voice.call("set_cooldown", previous_cooldown)


func _on_target_respawned(target: Node3D, voice_id: String) -> void:
	var old: Variant = _models.get(target.get_instance_id(), null)
	if old is Node3D and is_instance_valid(old):
		_models.erase(target.get_instance_id())
		(old as Node3D).queue_free()
	var skin: String = str(_skins.get(target.get_instance_id(), "enemy"))
	_attach_character_model(target, skin, voice_id)
	_impacts.erase(target.get_instance_id())


func _on_npc_action_changed(action: String, target: Node3D, _voice_id: String) -> void:
	var model := _model_for(target)
	if model == null:
		return
	var anim := "idle"
	match action:
		"patrol", "move", "walk":
			anim = "walk"
		"flee", "run":
			anim = "run"
		"aim", "attack":
			anim = "aim"
		"reload":
			anim = "hit"
	model.call("play", anim, anim != "aim")


func _on_npc_fired(_result: Dictionary, target: Node3D, _voice_id: String) -> void:
	var model := _model_for(target)
	if model != null:
		model.call("play", "shoot", false)


func _setup_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HudLayer"
	_hud_layer.layer = 10
	add_child(_hud_layer)
	var script := _safe_script(HUD_SCRIPT)
	hud = script.new() as Control if script != null else null
	if hud == null:
		hud = Control.new()
	hud.name = "GameHud"
	_hud_layer.add_child(hud)
	hud.setup(actor)


func _setup_hotbar() -> void:
	if not ResourceLoader.exists(HOTBAR_SCENE):
		return
	var packed := load(HOTBAR_SCENE) as PackedScene
	if packed == null:
		return
	var instance := packed.instantiate()
	if not (instance is Control):
		if instance != null:
			instance.queue_free()
		return
	hotbar = instance as Control
	hotbar.name = "Hotbar"
	_hud_layer.add_child(hotbar)
	if hotbar.has_method("setup") and actor != null:
		hotbar.call("setup", actor.get("inventory"), actor.get("item_db"))
	if hotbar.has_signal("selected"):
		var callable := Callable(self, "_on_hotbar_selected")
		if not hotbar.is_connected("selected", callable):
			hotbar.connect("selected", callable)
	if actor != null and actor.has_signal("weapon_changed") and hotbar.has_method("select_id"):
		var to_hotbar := Callable(self, "_on_actor_weapon_changed")
		if not actor.is_connected("weapon_changed", to_hotbar):
			actor.connect("weapon_changed", to_hotbar)
	if hotbar.has_method("select") and hotbar.has_method("weapon_ids"):
		var ids: Array = hotbar.call("weapon_ids")
		if not ids.is_empty():
			hotbar.call("select", 0)


func _setup_pause_menu() -> void:
	if not ResourceLoader.exists(PAUSE_MENU_SCRIPT):
		return
	var script := load(PAUSE_MENU_SCRIPT) as Script
	if script == null:
		return
	var instance = script.new()
	if not (instance is Node):
		return
	pause_menu = instance as Node
	pause_menu.name = "PauseMenu"
	_hud_layer.add_child(pause_menu)
	if pause_menu.has_method("setup"):
		pause_menu.call("setup", self, actor)


func _auto_equip() -> void:
	if actor == null or not actor.has_method("weapon_ids") or not actor.has_method("equip"):
		return
	var ids: Array = actor.call("weapon_ids")
	if not ids.is_empty():
		actor.call("equip", str(ids[0]))


func _on_menu_pressed() -> void:
	if vr_state != null and is_instance_valid(vr_state) and vr_state.has_method("toggle_menu"):
		vr_state.call("toggle_menu")
		return
	if pause_menu == null or not is_instance_valid(pause_menu):
		return
	if pause_menu.has_method("open"):
		pause_menu.call("open")
	elif pause_menu.has_method("show_menu"):
		pause_menu.call("show_menu")
	elif "visible" in pause_menu:
		pause_menu.set("visible", true)


func _on_hotbar_selected(item_id: String) -> void:
	if _syncing_hotbar or actor == null or not actor.has_method("equip"):
		return
	actor.call("equip", item_id)


func _on_actor_weapon_changed(item_id) -> void:
	if hotbar == null or not hotbar.has_method("select_id"):
		return
	_syncing_hotbar = true
	hotbar.call("select_id", str(item_id))
	_syncing_hotbar = false


func _discard(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()


func _safe_script(path: String) -> Script:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Script


func _session_meta() -> Dictionary:
	if not ResourceLoader.exists(SESSION_SCRIPT):
		return {}
	var script: Script = load(SESSION_SCRIPT) as Script
	if script == null:
		return {}
	var value: Variant = script.get("map_meta")
	if value is Dictionary:
		return (value as Dictionary).duplicate()
	return {}
