class_name Player
extends CharacterBody3D

const TOUCH_CONTROLS_SCENE := "res://scenes/ui/touch_controls.tscn"
const WEAPON_SYSTEM_PATH := "res://core/game/weapon_system.gd"
const WEAPON_DB_PATH := "res://core/game/weapon_db.gd"
const ITEM_DB_PATH := "res://core/game/item_db.gd"
const INVENTORY_PATH := "res://core/game/inventory.gd"
const LOADOUT_PATH := "res://core/game/loadout.gd"
const VIEWMODEL_PATH := "res://core/game/weapon_viewmodel.gd"
const SFX_BANK_PATH := "res://core/game/sfx_bank.gd"
const AUDIO_SYNTH_PATH := "res://core/game/audio_synth.gd"
const TOUCH_SIGNALS := [
	["move", "_on_touch_move"],
	["look", "_on_touch_look"],
	["jump_pressed", "_on_touch_jump"],
	["fire_pressed", "_on_touch_fire_pressed"],
	["fire_released", "_on_touch_fire_released"],
	["reload_pressed", "_on_touch_reload"],
	["interact_pressed", "_on_touch_interact"],
	["menu_pressed", "_on_touch_menu"],
	["hotbar_select", "_on_touch_hotbar"],
]

signal died
signal weapon_changed(item_id)
signal damaged(amount: float, point: Vector3, normal: Vector3)
signal empty(item_id: String)
signal fired(result: Dictionary)
signal reloaded(item_id: String)
signal ammo_changed(loaded: int, reserve: int)
signal health_changed(current: float, maximum: float)
signal interact_pressed
signal menu_pressed

@export var max_health: float = 100.0
@export var eye_height: float = 1.65
@export var walk_speed: float = 5.0
@export var run_speed: float = 8.0
@export var jump_velocity: float = 7.0
@export var gravity: float = 24.0
@export var mouse_sensitivity: float = 0.002
@export var pitch_limit: float = 1.5
@export var respawn_delay: float = 0.6

var inventory
var item_db = null
var health: float = 100.0
var equipped_weapon: String = ""
var vehicle: Node3D = null
var head: Node3D
var camera: Camera3D
var touch_controls: Node
var loadout_report: Dictionary = {}
var viewmodel = null

var _move_input := Vector2.ZERO
var _drive_input := Vector3.ZERO
var _jump_queued := false
var _running := false
var _dead := false
var _respawn_timer := 0.0
var _spawn_position := Vector3.ZERO
var _weapon_system: Node
var _touch_layer: CanvasLayer
var _fire_held := false
var _kit_ready := false


func _ready() -> void:
	if health <= 0.0:
		health = max_health
	_spawn_position = global_position
	_build_body()
	_setup_loadout()
	if _is_touch_platform():
		_setup_touch_controls()
	elif not OS.has_feature("headless") and not _is_vr_platform():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	health_changed.emit(health, max_health)


func _setup_loadout() -> void:
	if _kit_ready:
		return
	_kit_ready = true
	var db_script := _safe_script(ITEM_DB_PATH)
	var inv_script := _safe_script(INVENTORY_PATH)
	if db_script == null or inv_script == null:
		if inventory == null:
			inventory = inv_script.new() if inv_script != null else null
		return
	var db = db_script.new()
	item_db = db
	var weapons_script := _safe_script(WEAPON_DB_PATH)
	if weapons_script != null and weapons_script.has_method("register_items"):
		weapons_script.register_items(db)
	if inventory == null:
		inventory = inv_script.new(db, 20)
	elif not _inventory_has_kit(weapons_script):
		inventory = inv_script.new(db, 20)
	var kit_script := _safe_script(LOADOUT_PATH)
	if kit_script != null and kit_script.has_method("give_starting_kit"):
		var report = kit_script.give_starting_kit(inventory, db)
		if report is Dictionary:
			loadout_report = report


func _inventory_has_kit(weapons_script) -> bool:
	if weapons_script == null or not weapons_script.has_method("list_ids") or inventory == null:
		return true
	if not inventory.has_method("count"):
		return true
	for raw_id in weapons_script.list_ids():
		if int(inventory.count(str(raw_id))) <= 0:
			return false
	return true


func _safe_script(path: String) -> Script:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Script


func _build_body() -> void:
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	col.shape = capsule
	col.position = Vector3(0.0, 0.9, 0.0)
	add_child(col)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, eye_height, 0.0)
	add_child(head)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.current = true
	head.add_child(camera)
	_setup_viewmodel()


func _setup_viewmodel() -> void:
	if viewmodel != null and is_instance_valid(viewmodel):
		return
	var script := _safe_script(VIEWMODEL_PATH)
	if script == null or camera == null:
		return
	var node: Node = script.new() as Node
	if node == null or not (node is Node3D):
		return
	node.name = "WeaponViewmodel"
	camera.add_child(node)
	viewmodel = node
	var fx = null
	if viewmodel.has_method("muzzle_fx"):
		fx = viewmodel.call("muzzle_fx")
	if fx != null:
		fx.casing_parent = get_parent() if get_parent() != null else self


func _viewmodel_has_model(item_id: String) -> bool:
	if viewmodel == null or not is_instance_valid(viewmodel):
		return false
	var script := _safe_script(VIEWMODEL_PATH)
	return script != null and script.has_method("has_model_for") and bool(script.call("has_model_for", item_id))


func _update_viewmodel_walk() -> void:
	if viewmodel == null or not is_instance_valid(viewmodel) or not viewmodel.has_method("set_walk_intensity"):
		return
	var reference: float = run_speed if _running or Input.is_key_pressed(KEY_SHIFT) else walk_speed
	var speed: float = Vector2(velocity.x, velocity.z).length() / maxf(reference, 0.01)
	viewmodel.call("set_walk_intensity", maxf(clampf(speed, 0.0, 1.0), _move_input.length()))


func _is_touch_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("iOS")


func _is_vr_platform() -> bool:
	return OS.has_feature("XR") or OS.has_feature("vr")


func _setup_touch_controls() -> void:
	if not ResourceLoader.exists(TOUCH_CONTROLS_SCENE):
		return
	var packed := load(TOUCH_CONTROLS_SCENE) as PackedScene
	if packed == null:
		return
	var controls := packed.instantiate()
	if controls == null:
		return
	_touch_layer = CanvasLayer.new()
	_touch_layer.name = "TouchLayer"
	add_child(_touch_layer)
	_touch_layer.add_child(controls)
	set_touch_controls(controls)


func set_touch_controls(controls: Node) -> void:
	if touch_controls != null and is_instance_valid(touch_controls):
		_disconnect_controls(touch_controls)
	touch_controls = controls
	if controls == null:
		return
	for pair in TOUCH_SIGNALS:
		var signal_name: String = pair[0]
		var method: String = pair[1]
		if controls.has_signal(signal_name):
			var callable := Callable(self, method)
			if not controls.is_connected(signal_name, callable):
				controls.connect(signal_name, callable)


func _disconnect_controls(controls: Node) -> void:
	for pair in TOUCH_SIGNALS:
		var signal_name: String = pair[0]
		var method: String = pair[1]
		var callable := Callable(self, method)
		if controls.has_signal(signal_name) and controls.is_connected(signal_name, callable):
			controls.disconnect(signal_name, callable)


func _on_touch_move(vec: Vector2) -> void:
	move_action(vec)


func _on_touch_look(delta: Vector2) -> void:
	look_action(delta, false)


func _on_touch_jump() -> void:
	jump_action()


func _on_touch_fire_pressed() -> void:
	_fire_held = true
	fire_action()


func _on_touch_fire_released() -> void:
	_fire_held = false


func _on_touch_reload() -> void:
	reload_action()


func _on_touch_interact() -> void:
	interact_action()


func _on_touch_menu() -> void:
	menu_action()


func _on_touch_hotbar(index: int) -> void:
	hotbar_action(index)


func move_action(vec: Vector2) -> void:
	_move_input = vec


func look_action(delta: Vector2, apply_sensitivity: bool = true) -> void:
	var d: Vector2 = delta * mouse_sensitivity if apply_sensitivity else delta
	rotate_y(-d.x)
	if head != null:
		head.rotation.x = clampf(head.rotation.x - d.y, -pitch_limit, pitch_limit)


func jump_action() -> void:
	_jump_queued = true


func fire_action() -> void:
	fire()


func interact_action() -> void:
	interact_pressed.emit()


func menu_action() -> void:
	menu_pressed.emit()


func set_running(value: bool) -> void:
	_running = value


func hotbar_action(index: int) -> void:
	equip_index(index)


func equip_index(index: int) -> bool:
	var ids := weapon_ids()
	if index < 0 or index >= ids.size():
		return false
	return equip(str(ids[index]))


func weapon_ids() -> Array:
	var ids: Array = []
	if item_db != null and item_db.has_method("list") and item_db.has_method("get_def"):
		for raw_id in item_db.list():
			var id := str(raw_id)
			var def: Dictionary = item_db.get_def(id)
			var tags: Array = def.get("tags", [])
			if tags.has("weapon") and (inventory == null or not inventory.has_method("count") or int(inventory.count(id)) > 0):
				ids.append(id)
	if ids.is_empty():
		var weapons_script := _safe_script(WEAPON_DB_PATH)
		if weapons_script != null and weapons_script.has_method("list_ids"):
			for raw_id in weapons_script.list_ids():
				var id := str(raw_id)
				if inventory == null or not inventory.has_method("count") or int(inventory.count(id)) > 0:
					ids.append(id)
	ids.sort()
	return ids


func set_drive_input(throttle: float, steer: float, brake: float) -> void:
	_drive_input = Vector3(throttle, steer, brake)


func _unhandled_input(event: InputEvent) -> void:
	if vehicle != null or _dead:
		return
	if event is InputEventMouseMotion and not _is_touch_platform() and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var e := event as InputEventMouseMotion
		look_action(e.relative)
	elif event is InputEventKey:
		var e := event as InputEventKey
		if e.pressed and not e.echo:
			match e.keycode:
				KEY_SPACE:
					jump_action()
				KEY_E:
					interact_action()
				KEY_R:
					reload_action()
				KEY_ESCAPE:
					menu_action()
	elif event is InputEventMouseButton and not _is_touch_platform():
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT:
			_fire_held = e.pressed
			if e.pressed:
				fire_action()


func _physics_process(delta: float) -> void:
	if vehicle != null:
		var drive := _drive_input
		if drive == Vector3.ZERO:
			drive = _keyboard_drive()
		if vehicle.has_method("set_drive_input"):
			vehicle.call("set_drive_input", drive.x, drive.y, drive.z)
		return
	if _dead:
		velocity = Vector3.ZERO
		return
	var axis := _move_input
	if axis == Vector2.ZERO:
		axis = _keyboard_move()
	var running := _running or Input.is_key_pressed(KEY_SHIFT)
	var speed := run_speed if running else walk_speed
	var local := Vector3(axis.x, 0.0, -axis.y)
	if local.length_squared() > 1.0:
		local = local.normalized()
	var direction := transform.basis * local
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	if _jump_queued:
		if is_on_floor():
			velocity.y = jump_velocity
		_jump_queued = false
	move_and_slide()
	_update_viewmodel_walk()


func _process(delta: float) -> void:
	if _dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			respawn()
		return
	if _fire_held and vehicle == null and not equipped_weapon.is_empty():
		var def := _weapon_def(equipped_weapon)
		if bool(def.get("auto", false)):
			fire()


func _keyboard_move() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		v.y += 1.0
	if Input.is_key_pressed(KEY_S):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_A):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		v.x += 1.0
	return v


func _keyboard_drive() -> Vector3:
	var throttle := 0.0
	var steer := 0.0
	var brake := 0.0
	if Input.is_key_pressed(KEY_W):
		throttle += 1.0
	if Input.is_key_pressed(KEY_S):
		throttle -= 1.0
	if Input.is_key_pressed(KEY_D):
		steer += 1.0
	if Input.is_key_pressed(KEY_A):
		steer -= 1.0
	if Input.is_key_pressed(KEY_SPACE):
		brake = 1.0
	return Vector3(throttle, steer, brake)


func take_damage(amount: float, point: Vector3 = Vector3.ZERO, normal: Vector3 = Vector3.UP, source: Node = null) -> void:
	if amount <= 0.0 or health <= 0.0 or _dead:
		return
	health = maxf(health - amount, 0.0)
	damaged.emit(amount, point, normal)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	_respawn_timer = respawn_delay
	died.emit()


func respawn(at: Variant = null) -> void:
	var target: Vector3 = _spawn_position
	if at is Vector3:
		target = at
	global_position = target
	velocity = Vector3.ZERO
	health = max_health
	_dead = false
	_respawn_timer = 0.0
	_jump_queued = false
	_move_input = Vector2.ZERO
	_fire_held = false
	health_changed.emit(health, max_health)


func equip(item_id: String) -> bool:
	if item_id.is_empty() or _dead:
		return false
	if inventory != null and inventory.has_method("count") and int(inventory.count(item_id)) <= 0:
		return false
	equipped_weapon = item_id
	if _viewmodel_has_model(item_id) and viewmodel.has_method("set_weapon"):
		viewmodel.call("set_weapon", item_id)
	weapon_changed.emit(item_id)
	_emit_ammo()
	return true


func _weapon_def(item_id: String) -> Dictionary:
	var weapons_script := _safe_script(WEAPON_DB_PATH)
	if weapons_script != null and weapons_script.has_method("get_def"):
		var def = weapons_script.get_def(item_id)
		if def is Dictionary:
			return def
	return {}


func weapon_name() -> String:
	if item_db != null and item_db.has_method("get_def"):
		var def: Dictionary = item_db.get_def(equipped_weapon)
		var label := str(def.get("nombre", def.get("name", "")))
		if not label.is_empty():
			return label
	return str(_weapon_def(equipped_weapon).get("name", equipped_weapon))


func weapon_system() -> Node:
	return _get_weapon_system()


func _get_weapon_system() -> Node:
	if _weapon_system != null and is_instance_valid(_weapon_system):
		return _weapon_system
	var script := _safe_script(WEAPON_SYSTEM_PATH)
	if script == null:
		return null
	var node := Node.new()
	node.set_script(script)
	if not node.has_method("fire"):
		node.free()
		return null
	add_child(node)
	_weapon_system = node
	return node


func current_ammo() -> int:
	var ws := _get_weapon_system()
	if ws == null or not ws.has_method("ammo") or equipped_weapon.is_empty():
		return -1
	return int(ws.call("ammo", equipped_weapon))


func current_reserve() -> int:
	var ws := _get_weapon_system()
	if ws == null or not ws.has_method("reserve") or equipped_weapon.is_empty():
		return 0
	return int(ws.call("reserve", equipped_weapon))


func is_reloading() -> bool:
	var ws := _get_weapon_system()
	if ws == null or not ws.has_method("is_reloading") or equipped_weapon.is_empty():
		return false
	return bool(ws.call("is_reloading", equipped_weapon))


func reload() -> bool:
	if _dead or equipped_weapon.is_empty():
		return false
	var ws := _get_weapon_system()
	if ws == null or not ws.has_method("reload"):
		return false
	var started := bool(ws.call("reload", equipped_weapon))
	if started:
		var duration: float = maxf(float(_weapon_def(equipped_weapon).get("reload_time", 1.0)), 0.05)
		if viewmodel != null and is_instance_valid(viewmodel) and viewmodel.has_method("on_reload_started"):
			viewmodel.call("on_reload_started", duration)
		var synth := _safe_script(SFX_BANK_PATH)
		var audio_host: Node3D = get_parent() as Node3D
		if audio_host == null:
			audio_host = self
		if synth != null and synth.has_method("play_synth"):
			synth.call("play_synth", audio_host, "reload", equipped_weapon, global_position, "sfx")
		reloaded.emit(equipped_weapon)
	return started


func reload_action() -> void:
	reload()


func _emit_ammo() -> void:
	ammo_changed.emit(current_ammo(), current_reserve())


func fire() -> void:
	if _dead or equipped_weapon.is_empty() or vehicle != null:
		return
	var ws := _get_weapon_system()
	if ws == null:
		return
	var def := _weapon_def(equipped_weapon)
	if bool(def.get("uses_ammo", true)) and int(ws.call("ammo", equipped_weapon)) <= 0:
		_on_empty_fire()
		return
	var world := get_world_3d()
	if world == null:
		return
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	if space == null:
		return
	var origin: Vector3 = camera.global_position if camera != null else global_position
	var direction: Vector3 = -camera.global_transform.basis.z if camera != null else -global_transform.basis.z
	var result = ws.call("fire", equipped_weapon, origin, direction, space, [self])
	if not result is Dictionary:
		return
	var shot: Dictionary = result
	_emit_ammo()
	if bool(shot.get("fired", false)):
		if viewmodel != null and is_instance_valid(viewmodel) and viewmodel.has_method("on_fired"):
			viewmodel.call("on_fired")
		fired.emit(shot)
		_play_shot_sound(origin)
	elif str(shot.get("error", "")).find("municion") >= 0:
		_on_empty_fire()


func _on_empty_fire() -> void:
	if viewmodel != null and is_instance_valid(viewmodel) and viewmodel.has_method("on_empty"):
		viewmodel.call("on_empty")
	empty.emit(equipped_weapon)


func _play_shot_sound(pos: Vector3) -> void:
	var host: Node = get_parent() if get_parent() != null else self
	RecordedSfx.play(equipped_weapon, "fire", host, pos)
	if not RecordedSfx.has_sample(equipped_weapon, "fire"):
		var bank := _safe_script(SFX_BANK_PATH)
		var audio_host: Node3D = get_parent() as Node3D
		if audio_host == null:
			audio_host = self
		if bank != null and bank.has_method("play_synth"):
			bank.call("play_synth", audio_host, "shot", equipped_weapon, pos, "sfx")
	if RecordedSfx.has_sample(equipped_weapon, "pump"):
		var id := equipped_weapon
		get_tree().create_timer(0.4).timeout.connect(func() -> void:
			if is_inside_tree() and equipped_weapon == id:
				RecordedSfx.play(id, "pump", host, global_position))


func enter_vehicle(v: Node3D) -> void:
	if v == null or not is_instance_valid(v):
		return
	if vehicle != null and vehicle != v:
		exit_vehicle()
	if v.has_method("enter") and not bool(v.call("enter", self)):
		return
	vehicle = v
	velocity = Vector3.ZERO
	_move_input = Vector2.ZERO
	_drive_input = Vector3.ZERO
	_jump_queued = false


func exit_vehicle() -> void:
	if vehicle == null:
		return
	var v: Node3D = vehicle
	vehicle = null
	if v != null and is_instance_valid(v) and v.has_method("exit"):
		v.call("exit")
	if v != null and is_instance_valid(v):
		global_position = v.global_position + Vector3(2.0, 1.0, 0.0)
	velocity = Vector3.ZERO
	_drive_input = Vector3.ZERO
