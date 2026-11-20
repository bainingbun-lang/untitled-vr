class_name ArmedNpc
extends CharacterBody3D

signal action_changed(action: String)
signal fired(result: Dictionary)
signal died_from(source: Node)
signal weapon_dropped(weapon: Node3D)
signal called_for_help(source_id: String)

const COMBAT_PATH: String = "res://core/npc/npc_combat.gd"
const DAMAGEABLE_PATH: String = "res://core/game/damageable.gd"
const WEAPON_SYSTEM_PATH: String = "res://core/game/weapon_system.gd"
const WEAPON_DB_PATH: String = "res://core/game/weapon_db.gd"
const GORE_FX_PATH: String = "res://core/game/gore_fx.gd"
const SESSION_PATH: String = "res://core/game/game_session.gd"
const PERCEPTION_PATH: String = "res://core/npc/npc_perception.gd"
const NAVIGATION_PATH: String = "res://core/npc/npc_navigation.gd"
const RELATIONS_PATH: String = "res://core/npc/npc_relations.gd"
const FACTIONS_PATH: String = "res://core/npc/npc_factions.gd"
const LOD_PATH: String = "res://core/npc/npc_lod.gd"
const WEAPON_VIEWMODEL_PATH: String = "res://core/game/weapon_viewmodel.gd"
const MUZZLE_FX_PATH: String = "res://core/game/muzzle_fx.gd"
const RECORDED_SFX_PATH: String = "res://core/game/recorded_sfx.gd"
const SFX_BANK_PATH: String = "res://core/game/sfx_bank.gd"
const AUDIO_SYNTH_PATH: String = "res://core/game/audio_synth.gd"

const MAX_TRACERS: int = 12
const TRACER_LIFE: float = 0.09
const MELEE_RANGE: float = 1.8
const MELEE_DAMAGE: float = 32.0

const PLATFORM_LIMITS: Dictionary = {"android": 8, "pc": 16, "vr": 10}
const DEFAULT_LIMIT: int = 8
const PLATFORM_ALIASES: Dictionary = {
	"android": "android", "mobile": "android", "movil": "android", "celular": "android",
	"pc": "pc", "windows": "pc", "desktop": "pc", "linux": "pc", "escritorio": "pc",
	"vr": "vr", "quest": "vr", "oculus": "vr",
}

static var _active: Array = []
static var limits_override: Dictionary = {}
static var _tracers: Array = []
static var _tracer_material: StandardMaterial3D = null
static var _tracer_mesh: BoxMesh = null

@export var npc_id: String = "npc"
@export var faction_id: String = ""
@export var weapon_id: String = "pistol"
@export var role: String = "hostile"
@export var difficulty: String = "normal"
@export var seed_value: int = 1337
@export var max_health: float = 100.0
@export var vision_range: float = 18.0
@export var patrol_speed: float = 2.0
@export var run_speed: float = 5.5
@export var spread_scale: float = 1.0
@export var drop_weapon_on_death: bool = true
@export var auto_tick: bool = true

var combat = null
var damageable = null
var weapon_system = null
var perception = null
var navigation = null
var relations = null
var factions = null
var target: Node3D = null
var target_id: String = "player"
var aim_point: Vector3 = Vector3.ZERO
var has_explicit_aim: bool = false
var death_report: Dictionary = {}
var spawn_accepted: bool = false
var platform: String = ""

var collision: CollisionShape3D = null
var visual: MeshInstance3D = null
var head_visual: MeshInstance3D = null
var weapon_visual: MeshInstance3D = null
var weapon_mount: Node3D = null

var _built: bool = false
var _dead: bool = false
var _pending_options: Dictionary = {}
var _last_impact_direction: Vector3 = Vector3.FORWARD
var _last_impact_force: float = 8.0
var _material: StandardMaterial3D = null
var _head_material: StandardMaterial3D = null
var _goal: Vector3 = Vector3.ZERO
var _moving: bool = false
var _last_action: String = ""
var lod = null
var observer: Node = null
var fx_parent: Node = null
var world_bounds: AABB = AABB()
var has_world_bounds: bool = false
var nav_cell_size: float = 1.0
var tick_rate: float = 12.0
var _tick_accumulator: float = 0.0
var _sim_time: float = 0.0
var _path: Array = []
var _path_index: int = 0
var _last_position: Vector3 = Vector3.ZERO
var _stuck_time: float = 0.0
var _repath_cooldown: float = 0.0
var _neighbors: Array = []
var _threat_memory: float = 0.0
var _threat_position: Vector3 = Vector3.ZERO
var _melee_cooldown: float = 0.0
var _weapon_model: Node3D = null
var _weapon_model_id: String = ""
var _fx_script: Script = null
var _recorded_sfx_script: Script = null
var _sfx_bank_script: Script = null
var _rng := RandomNumberGenerator.new()


static func detect_platform() -> String:
	if ResourceLoader.exists(SESSION_PATH):
		var script: Script = load(SESSION_PATH) as Script
		if script != null:
			var declared: Variant = script.get("platform")
			if typeof(declared) == TYPE_STRING and not str(declared).strip_edges().is_empty():
				return _normalize_platform(str(declared))
			if script.has_method("detect_platform"):
				return _normalize_platform(str(script.call("detect_platform")))
	if OS.get_name() == "Android" or OS.has_feature("android"):
		return "android"
	if OS.has_feature("mobile") or OS.has_feature("iOS"):
		return "android"
	var xr := Engine.get_singleton("XRServer")
	if xr != null and xr.has_method("get_interface_count") and int(xr.call("get_interface_count")) > 0:
		return "vr"
	return "pc"


static func max_active(p_platform: String = "") -> int:
	var key: String = _normalize_platform(p_platform if not p_platform.is_empty() else detect_platform())
	if key.is_empty():
		key = "pc"
	var limit: int = int(PLATFORM_LIMITS.get(key, DEFAULT_LIMIT))
	if limits_override.has(key):
		limit = mini(limit, maxi(0, int(limits_override[key])))
	return maxi(0, limit)


static func active_count() -> int:
	var count: int = 0
	for entry in _active:
		if is_instance_valid(entry):
			count += 1
	return count


static func active_npcs() -> Array:
	var result: Array = []
	for entry in _active:
		if is_instance_valid(entry):
			result.append(entry)
	return result


static func can_spawn(p_platform: String = "") -> bool:
	return active_count() < max_active(p_platform)


static func clear_registry() -> void:
	_active.clear()


static func register(npc) -> bool:
	if npc == null or not is_instance_valid(npc):
		return false
	for entry in _active:
		if entry == npc:
			return true
	if not can_spawn(str(npc.get("platform"))):
		return false
	_active.append(npc)
	return true


static func unregister(npc) -> void:
	for i in range(_active.size() - 1, -1, -1):
		if _active[i] == npc:
			_active.remove_at(i)


static func spawn(parent: Node3D, position: Vector3, p_options: Dictionary = {}) -> Node3D:
	if parent == null or not ResourceLoader.exists(COMBAT_PATH):
		return null
	var declared: String = str(p_options.get("platform", detect_platform()))
	if not can_spawn(declared):
		return null
	var script: Script = load(COMBAT_PATH) as Script
	if script == null:
		return null
	var npc_script: Script = _self_script()
	if npc_script == null:
		return null
	var npc := npc_script.new() as Node3D
	if npc == null:
		return null
	npc.name = str(p_options.get("id", p_options.get("npc_id", "ArmedNpc")))
	if npc.has_method("apply_options"):
		npc.call("apply_options", p_options)
	parent.add_child(npc)
	npc.global_position = position
	return npc


static func _self_script() -> Script:
	var script: Script = load("res://core/game/armed_npc.gd") as Script
	return script


static func _normalize_platform(value) -> String:
	var text: String = str(value).strip_edges().to_lower()
	if PLATFORM_ALIASES.has(text):
		return str(PLATFORM_ALIASES[text])
	return ""


func _ready() -> void:
	platform = detect_platform()
	_build()
	if not _pending_options.is_empty():
		_apply_pending_options()
	spawn_accepted = register(self)
	if not spawn_accepted and auto_tick:
		push_warning("ArmedNpc: limite de NPCs activos alcanzado")


func _exit_tree() -> void:
	unregister(self)


func apply_options(p_options: Dictionary) -> void:
	_pending_options = p_options.duplicate(true)
	npc_id = str(p_options.get("id", p_options.get("npc_id", npc_id)))
	faction_id = str(p_options.get("faction_id", p_options.get("faction", faction_id)))
	weapon_id = str(p_options.get("weapon_id", weapon_id))
	role = str(p_options.get("role", role))
	difficulty = str(p_options.get("difficulty", difficulty))
	seed_value = int(p_options.get("seed", seed_value))
	target_id = str(p_options.get("target_id", target_id))
	max_health = maxf(1.0, float(p_options.get("max_health", max_health)))
	vision_range = maxf(0.0, float(p_options.get("vision_range", vision_range)))
	patrol_speed = maxf(0.0, float(p_options.get("patrol_speed", patrol_speed)))
	run_speed = maxf(patrol_speed, float(p_options.get("run_speed", run_speed)))
	spread_scale = clampf(float(p_options.get("spread_scale", spread_scale)), 0.0, 4.0)
	drop_weapon_on_death = bool(p_options.get("drop_weapon_on_death", drop_weapon_on_death))
	if p_options.has("platform"):
		platform = str(p_options["platform"])
	tick_rate = clampf(float(p_options.get("tick_rate", tick_rate)), 10.0, 15.0)
	var observer_value: Variant = p_options.get("observer", null)
	if observer_value is Node:
		observer = observer_value as Node
	var fx_value: Variant = p_options.get("fx_parent", null)
	if fx_value is Node:
		fx_parent = fx_value as Node
	var bounds_value: Variant = p_options.get("bounds", null)
	if bounds_value is AABB:
		world_bounds = bounds_value as AABB
		has_world_bounds = world_bounds.size.x > 0.0 and world_bounds.size.z > 0.0
	nav_cell_size = maxf(0.25, float(p_options.get("nav_cell_size", nav_cell_size)))
	var lod_value: Variant = p_options.get("lod", null)
	if lod_value != null:
		lod = lod_value
	if _built:
		_apply_pending_options()


func setup(p_options: Dictionary = {}) -> void:
	apply_options(p_options)


func _build() -> void:
	if _built:
		return
	_built = true
	add_to_group("damageable")
	add_to_group("armed_npc")
	collision_layer = 1
	collision_mask = 1
	collision = CollisionShape3D.new()
	collision.name = "Collision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	collision.shape = capsule
	collision.position = Vector3(0.0, 0.9, 0.0)
	collision.set_meta("hit_zone", "torso")
	add_child(collision)

	_material = StandardMaterial3D.new()
	_material.albedo_color = _role_color()
	_material.roughness = 0.85
	visual = MeshInstance3D.new()
	visual.name = "Visual"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.35
	body_mesh.height = 1.8
	body_mesh.radial_segments = 8
	body_mesh.rings = 4
	visual.mesh = body_mesh
	visual.material_override = _material
	visual.position = Vector3(0.0, 0.9, 0.0)
	add_child(visual)

	_head_material = StandardMaterial3D.new()
	_head_material.albedo_color = _role_color().lightened(0.2)
	_head_material.roughness = 0.8
	head_visual = MeshInstance3D.new()
	head_visual.name = "HeadVisual"
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	sphere.radial_segments = 8
	sphere.rings = 4
	head_visual.mesh = sphere
	head_visual.material_override = _head_material
	head_visual.position = Vector3(0.0, 1.72, 0.0)
	head_visual.set_meta("hit_zone", "head")
	add_child(head_visual)

	weapon_mount = Node3D.new()
	weapon_mount.name = "WeaponMount"
	weapon_mount.position = Vector3(0.32, 1.25, -0.42)
	add_child(weapon_mount)
	weapon_visual = MeshInstance3D.new()
	weapon_visual.name = "WeaponVisual"
	var gun_mesh := BoxMesh.new()
	gun_mesh.size = Vector3(0.09, 0.12, 0.72)
	weapon_visual.mesh = gun_mesh
	var gun_material := StandardMaterial3D.new()
	gun_material.albedo_color = Color(0.16, 0.17, 0.19)
	gun_material.metallic = 0.35
	gun_material.roughness = 0.6
	weapon_visual.material_override = gun_material
	weapon_mount.add_child(weapon_visual)

	if ResourceLoader.exists(DAMAGEABLE_PATH):
		var script: Script = load(DAMAGEABLE_PATH) as Script
		if script != null:
			damageable = script.new()
			if damageable is Node:
				damageable.name = "Damage"
				damageable.set("health", max_health)
				damageable.set("max_health", max_health)
				add_child(damageable)
				if damageable.has_signal("damaged"):
					damageable.connect("damaged", Callable(self, "_on_damaged"))
				if damageable.has_signal("died"):
					damageable.connect("died", Callable(self, "_on_died"))

	combat = _new_script_instance(COMBAT_PATH)
	if combat != null:
		combat.call("set_role", role)
		combat.set("entity_id", npc_id)
		combat.set("target_id", str(pending_target_id()))
		combat.set("difficulty", difficulty)
		combat.call("set_seed", seed_value)
		combat.set("vision_range", vision_range)

	if ResourceLoader.exists(WEAPON_SYSTEM_PATH):
		var ws_script: Script = load(WEAPON_SYSTEM_PATH) as Script
		if ws_script != null:
			var node := Node.new()
			node.name = "WeaponSystem"
			node.set_script(ws_script)
			if node.has_method("fire"):
				add_child(node)
				weapon_system = node

	if ResourceLoader.exists(PERCEPTION_PATH):
		perception = _new_script_instance(PERCEPTION_PATH)
		if perception != null and perception.has_method("configure"):
			perception.call("configure", {
				"vision_range": vision_range,
				"vision_half_angle_deg": 95.0,
				"line_of_sight": Callable(self, "_has_line_of_sight"),
			})
	if navigation == null and ResourceLoader.exists(NAVIGATION_PATH):
		navigation = _new_script_instance(NAVIGATION_PATH)
	if lod == null and ResourceLoader.exists(LOD_PATH):
		lod = _new_script_instance(LOD_PATH)
	if ResourceLoader.exists(MUZZLE_FX_PATH):
		_fx_script = load(MUZZLE_FX_PATH) as Script
	if ResourceLoader.exists(RECORDED_SFX_PATH):
		_recorded_sfx_script = load(RECORDED_SFX_PATH) as Script
	if ResourceLoader.exists(SFX_BANK_PATH):
		_sfx_bank_script = load(SFX_BANK_PATH) as Script
	_rng.seed = absi(seed_value) ^ 0xA5A5

	_apply_weapon_definition()
	_attach_weapon_model()


func _new_script_instance(path: String):
	if not ResourceLoader.exists(path):
		return null
	var script: Script = load(path) as Script
	if script == null:
		return null
	return script.new()


func _has_line_of_sight(from_value: Variant, to_value: Variant) -> bool:
	var world := get_world_3d()
	if world == null:
		return true
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	if space == null:
		return true
	var from: Vector3 = _as_position(from_value)
	var to: Vector3 = _as_position(to_value)
	var delta: Vector3 = to - from
	if delta.length_squared() < 0.0001:
		return true
	var exclude: Array[RID] = []
	if self is CollisionObject3D:
		exclude.append((self as CollisionObject3D).get_rid())
	if target is CollisionObject3D:
		exclude.append((target as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 1.4, to + Vector3.UP * 1.2, 1, exclude)
	query.collide_with_areas = false
	return space.intersect_ray(query).is_empty()


func _as_position(value: Variant) -> Vector3:
	if value is Vector3:
		return value as Vector3
	if value is Vector2:
		var vector: Vector2 = value
		return Vector3(vector.x, 0.0, vector.y)
	return Vector3.ZERO


func _attach_weapon_model() -> void:
	if weapon_mount == null or (_weapon_model != null and _weapon_model_id == weapon_id):
		return
	if _weapon_model != null and is_instance_valid(_weapon_model):
		_weapon_model.queue_free()
	_weapon_model = null
	_weapon_model_id = weapon_id
	if not ResourceLoader.exists(WEAPON_VIEWMODEL_PATH):
		return
	var view: Script = load(WEAPON_VIEWMODEL_PATH) as Script
	if view == null or not view.has_method("model_path_for"):
		return
	var path: String = str(view.call("model_path_for", weapon_id))
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var model := packed.instantiate() as Node3D
	if model == null:
		return
	weapon_mount.add_child(model)
	var box := _combined_aabb(model)
	if not box.size.is_zero_approx():
		var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
		if longest > 0.0001:
			var factor: float = 0.72 / longest
			model.scale = Vector3(factor, factor, factor)
		if box.size.x > box.size.z:
			model.rotation.y = PI * 0.5
		model.position = -box.get_center() * maxf(model.scale.x, 0.0001)
	_weapon_model = model
	if weapon_visual != null:
		weapon_visual.visible = false


func _combined_aabb(node: Node) -> AABB:
	var result := AABB()
	var found: bool = false
	for child in node.find_children("*", "MeshInstance3D", true, true):
		var mesh := child as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		var local_box: AABB = mesh.mesh.get_aabb()
		local_box.size *= mesh.scale
		local_box.position += mesh.position
		if not found:
			result = local_box
			found = true
		else:
			result = result.merge(local_box)
	return result


func _apply_weapon_definition() -> void:
	if combat == null or not ResourceLoader.exists(WEAPON_DB_PATH):
		return
	var db: Script = load(WEAPON_DB_PATH) as Script
	if db == null or not db.has_method("get_def"):
		return
	var def: Dictionary = db.call("get_def", weapon_id)
	if def.is_empty():
		return
	combat.set("mag_size", maxi(0, int(def.get("mag", 0))))
	combat.set("fire_rate", maxf(0.01, float(def.get("fire_rate", 1.0))))
	combat.set("reload_duration", maxf(0.01, float(def.get("reload_time", 1.0))))
	var loaded: int = int(_pending_options.get("ammo", int(def.get("mag", 0))))
	var stored: int = int(_pending_options.get("reserve", int(def.get("mag", 0)) * 3))
	combat.call("set_ammo", loaded, stored)
	if weapon_system != null and weapon_system.has_method("set_ammo"):
		weapon_system.call("set_ammo", weapon_id, int(combat.get("ammo")), int(combat.get("reserve")))


func _apply_pending_options() -> void:
	if combat == null:
		return
	combat.call("set_role", role)
	combat.call("set_difficulty", difficulty)
	combat.call("set_seed", seed_value)
	combat.set("entity_id", npc_id)
	combat.set("target_id", str(pending_target_id()))
	combat.set("vision_range", vision_range)
	combat.set("cover_points", _pending_options.get("cover_points", []))
	combat.set("attack_points", _pending_options.get("attack_points", []))
	combat.set("patrol_points", _pending_options.get("patrol_points", []))
	var nav_value: Variant = _pending_options.get("navigation", null)
	if nav_value != null:
		set_navigation(nav_value)
	var lod_value: Variant = _pending_options.get("lod", null)
	if lod_value != null:
		lod = lod_value
	var observer_value: Variant = _pending_options.get("observer", null)
	if observer_value is Node:
		observer = observer_value as Node
	var fx_value: Variant = _pending_options.get("fx_parent", null)
	if fx_value is Node:
		fx_parent = fx_value as Node
	var bounds_value: Variant = _pending_options.get("bounds", null)
	if bounds_value is AABB:
		world_bounds = bounds_value as AABB
		has_world_bounds = world_bounds.size.x > 0.0 and world_bounds.size.z > 0.0
	nav_cell_size = maxf(0.25, float(_pending_options.get("nav_cell_size", nav_cell_size)))
	if _pending_options.has("health_ratio") and damageable != null:
		var ratio: float = clampf(float(_pending_options["health_ratio"]), 0.0, 1.0)
		damageable.set("health", max_health * ratio)
	if _pending_options.has("faction_data") and factions == null:
		factions = _new_script_instance(FACTIONS_PATH)
		if factions != null:
			factions.call("restore", _pending_options["faction_data"])
	if _pending_options.has("factions") and _pending_options["factions"] != null:
		factions = _pending_options["factions"]
	if _pending_options.has("relations") and _pending_options["relations"] != null:
		relations = _pending_options["relations"]
	if factions == null and faction_id.is_empty() and _pending_options.has("faction_members"):
		factions = _new_script_instance(FACTIONS_PATH)
	var target_value: Variant = _pending_options.get("target", null)
	if target_value is Node3D:
		set_target(target_value)
	elif typeof(target_value) == TYPE_NODE_PATH:
		set_target(get_node_or_null(target_value) as Node3D)
	elif target_value is Vector3:
		set_aim_point(target_value)
	_apply_weapon_definition()
	if _material != null:
		_material.albedo_color = _role_color()
	if _head_material != null:
		_head_material.albedo_color = _role_color().lightened(0.2)
	_attach_weapon_model()


func pending_target_id() -> String:
	if _pending_options.has("target_id"):
		return str(_pending_options["target_id"])
	if _pending_options.has("target") and typeof(_pending_options["target"]) == TYPE_STRING:
		return str(_pending_options["target"])
	if not target_id_is_default():
		return target_id
	return "player"


func target_id_is_default() -> bool:
	return target_id == "player"


func set_target(node: Node3D) -> void:
	target = node
	if node != null and combat != null:
		combat.set("target_id", str(node.name))
	if node != null and is_inside_tree():
		_face_target()
	if combat != null and target != null:
		var id: String = str(node.name)
		if relations != null and relations.has_method("set_affinity"):
			relations.call("set_affinity", npc_id, id, _initial_affinity())


func set_aim_point(point: Vector3) -> void:
	aim_point = point
	has_explicit_aim = true


func set_relations(value) -> void:
	relations = value
	if combat != null:
		combat.set("relations", value)


func set_factions(value) -> void:
	factions = value
	if combat != null:
		combat.set("factions", value)


func set_navigation(value) -> void:
	navigation = value
	if combat != null:
		combat.set("navigation", value)


func initial_attitude() -> String:
	if combat == null:
		return "neutral"
	return str(combat.call("attitude_toward_target"))


func current_action() -> String:
	if combat == null:
		return "idle"
	return str(combat.call("action"))


func current_ammo() -> int:
	if combat == null:
		return 0
	return int(combat.get("ammo"))


func current_reserve() -> int:
	if combat == null:
		return 0
	return int(combat.get("reserve"))


func health_ratio() -> float:
	if damageable == null:
		return 1.0
	return clampf(float(damageable.get("health")) / maxf(max_health, 0.01), 0.0, 1.0)


func is_dead() -> bool:
	return _dead


func tick(delta: float) -> Dictionary:
	if combat == null or _dead:
		return {"action": "dead", "fired": false}
	combat.set("health_ratio", health_ratio())
	if weapon_system != null and weapon_system.has_method("advance"):
		weapon_system.call("advance", maxf(delta, 0.0))
	var ctx: Dictionary = _context()
	var result: Dictionary = combat.call("update", maxf(delta, 0.0), ctx)
	var action: String = str(result.get("id", current_action()))
	if action != _last_action:
		_last_action = action
		action_changed.emit(action)
	var goal: Variant = combat.call("goal_for", action, ctx)
	_goal = goal if goal is Vector3 else Vector3.ZERO
	_sanitize_goal(action)
	if action == "reload" and not bool(combat.call("is_reloading")):
		combat.call("start_reload")
	if action == "attack":
		if role == "zombie":
			_melee_attack()
		elif bool(combat.call("can_fire")):
			fire()
	_replan_path()
	return result


func fire() -> Dictionary:
	var failed: Dictionary = {"fired": false, "reason": "unavailable"}
	if _dead or combat == null or weapon_system == null or (target == null and not has_explicit_aim):
		return failed
	if not bool(combat.call("can_fire")):
		failed["reason"] = "blocked"
		return failed
	var world := get_world_3d()
	if world == null:
		failed["reason"] = "no_world"
		return failed
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	if space == null:
		failed["reason"] = "no_space"
		return failed
	var origin: Vector3 = _muzzle_position()
	var point: Vector3 = aim_point if has_explicit_aim else target.global_position + Vector3.UP * 1.0
	var to_point: Vector3 = point - origin
	var distance: float = to_point.length()
	if distance < 0.01:
		failed["reason"] = "no_direction"
		return failed
	var direction: Vector3 = to_point.normalized()
	var spread: float = float(combat.call("settings")["spread"]) * spread_scale
	spread *= 1.0 + clampf(distance / 60.0, 0.0, 1.0)
	if _moving:
		spread *= 1.25
	direction = combat.call("spread_direction_with", direction, spread)
	if not bool(combat.call("consume_shot")):
		failed["reason"] = "blocked"
		return failed
	if weapon_system.has_method("set_ammo"):
		weapon_system.call("set_ammo", weapon_id, int(combat.get("ammo")), int(combat.get("reserve")))
	var result: Variant = weapon_system.call("fire", weapon_id, origin, direction, space, [self])
	if not result is Dictionary:
		return failed
	var shot: Dictionary = result
	shot["npc_id"] = npc_id
	shot["spread"] = spread
	_play_shot_fx(origin, direction, shot)
	fired.emit(shot)
	return shot


func take_damage(amount: float, point: Vector3 = Vector3.ZERO, normal: Vector3 = Vector3.UP, source: Node = null) -> void:
	if damageable == null or _dead or amount <= 0.0:
		return
	var impact: Vector3 = point - global_position
	if impact.length_squared() < 0.0001:
		impact = -_forward()
	_last_impact_direction = -impact.normalized() if normal.length_squared() < 0.0001 else -normal.normalized()
	_last_impact_force = clampf(4.0 + amount * 0.16, 4.0, 24.0)
	var source_id: String = "unknown"
	if source != null:
		source_id = str(source.name)
	damageable.call("take_damage", amount, point, normal, source)
	if combat != null:
		combat.call("note_hit", source_id, clampf(amount / 60.0, 0.1, 1.0), point)
	_remember_threat(point, source_id, 3.0)
	_alert_allies(source_id)


func take_zone_damage(zone: String, amount: float, point: Vector3, normal: Vector3, source: Node = null) -> void:
	if damageable == null or _dead:
		return
	if damageable.has_method("take_zone_damage"):
		var impact: Vector3 = point - global_position
		_last_impact_direction = -impact.normalized() if impact.length_squared() > 0.0001 else -_forward()
		_last_impact_force = clampf(4.0 + amount * 0.16, 4.0, 24.0)
		damageable.call("take_zone_damage", zone, amount, point, normal, source)
		if combat != null:
			combat.call("note_hit", str(source.name) if source != null else "unknown", clampf(amount / 60.0, 0.1, 1.0), point)
		_remember_threat(point, str(source.name) if source != null else "unknown", 3.0)
	else:
		take_damage(amount, point, normal, source)


func request_help(source_id: String) -> void:
	called_for_help.emit(source_id)
	_alert_allies(source_id)


func _physics_process(delta: float) -> void:
	if not auto_tick:
		return
	var step: float = maxf(delta, 0.0)
	_melee_cooldown = maxf(0.0, _melee_cooldown - step)
	_threat_memory = maxf(0.0, _threat_memory - step)
	if _dead:
		velocity = Vector3.ZERO
		return
	_tick_accumulator += step
	var interval: float = 1.0 / maxf(tick_rate, 1.0)
	if _tick_accumulator + _hash01(npc_id) * interval >= interval:
		var decision_delta: float = _tick_accumulator
		_tick_accumulator = 0.0
		tick(decision_delta)
	_move_toward_goal(step)


func _move_toward_goal(delta: float) -> void:
	var destination: Vector3 = _goal
	if _path_index < _path.size():
		destination = _path[_path_index]
	var offset: Vector3 = destination - global_position
	offset.y = 0.0
	var remaining: float = offset.length()
	if _path_index < _path.size() and remaining < 0.55:
		_path_index += 1
		if _path_index < _path.size():
			destination = _path[_path_index]
			offset = destination - global_position
			offset.y = 0.0
			remaining = offset.length()
	_moving = remaining > 0.45
	var action: String = current_action()
	var speed: float = patrol_speed
	if action == "flee" or action == "run" or (role == "zombie" and action == "attack"):
		speed = run_speed
	elif action == "attack" or action == "investigate":
		speed = maxf(patrol_speed, run_speed * 0.55)
	if _moving:
		var direction: Vector3 = offset.normalized()
		var avoidance: Vector3 = Vector3.ZERO
		for ally in _active:
			if ally == self or not is_instance_valid(ally):
				continue
			var other: Node3D = ally as Node3D
			if other == null or (other.has_method("is_dead") and bool(other.call("is_dead"))):
				continue
			var separation: Vector3 = global_position - other.global_position
			separation.y = 0.0
			var distance: float = separation.length()
			if distance > 0.001 and distance < 1.4:
				avoidance += (separation / distance) * ((1.4 - distance) / 1.4)
		if avoidance.length_squared() > 0.0001:
			direction = (direction + avoidance * 0.65).normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		_face_direction_smooth(direction, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if target != null and action != "flee":
			_face_target()
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0
	var previous: Vector3 = global_position
	move_and_slide()
	if navigation != null and not bool(navigation.call("is_walkable_world", global_position, nav_cell_size)):
		global_position = previous
		velocity.x = 0.0
		velocity.z = 0.0
		_stuck_time += delta
		_path.clear()
	if has_world_bounds:
		var inset: float = 0.6
		var x: float = clampf(global_position.x, world_bounds.position.x + inset, world_bounds.end.x - inset)
		var z: float = clampf(global_position.z, world_bounds.position.z + inset, world_bounds.end.z - inset)
		if x != global_position.x or z != global_position.z:
			global_position = Vector3(x, global_position.y, z)
	var travelled: float = global_position.distance_to(previous)
	if _moving and travelled < maxf(0.001, speed * delta * 0.08):
		_stuck_time += delta
	else:
		_stuck_time = maxf(0.0, _stuck_time - delta * 0.5)


func _context() -> Dictionary:
	var visible: bool = false
	var distance: float = 100.0
	var target_position: Vector3 = aim_point if has_explicit_aim else _threat_position
	if target != null and is_instance_valid(target):
		target_position = target.global_position
		distance = maxf(global_position.distance_to(target_position), 0.0)
		var facing: Vector3 = _forward()
		if perception != null and perception.has_method("can_see"):
			var sight: Dictionary = perception.call(
				"can_see", global_position,
				Vector2(facing.x, facing.z),
				Vector2(target_position.x, target_position.z),
				{"vision_range": vision_range}
			)
			visible = bool(sight.get("visible", false))
		else:
			visible = distance <= vision_range
	elif has_explicit_aim:
		distance = global_position.distance_to(aim_point)
		visible = distance <= vision_range
	if combat != null and _threat_memory > 0.0:
		combat.set("last_threat_position", _threat_position)
	if role == "civilian" and _threat_memory > 0.0:
		visible = true
		target_position = _threat_position
		distance = minf(distance, maxf(global_position.distance_to(_threat_position), 0.0))
	return {
		"visible": visible,
		"distance": distance,
		"target_position": target_position,
		"position": global_position,
		"path": _path,
	}


func _sanitize_goal(action: String) -> void:
	if navigation == null or _goal.length_squared() <= 0.0001:
		return
	var target: Vector3 = _goal
	if has_world_bounds:
		target.x = clampf(target.x, world_bounds.position.x + 1.0, world_bounds.end.x - 1.0)
		target.z = clampf(target.z, world_bounds.position.z + 1.0, world_bounds.end.z - 1.0)
	if action == "flee" and _threat_position.length_squared() > 0.0001:
		var flee_point: Vector3 = Vector3.ZERO
		var flee_score: float = -INF
		var grid_width: int = int(navigation.get("width"))
		var grid_height: int = int(navigation.get("height"))
		for y in range(grid_height):
			for x in range(grid_width):
				var cell_candidate := Vector2i(x, y)
				if bool(navigation.call("is_blocked", cell_candidate)):
					continue
				var world_point: Vector3 = navigation.call(
					"cell_to_world", cell_candidate, nav_cell_size, global_position.y
				)
				var score: float = world_point.distance_squared_to(_threat_position)
				score -= world_point.distance_squared_to(global_position) * 0.05
				if score > flee_score:
					flee_score = score
					flee_point = world_point
		if flee_score > -INF:
			_goal = flee_point
			return
	if bool(navigation.call("is_walkable_world", target, nav_cell_size)):
		_goal = target
		return
	var from_cell: Vector2i = navigation.call("world_to_cell_2d", Vector2(global_position.x, global_position.z), nav_cell_size)
	var cell: Vector2i = navigation.call("world_to_cell_2d", Vector2(target.x, target.z), nav_cell_size)
	for skip_current in [true, false]:
		var best: Vector3 = Vector3.ZERO
		var best_distance: float = INF
		for radius in range(0, 7):
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					if maxi(absi(dx), absi(dy)) != radius:
						continue
					var candidate: Vector2i = cell + Vector2i(dx, dy)
					if not bool(navigation.call("is_inside", candidate)):
						continue
					if bool(navigation.call("is_blocked", candidate)):
						continue
					if skip_current and candidate == from_cell:
						continue
					var world_point: Vector3 = navigation.call("cell_to_world", candidate, nav_cell_size, _goal.y)
					var distance: float = world_point.distance_squared_to(target)
					if distance < best_distance:
						best_distance = distance
						best = world_point
			if best_distance < INF:
				break
		if best_distance < INF:
			_goal = best
			return


func _replan_path() -> void:
	_repath_cooldown = maxf(0.0, _repath_cooldown - 1.0 / maxf(tick_rate, 1.0))
	if navigation == null or _goal.length_squared() < 0.0001:
		return
	var moved: float = global_position.distance_to(_last_position)
	_last_position = global_position
	if _moving and moved < 0.02:
		_stuck_time += 1.0 / maxf(tick_rate, 1.0)
	var need_path: bool = _repath_cooldown <= 0.0 and (
		_stuck_time > 0.85 or _path.is_empty() or _path_index >= _path.size()
	)
	if not need_path:
		return
	var start_cell: Vector2i = navigation.call(
		"world_to_cell_2d", Vector2(global_position.x, global_position.z), nav_cell_size
	)
	var goal_cell: Vector2i = navigation.call(
		"world_to_cell_2d", Vector2(_goal.x, _goal.z), nav_cell_size
	)
	var result: Variant = navigation.call("find_path", start_cell, goal_cell, {
		"position": global_position,
		"target_position": _goal,
		"cell_size": nav_cell_size,
	})
	if not result is Dictionary or not bool((result as Dictionary).get("ok", false)):
		_repath_cooldown = 0.5
		return
	_path.clear()
	for cell in (result as Dictionary).get("path", []):
		_path.append(_cell_to_world(cell))
	_path_index = 0
	_repath_cooldown = 0.45 if _stuck_time <= 0.85 else 0.25
	_stuck_time = 0.0


func _cell_to_world(cell: Variant) -> Vector3:
	if cell is Vector3:
		return cell as Vector3
	if navigation == null:
		return Vector3.ZERO
	if cell is Vector2i:
		return navigation.call("cell_to_world", cell, nav_cell_size, global_position.y)
	if cell is Vector2:
		return navigation.call("cell_to_world", cell, nav_cell_size, global_position.y)
	return Vector3.ZERO


func _muzzle_position() -> Vector3:
	if weapon_mount != null:
		return weapon_mount.global_position
	return global_position + Vector3.UP * 1.4 + _forward() * 0.4


func _forward() -> Vector3:
	var forward: Vector3 = -global_transform.basis.z
	return forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD


func _face_target() -> void:
	if target == null or not is_instance_valid(target):
		return
	var direction: Vector3 = target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		_face_direction(direction.normalized())


func _face_direction(direction: Vector3) -> void:
	var yaw: float = atan2(-direction.x, -direction.z)
	rotation.y = yaw


func _face_direction_smooth(direction: Vector3, delta: float) -> void:
	var yaw: float = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 8.0, 0.0, 1.0))


func _hash01(value: String) -> float:
	return float(absi(value.hash()) % 1000) / 1000.0


func _remember_threat(position: Vector3, source_id: String, duration: float) -> void:
	if position.length_squared() <= 0.0001:
		return
	_threat_position = position
	_threat_memory = maxf(_threat_memory, maxf(0.2, duration))
	if combat != null:
		combat.call("note_threat", source_id, 0.8, position)


func _melee_attack() -> void:
	if _melee_cooldown > 0.0 or target == null or not is_instance_valid(target):
		return
	var distance: float = global_position.distance_to(target.global_position)
	if distance > MELEE_RANGE + 0.4:
		return
	_melee_cooldown = 0.85
	var hit_point: Vector3 = target.global_position + Vector3.UP * 1.0
	var direction: Vector3 = (target.global_position - global_position).normalized()
	if target.has_method("take_zone_damage"):
		target.call("take_zone_damage", "torso", MELEE_DAMAGE, hit_point, -direction, self)
	elif target.has_method("take_damage"):
		target.call("take_damage", MELEE_DAMAGE, hit_point, -direction, self)
	_spawn_tracer(_muzzle_position(), hit_point, true)


func _play_shot_fx(origin: Vector3, direction: Vector3, shot: Dictionary) -> void:
	var parent: Node = fx_parent if fx_parent != null and is_instance_valid(fx_parent) else get_parent()
	if parent == null:
		return
	if _fx_script != null:
		_fx_script.call("spawn_flash", parent, origin, direction, 1.0)
		_fx_script.call("spawn_smoke", parent, origin, direction, 0.8)
	var end: Vector3 = origin + direction * maxf(4.0, float(shot.get("distance", 20.0)))
	if shot.has("position") and shot["position"] is Vector3:
		end = shot["position"] as Vector3
	_spawn_tracer(origin, end, false)
	if _recorded_sfx_script != null:
		_recorded_sfx_script.call("play", weapon_id, "fire", parent, origin, _rng)
	elif _sfx_bank_script != null:
		_sfx_bank_script.call("play_synth", parent, "shot", weapon_id, origin, "sfx", seed_value)


func _spawn_tracer(from: Vector3, to: Vector3, melee: bool) -> void:
	var parent: Node = fx_parent if fx_parent != null and is_instance_valid(fx_parent) else get_parent()
	if parent == null:
		return
	var delta: Vector3 = to - from
	var length: float = delta.length()
	if length < 0.05:
		return
	if _tracer_mesh == null:
		_tracer_mesh = BoxMesh.new()
		_tracer_mesh.size = Vector3(0.035, 0.035, 1.0)
	if _tracer_material == null:
		_tracer_material = StandardMaterial3D.new()
		_tracer_material.albedo_color = Color(1.0, 0.76, 0.32)
		_tracer_material.emission_enabled = true
		_tracer_material.emission = Color(1.0, 0.6, 0.18)
		_tracer_material.emission_energy_multiplier = 3.0
	var tracer := MeshInstance3D.new()
	tracer.name = "NpcTracer"
	tracer.mesh = _tracer_mesh
	tracer.material_override = _tracer_material
	parent.add_child(tracer)
	tracer.global_position = (from + to) * 0.5
	tracer.look_at(to, Vector3.UP)
	tracer.scale.z = length if not melee else minf(length, 1.6)
	tracer.set_meta("life", TRACER_LIFE * (1.4 if melee else 1.0))
	_tracers.append(tracer)
	while _tracers.size() > MAX_TRACERS:
		var old: Variant = _tracers.pop_front()
		if old is Node and is_instance_valid(old):
			(old as Node).queue_free()


static func advance_fx(delta: float) -> void:
	if _tracers.is_empty():
		return
	for i in range(_tracers.size() - 1, -1, -1):
		var tracer: Variant = _tracers[i]
		if not is_instance_valid(tracer):
			_tracers.remove_at(i)
			continue
		var life: float = float((tracer as Node).get_meta("life", 0.0)) - maxf(delta, 0.0)
		if life <= 0.0:
			(tracer as Node).queue_free()
			_tracers.remove_at(i)
		else:
			(tracer as Node).set_meta("life", life)


func _on_damaged(amount: float, point: Vector3, normal: Vector3) -> void:
	if combat == null:
		return
	combat.set("health_ratio", health_ratio())


func _on_died() -> void:
	if _dead:
		return
	_dead = true
	velocity = Vector3.ZERO
	set_physics_process(false)
	collision_layer = 0
	if visual != null:
		visual.visible = false
	if head_visual != null:
		head_visual.visible = false
	if weapon_visual != null:
		weapon_visual.visible = false
	var parent: Node = get_parent()
	var impulse: Vector3 = _last_impact_direction.normalized() * _last_impact_force
	var ragdoll: RigidBody3D = null
	if parent != null:
		ragdoll = RigidBody3D.new()
		ragdoll.name = "Ragdoll_%s" % npc_id
		ragdoll.mass = 60.0
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.35
		capsule.height = 1.8
		shape.shape = capsule
		shape.position = Vector3(0.0, 0.9, 0.0)
		ragdoll.add_child(shape)
		var mesh_instance := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.35
		mesh.height = 1.8
		mesh.radial_segments = 8
		mesh_instance.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = _role_color()
		mesh_instance.material_override = material
		mesh_instance.position = Vector3(0.0, 0.9, 0.0)
		ragdoll.add_child(mesh_instance)
		parent.add_child(ragdoll)
		ragdoll.global_transform = global_transform
		ragdoll.apply_impulse(impulse, Vector3(0.0, 1.2, 0.0))
	var dropped: Node3D = null
	if drop_weapon_on_death and not weapon_id.is_empty() and parent != null:
		dropped = _drop_weapon(parent, _muzzle_position() + Vector3.UP * 0.2, impulse * 0.12)
	var source: Node = null
	if damageable != null and damageable.get("last_source") != null:
		source = damageable.get("last_source")
	death_report = {
		"ok": true,
		"position": global_position,
		"impulse": impulse,
		"ragdoll": ragdoll,
		"weapon": dropped,
		"source": source,
	}
	if ResourceLoader.exists(GORE_FX_PATH):
		var gore: Script = load(GORE_FX_PATH) as Script
		if gore != null and gore.has_method("on_death"):
			gore.call("on_death", parent if parent != null else self, global_position, 0.8)
	died_from.emit(source)
	if dropped != null:
		weapon_dropped.emit(dropped)


func _drop_weapon(parent: Node, position: Vector3, impulse: Vector3) -> Node3D:
	var body := RigidBody3D.new()
	body.name = "DroppedWeapon_%s" % weapon_id
	body.mass = maxf(0.5, weapon_id.length() * 0.2)
	body.position = position
	body.add_to_group("weapon_pickup")
	body.set_meta("weapon_id", weapon_id)
	body.set_meta("pickable", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.12, 0.14, 0.7)
	shape.shape = box
	body.add_child(shape)
	var visual_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	visual_node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.17, 0.19)
	visual_node.material_override = material
	body.add_child(visual_node)
	parent.add_child(body)
	body.apply_impulse(impulse + Vector3.UP * 1.5)
	return body


static func pick_up_weapon(node: Node3D) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	if not node.has_meta("weapon_id"):
		return ""
	var id: String = str(node.get_meta("weapon_id"))
	node.queue_free()
	return id


func _alert_allies(source_id: String) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	for ally in tree.get_nodes_in_group("armed_npc"):
		if ally == self or not is_instance_valid(ally):
			continue
		if not ally.has_method("hear_alert"):
			continue
		if global_position.distance_to(ally.global_position) > vision_range + 10.0:
			continue
		ally.call("hear_alert", source_id, global_position)


func hear_alert(source_id: String, position: Vector3) -> void:
	hear_gunshot(position, 0.7, source_id)


func hear_gunshot(position: Vector3, loudness: float = 1.0, source_id: String = "player") -> void:
	if _dead or combat == null:
		return
	var radius: float = vision_range + 12.0
	if perception != null and perception.has_method("can_hear"):
		var stimulus: Dictionary = {"position": position, "noise": loudness, "radius": radius}
		var heard: Dictionary = perception.call("can_hear", stimulus, global_position, {})
		if not bool(heard.get("heard", false)):
			return
	elif global_position.distance_to(position) > radius:
		return
	_remember_threat(position, source_id, 4.0)


func notice_weapon(position: Vector3) -> void:
	if role != "civilian" or _dead:
		return
	if global_position.distance_to(position) <= vision_range:
		_remember_threat(position, "weapon", 3.5)


func _initial_affinity() -> float:
	match role:
		"civilian":
			return 10.0
		"defender":
			return -10.0
		_:
			return -60.0


func _role_color() -> Color:
	match role:
		"civilian":
			return Color(0.24, 0.48, 0.78)
		"defender":
			return Color(0.22, 0.62, 0.36)
		"zombie":
			return Color(0.45, 0.58, 0.25)
		_:
			return Color(0.72, 0.24, 0.18)


func snapshot() -> Dictionary:
	var base: Dictionary = combat.call("snapshot") if combat != null else {}
	base["npc_id"] = npc_id
	base["weapon_id"] = weapon_id
	base["dead"] = _dead
	base["spawn_accepted"] = spawn_accepted
	base["platform"] = platform
	base["tick_rate"] = tick_rate
	base["path_length"] = _path.size()
	base["lod_interval"] = lod.call("get_update_interval", 0.0) if lod != null else 0.0
	return base
