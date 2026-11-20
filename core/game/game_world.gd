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
const WORLD_SPAWNER_PATH: String = "res://core/game/world_spawner.gd"
const NAVIGATION_PATH: String = "res://core/npc/npc_navigation.gd"
const FACTIONS_PATH: String = "res://core/npc/npc_factions.gd"
const LOD_PATH: String = "res://core/npc/npc_lod.gd"
const CharacterModelScript = preload("res://core/game/character_model.gd")
const VoiceSystemScript = preload("res://core/game/voice_system.gd")
const GoreFxScript = preload("res://core/game/gore_fx.gd")
const VrPerformanceScript = preload("res://core/vr/vr_performance.gd")
const VrGameModeScript = preload("res://core/vr/vr_game_mode.gd")
const MapWorldBuilderScript = preload("res://core/maps/map_world_builder.gd")
const WorldSpawnerScript = preload("res://core/game/world_spawner.gd")
const NPCNavigationScript = preload("res://core/npc/npc_navigation.gd")
const NPCFactionsScript = preload("res://core/npc/npc_factions.gd")
const NPCLODScript = preload("res://core/npc/npc_lod.gd")

const DUMMY_COUNT: int = 6
const STATIC_DUMMY_COUNT: int = 2
const NAV_CELL_SIZE: float = 1.0
const PLAYER_CLEARANCE: float = 4.5

var actor: Node3D = null
var spawn_points: Array = []
var bounds: AABB = AABB()
var world_report: Dictionary = {}
var hud: Control = null
var hotbar: Control = null
var pause_menu: Node = null
var dummies: Array = []
var physics_props: Array = []
var npcs: Array = []

var navigation = null
var factions = null
var npc_lod = null
var _npcs_root: Node3D = null
var _npc_voice_mute: int = 0
var _locomotion: Dictionary = {}
var _locomotion_timer: float = 0.0
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
	for old_npc in npcs:
		if old_npc != null and is_instance_valid(old_npc):
			ArmedNpc.unregister(old_npc)
	_discard(_npcs_root)
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
	_npcs_root = null
	vr_state = null
	vr_active = false
	vr_result = {}
	spawn_points = []
	bounds = AABB()
	dummies = []
	physics_props = []
	npcs = []
	navigation = null
	factions = null
	_models.clear()
	_skins.clear()
	_impacts.clear()
	_wired.clear()
	_locomotion.clear()

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
	_build_navigation(meta)
	_spawn_living_npcs(first_point, meta)
	_spawn_dummies(first_point, meta)
	_connect_player_signals()
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
	ArmedNpc.advance_fx(maxf(delta, 0.0))
	_locomotion_timer -= maxf(delta, 0.0)
	if _locomotion_timer <= 0.0:
		_locomotion_timer = 0.2
		_sync_locomotion()
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
	if not use_vr and result is CollisionObject3D:
		result.collision_layer = 0
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
	var count: int = STATIC_DUMMY_COUNT
	if vr_active and performance != null and performance.has_method("current_profile"):
		var profile: Dictionary = performance.call("current_profile")
		count = clampi(int(profile.get("npcs", STATIC_DUMMY_COUNT)), 1, STATIC_DUMMY_COUNT)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x5EED
	for i in range(count):
		var angle := TAU * float(i) / float(maxi(count, 1)) + rng.randf_range(-0.16, 0.16)
		var radius: float = 5.0 + rng.randf_range(0.0, 1.8)
		var point := center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		point = _clamp_to_bounds(point, center)
		dummies.append(_create_dummy(point, i))
	for npc in npcs:
		if dummies.size() >= DUMMY_COUNT:
			break
		if npc != null and is_instance_valid(npc):
			dummies.append(npc)
	world_report["static_dummies"] = count
	world_report["living_npcs_exposed_as_targets"] = dummies.size() - count


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


func _build_navigation(meta: Dictionary) -> void:
	var origin: Vector3 = bounds.position
	var width: int = maxi(1, ceili(bounds.size.x / NAV_CELL_SIZE))
	var height: int = maxi(1, ceili(bounds.size.z / NAV_CELL_SIZE))
	var blocked: Dictionary = {}
	if _geometry_root != null:
		for body in _geometry_root.find_children("*", "CollisionObject3D", true, false):
			if str((body as Node).name) == "Ground":
				continue
			var box: AABB = _collision_box(body as Node3D)
			if box.size.x > 0.0 and box.size.z > 0.0:
				_mark_blocked(blocked, box, origin, width, height, 0.55)
	for prop in physics_props:
		if not (prop is Node3D) or not is_instance_valid(prop):
			continue
		var box: AABB = _collision_box(prop as Node3D)
		if box.size.x <= 0.0 or box.size.z <= 0.0:
			continue
		_mark_blocked(blocked, box, origin, width, height, 0.45)
	navigation = NPCNavigationScript.new(width, height, blocked.keys(), {
		"origin": Vector2(origin.x, origin.z),
		"max_expansions": 4096,
	})
	npc_lod = NPCLODScript.new()
	var decision: String = "NpcNavigation con rejilla de 1m derivada de colisiones reales del builder; "
	decision += "celdas marcadas con margen 0.55 (0.45 props) para no atravesar paredes ni obstaculos; "
	decision += "el origen coincide con bounds.position y se guarda como Vector2(x,z) para pasar coordenadas mundo."
	world_report["navigation"] = {
		"decision": decision,
		"width": width, "height": height, "cell_size": NAV_CELL_SIZE,
		"origin": Vector2(origin.x, origin.z), "blocked_cells": blocked.size(),
		"meta_seed": int(meta.get("seed", 0)),
	}


func _collision_box(body: Node3D) -> AABB:
	if body == null or not is_instance_valid(body):
		return AABB()
	for child in body.find_children("*", "CollisionShape3D", true, false):
		var shape_node := child as CollisionShape3D
		if shape_node == null or shape_node.shape == null:
			continue
		if shape_node.shape is BoxShape3D:
			var size: Vector3 = (shape_node.shape as BoxShape3D).size
			var center: Vector3 = body.global_position + shape_node.position
			return AABB(center - size * 0.5, size)
	var raw: AABB = body.get_aabb() if body.has_method("get_aabb") else AABB()
	return raw


func _mark_blocked(
	blocked: Dictionary, box: AABB, origin: Vector3,
	width: int, height: int, margin: float
) -> void:
	var min_x: int = maxi(0, floori((box.position.x - margin - origin.x) / NAV_CELL_SIZE))
	var max_x: int = mini(width - 1, ceili((box.end.x + margin - origin.x) / NAV_CELL_SIZE))
	var min_y: int = maxi(0, floori((box.position.z - margin - origin.z) / NAV_CELL_SIZE))
	var max_y: int = mini(height - 1, ceili((box.end.z + margin - origin.z) / NAV_CELL_SIZE))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			blocked[Vector2i(x, y)] = true


func _spawn_living_npcs(center: Vector3, meta: Dictionary) -> void:
	_npcs_root = Node3D.new()
	_npcs_root.name = "LivingNPCs"
	add_child(_npcs_root)
	if navigation == null:
		return
	var platform: String = _session_platform()
	if platform.is_empty():
		platform = ArmedNpc.detect_platform()
	var capacity: int = ArmedNpc.max_active(platform)
	var wanted: int = mini(capacity, 16)
	var meta_limit: int = maxi(0, int(meta.get("max_npcs", 0)))
	if meta_limit > 0:
		wanted = mini(wanted, meta_limit)
	if capacity >= 6:
		wanted = maxi(wanted, 6)
	wanted = mini(wanted, capacity)
	if wanted <= 0:
		return
	var candidates: Array = _free_navigation_points(center)
	if candidates.is_empty():
		return
	var seed_value: int = int(meta.get("seed", 4242))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0xA11CE
	candidates.shuffle()
	var selected: Array = []
	var min_gap: float = 1.7
	for point in candidates:
		if selected.size() >= wanted:
			break
		var valid: bool = true
		for other in selected:
			if point.distance_to(other as Vector3) < min_gap:
				valid = false
				break
		if valid:
			selected.append(point)
	if selected.size() < wanted:
		for point in candidates:
			if selected.size() >= wanted:
				break
			if not selected.has(point):
				selected.append(point)
	if selected.is_empty():
		return
	factions = NPCFactionsScript.new({})
	for id in ["civilian", "criminal", "police", "zombie"]:
		factions.call("register_faction", id, id)
	factions.call("set_relation", "police", "criminal", -85.0)
	factions.call("set_relation", "civilian", "criminal", -70.0)
	factions.call("set_relation", "civilian", "zombie", -90.0)
	factions.call("set_relation", "police", "zombie", -90.0)
	factions.call("set_relation", "criminal", "civilian", -45.0)
	factions.call("set_relation", "zombie", "civilian", -95.0)

	var roles: Array = ["hostile", "civilian", "defender", "zombie", "hostile", "civilian", "zombie", "defender"]
	var weapons: Dictionary = {
		"hostile": "assault_rifle", "defender": "pistol",
		"civilian": "pistol", "zombie": "",
	}
	var faction_by_role: Dictionary = {
		"hostile": "criminal", "defender": "police",
		"civilian": "civilian", "zombie": "zombie",
	}
	var defs: Array = []
	for i in range(wanted):
		var role: String = str(roles[i % roles.size()])
		var personality: Dictionary = {
			"temperament": rng.randf_range(0.2, 0.9),
			"confidence": rng.randf_range(0.2, 0.9),
			"bravery": rng.randf_range(0.2, 0.95),
			"fear": rng.randf_range(0.1, 0.7),
			"curiosity": rng.randf_range(0.2, 0.8),
			"sociability": rng.randf_range(0.1, 0.8),
			"aggressiveness": rng.randf_range(0.2, 0.95) if role != "civilian" else 0.05,
		}
		var needs: Dictionary = {"fatigue": 0.2, "stress": 0.1, "fear": 0.1, "confusion": 0.0, "stun": 0.0, "health": 1.0}
		defs.append({
			"id": "npc_%02d" % i,
			"role": role,
			"faction": faction_by_role[role],
			"weapon": weapons[role],
			"personality": personality,
			"needs": needs,
			"routine": [],
			"state": "idle",
		})
	var spawn_meta: Dictionary = {
		"spawn_points": selected,
		"platforms": [platform],
		"performance_profiles": {platform: {"max_npcs": wanted}},
	}
	var spawner = WorldSpawnerScript.new()
	var report: Dictionary = spawner.call("spawn", spawn_meta, defs, seed_value)
	for entry in report.get("spawned", []):
		var def: Dictionary = defs[int(entry.get("index", 0))]
		var role: String = str(def["role"])
		var npc_id: String = str(entry["id"])
		var point: Vector3 = entry["position"]
		factions.call("set_member", npc_id, str(def["faction"]))
		var options: Dictionary = {
			"id": npc_id, "npc_id": npc_id,
			"role": role, "faction_id": str(def["faction"]),
			"weapon_id": str(def["weapon"]),
			"difficulty": "normal", "seed": seed_value + int(entry.get("index", 0)) * 17,
			"platform": platform, "target": actor, "target_id": "player",
			"navigation": navigation, "observer": self, "fx_parent": self,
			"bounds": bounds, "nav_cell_size": NAV_CELL_SIZE, "lod": npc_lod,
			"factions": factions, "patrol_points": selected,
			"attack_points": selected, "cover_points": selected,
			"tick_rate": 12.0, "vision_range": 18.0 if role != "zombie" else 14.0,
			"patrol_speed": 2.0 if role != "zombie" else 3.2,
			"run_speed": 5.5 if role != "zombie" else 6.4,
			"drop_weapon_on_death": role != "zombie",
		}
		var npc: Node3D = ArmedNpc.spawn(_npcs_root, point, options) as Node3D
		if npc == null:
			continue
		_attach_character_model(npc, _skin_for_role(role), "npc_%s" % npc_id)
		npcs.append(npc)
	var role_counts: Dictionary = {}
	for npc in npcs:
		var role: String = str(npc.get("role"))
		role_counts[role] = int(role_counts.get(role, 0)) + 1
	world_report["ai"] = {
		"platform": platform, "requested": wanted, "spawned": npcs.size(),
		"rejected": (report.get("rejected", []) as Array).size(),
		"rejection_reason": _first_rejection(report),
		"roles": role_counts, "factions": factions.call("faction_ids"),
		"tick_hz": 12.0, "lod": true, "subtitles_by_default": false,
	}


func _first_rejection(report: Dictionary) -> String:
	var rejected: Array = report.get("rejected", [])
	if rejected.is_empty():
		return ""
	var first: Variant = rejected[0]
	if first is Dictionary:
		return str((first as Dictionary).get("reason", ""))
	return str(first)


func _free_navigation_points(center: Vector3) -> Array:
	var result: Array = []
	if navigation == null:
		return result
	var width: int = int(navigation.get("width"))
	var height: int = int(navigation.get("height"))
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			if bool(navigation.call("is_blocked", cell)):
				continue
			var point: Vector3 = navigation.call("cell_to_world", cell, NAV_CELL_SIZE, 0.0)
			if point.distance_to(center) < PLAYER_CLEARANCE:
				continue
			result.append(point)
	return result


func _skin_for_role(role: String) -> String:
	var manifest: Dictionary = _role_skin_manifest()
	var key: String = role.strip_edges().to_lower()
	if manifest.has(key):
		var entry: Variant = manifest[key]
		if entry is String and not str(entry).is_empty():
			return str(entry)
		if entry is Dictionary:
			for field in ["skin", "model", "id", "character"]:
				if (entry as Dictionary).has(field):
					var value: String = str((entry as Dictionary)[field])
					if not value.is_empty():
						return value
	match key:
		"civilian", "civil", "pacifist":
			return "civil"
		"defender", "police", "guard":
			return "soldier"
		"zombie", "zombi", "infectado":
			return "enemy"
		_:
			return "enemy"


func _role_skin_manifest() -> Dictionary:
	var path: String = "res://assets/models/characters/v2/manifest.json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Dictionary) if parsed is Dictionary else {}


func _connect_player_signals() -> void:
	if actor == null:
		return
	_connect_once(actor, "fired", Callable(self, "_on_player_fired"))
	_connect_once(actor, "weapon_changed", Callable(self, "_on_player_weapon_changed"))


func _on_player_fired(result: Dictionary) -> void:
	if actor == null:
		return
	var position: Variant = result.get("position", null)
	var origin: Vector3 = position if position is Vector3 else actor.global_position
	for npc in npcs:
		if npc != null and is_instance_valid(npc) and npc.has_method("hear_gunshot"):
			npc.call("hear_gunshot", origin, 1.0, str(actor.name))


func _on_player_weapon_changed(_item_id) -> void:
	if actor == null:
		return
	for npc in npcs:
		if npc != null and is_instance_valid(npc) and npc.has_method("notice_weapon"):
			npc.call("notice_weapon", actor.global_position)


func _attach_character_model(target: Node3D, skin: String, voice_id: String) -> Node3D:
	if target == null or not is_instance_valid(target):
		return null
	var model: Node3D = CharacterModelScript.spawn(target, skin) as Node3D
	if model == null or not bool(model.call("is_loaded")):
		if model != null:
			model.queue_free()
		return null
	var weapon_mount: Node = target.get_node_or_null("WeaponMount")
	for mesh in target.find_children("*", "MeshInstance3D", true, false):
		if not model.is_ancestor_of(mesh) and (weapon_mount == null or not weapon_mount.is_ancestor_of(mesh)):
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
		var target := dummy as Node3D
		if target == null or target.is_in_group("armed_npc"):
			continue
		_wire_target(target, "dummy_%d" % int(dummy.get("dummy_id")))
	_wire_existing_npcs()


func _wire_existing_npcs() -> void:
	for raw in get_tree().get_nodes_in_group("armed_npc"):
		var npc := raw as Node3D
		if npc == null or not is_instance_valid(npc):
			continue
		var key: String = "npc_%s" % str(npc.get("npc_id"))
		if _model_for(npc) == null:
			var role: String = str(npc.get("role"))
			_attach_character_model(npc, _skin_for_role(role), key)
		if npc.has_method("apply_options"):
			npc.call("apply_options", {
				"navigation": navigation,
				"observer": self,
				"fx_parent": self,
				"bounds": bounds,
				"nav_cell_size": NAV_CELL_SIZE,
				"lod": npc_lod,
			})
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
	if _npc_voice_mute > 0:
		return
	if vr_state != null and is_instance_valid(vr_state) and vr_state.has_method("show_subtitle"):
		vr_state.call("show_subtitle", text, npc)
	elif hud != null and hud.has_method("show_subtitle"):
		hud.call("show_subtitle", text, npc)


func _play_npc_voice(voice_id: String, cue: String, state: Dictionary = {}) -> void:
	if voice == null or not voice.has_method("play_cue"):
		return
	if not state.is_empty() and voice.has_method("set_npc_state"):
		voice.call("set_npc_state", voice_id, state)
	_npc_voice_mute += 1
	voice.call("play_cue", voice_id, cue)
	_npc_voice_mute -= 1


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
		if target.is_in_group("armed_npc"):
			_play_npc_voice(voice_id, "pain", {"health": clampf(hp, 0.0, 100.0), "fear": 0.4})
		else:
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
	var is_living_npc: bool = target.is_in_group("armed_npc")
	if not is_living_npc:
		GoreFxScript.on_death(self, point, 0.8)
	if voice != null and voice.has_method("play_cue"):
		var previous_cooldown: float = float(voice.get("cooldown"))
		voice.call("set_npc_state", voice_id, {"health": 0.0})
		voice.call("set_cooldown", 0.0)
		if is_living_npc:
			_npc_voice_mute += 1
			voice.call("play_cue", voice_id, "death")
			_npc_voice_mute -= 1
		else:
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


func _on_npc_action_changed(action: String, target: Node3D, voice_id: String) -> void:
	var model := _model_for(target)
	var anim := "idle"
	match action:
		"patrol", "move", "walk", "investigate":
			anim = "walk"
		"flee", "run":
			anim = "run"
		"aim", "attack":
			anim = "aim"
		"reload":
			anim = "hit"
	if model != null:
		model.call("play", anim, anim != "aim")
	_locomotion[target.get_instance_id()] = anim
	match action:
		"investigate":
			_play_npc_voice(voice_id, "alert")
		"flee":
			_play_npc_voice(voice_id, "fear")
		"attack":
			_play_npc_voice(voice_id, "effort")


func _on_npc_fired(_result: Dictionary, target: Node3D, _voice_id: String) -> void:
	var model := _model_for(target)
	if model != null:
		model.call("play", "shoot", false)


func _sync_locomotion() -> void:
	for npc in npcs:
		if npc == null or not is_instance_valid(npc) or (npc.has_method("is_dead") and bool(npc.call("is_dead"))):
			continue
		var distance: float = global_position.distance_to(npc.global_position)
		if npc_lod != null and distance > 50.0:
			continue
		var model := _model_for(npc)
		if model == null:
			continue
		var speed: float = Vector2(npc.velocity.x, npc.velocity.z).length()
		var anim: String = "run" if speed > 4.0 else ("walk" if speed > 0.4 else "idle")
		var key: int = npc.get_instance_id()
		if str(_locomotion.get(key, "")) != anim:
			_locomotion[key] = anim
			model.call("play", anim, true)


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
