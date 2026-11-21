class_name VrGameMode
extends RefCounted

const RemoteLog = preload("res://core/debug/remote_log.gd")
const OnboardingScript = preload("res://core/vr/vr_onboarding.gd")
const CalibrationScript = preload("res://core/vr/vr_calibration.gd")
const BOOTSTRAP_PATH: String = "res://core/vr/vr_bootstrap.gd"
const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const SESSION_PATH: String = "res://core/game/game_session.gd"
const GameSessionScript = preload("res://core/game/game_session.gd")
const VrRigScript = preload("res://core/vr/vr_rig.gd")
const VrHudScript = preload("res://core/vr/vr_hud.gd")
const VrMenuScript = preload("res://core/vr/vr_menu.gd")
const WeaponSystemScript = preload("res://core/game/weapon_system.gd")
const ItemDbScript = preload("res://core/game/item_db.gd")
const InventoryScript = preload("res://core/game/inventory.gd")
const LoadoutScript = preload("res://core/game/loadout.gd")
const DbScript = preload("res://core/game/weapon_db.gd")
const GeneratorScript = preload("res://core/maps/map_generator.gd")
const ThemesScript = preload("res://core/maps/map_themes.gd")
const VrVehicleInputScript = preload("res://core/vr/vr_vehicle_input.gd")
const VrComfortScript = preload("res://core/vr/vr_comfort.gd")

const PAUSE_BUTTONS: Array = [
	{"id": "resume", "label": "REANUDAR", "rect": Rect2(-0.13, -0.12, 0.26, 0.07)},
	{"id": "map", "label": "CAMBIAR MAPA", "rect": Rect2(-0.13, -0.03, 0.26, 0.07)},
	{"id": "gore", "label": "GORE ON/OFF", "rect": Rect2(-0.13, 0.06, 0.26, 0.07)},
	{"id": "quit", "label": "SALIR", "rect": Rect2(-0.13, 0.15, 0.26, 0.07)},
]
const START_BUTTONS: Array = [
	{"id": "play", "label": "JUGAR", "rect": Rect2(-0.2, 0.05, 0.4, 0.08)},
	{"id": "map_next", "label": "CAMBIAR MAPA", "rect": Rect2(-0.2, -0.06, 0.4, 0.08)},
	{"id": "recalibrate", "label": "RECALIBRAR", "rect": Rect2(-0.2, -0.17, 0.4, 0.08)},
]

# La oficina (Ciudad con la Oficina Central) es siempre la primera opcion.
const MAP_CHOICES: Array = [
	{"label": "OFICINA", "theme": "urbano", "seed": 1001, "office": true},
	{"label": "CIUDAD", "theme": "urbano", "seed": 1001, "office": false},
	{"label": "INDUSTRIAL", "theme": "industrial", "seed": 2002, "office": false},
	{"label": "RURAL", "theme": "rural", "seed": 3003, "office": false},
	{"label": "ARENA", "theme": "", "seed": 4242, "office": false},
]

static var xr_available_override: Callable = Callable()
static var last_start_menu = null


class State extends Node:
	var world: Node3D = null
	var rig: Node3D = null
	var weapon_system: Node = null
	var bag = null
	var hud = null
	var menu = null
	var hands: Dictionary = {}
	var selected_meta: Dictionary = {}
	var current_weapon: String = ""
	var onboarding = null
	var flat_ui_removed: int = 0
	var flat_ui_guard: Callable = Callable()
	var _guard_time: float = 0.0
	var vehicle_input = null
	var vehicle_spawn_menu = null
	var _spawn_button_down: bool = false
	var _interact_button_down: bool = false
	var _grab_prev: bool = false
	var _last_camera_basis: Basis = Basis.IDENTITY
	var _eye_timer: float = 0.0
	var _eye_done: bool = false


	func configure(p_world: Node3D, p_rig: Node3D, p_ws: Node, p_meta: Dictionary) -> void:
		world = p_world
		rig = p_rig
		weapon_system = p_ws
		selected_meta = p_meta.duplicate(true)
		bag = rig.get("bag")
		hands["left"] = rig.get("left_hand")
		hands["right"] = rig.get("right_hand")
		weapon_system.set("manual_cycle", true)
		for hand_name in hands:
			var weapon_hand = hands[hand_name]
			if weapon_hand != null:
				weapon_hand.manual_gesture_reload = true
				weapon_hand._ensure_reload_system()
		_setup_hud()
		_setup_menu()
		_setup_onboarding()
		_connect_signals()
		_setup_vehicle_input()
		refresh_hud()


	func _setup_hud() -> void:
		hud = VrHudScript.new()
		hud.name = "VrHud"
		world.add_child(hud)
		hud.build()
		var left = rig.call("controller_for", "left")
		var right = rig.call("controller_for", "right")
		if left != null:
			hud.mount_health(left)
		if right != null:
			hud.mount_laser(right)
			hud.set_laser_length(1.0)
		hud.set_laser_enabled(false)
		hud.set_health(float(rig.get("health")), float(rig.get("max_health")))


	func _setup_menu() -> void:
		menu = VrMenuScript.new()
		menu.name = "VrMenu"
		world.add_child(menu)
		menu.set_buttons(PAUSE_BUTTONS)
		menu.build()
		_connect_once(rig, "menu_pressed", Callable(self, "toggle_menu"))
		_connect_once(rig, "health_changed", Callable(self, "on_health_changed"))
		_connect_once(menu, "button_pressed", Callable(self, "on_menu_button"))
		_connect_once(menu, "closed", Callable(self, "on_menu_closed"))


	func _connect_signals() -> void:
		if weapon_system != null:
			_connect_once(weapon_system, "empty", Callable(self, "on_empty"))
			_connect_once(weapon_system, "reload_started", Callable(self, "on_reload_started"))
			_connect_once(weapon_system, "reload_finished", Callable(self, "on_reload_finished"))
			_connect_once(weapon_system, "impact", Callable(self, "on_impact"))
		for hand in hands.values():
			if hand == null:
				continue
			_connect_once(hand, "weapon_taken", Callable(self, "on_weapon_taken"))
			_connect_once(hand, "weapon_stowed", Callable(self, "on_weapon_stowed"))
			_connect_once(hand, "fired", Callable(self, "on_fired"))


	func _connect_once(target: Node, signal_name: String, callable: Callable) -> void:
		if target != null and target.has_signal(signal_name) and not target.is_connected(signal_name, callable):
			target.connect(signal_name, callable)


	func _setup_onboarding() -> void:
		var calibration = rig.get_meta("calibration", null)
		var holsters = hands["right"].holsters if hands["right"] != null else null
		onboarding = OnboardingScript.new()
		onboarding.name = "VrOnboarding"
		world.add_child(onboarding)
		var ids: Array = bag.call("items") if bag != null else DbScript.list_ids()
		onboarding.configure(holsters, weapon_system, ids, calibration.dominant_hand() if calibration != null else "right")
		onboarding.equip_requested.connect(func(id: String) -> void:
			var hand = hands["right"]
			if hand != null and str(hand.weapon_id).is_empty():
				hand.try_take(id))


	func tick(delta: float) -> void:
		if rig == null or not is_instance_valid(rig):
			return
		if onboarding != null and rig.xr_camera != null:
			var poses := {"left": rig.get_pose("left"), "right": rig.get_pose("right")}
			var triggers := {"left": 1.0 if rig.is_trigger_pressed("left") else 0.0, "right": 1.0 if rig.is_trigger_pressed("right") else 0.0}
			onboarding.tick(delta, rig.xr_camera.global_transform, poses, triggers)
		_guard_time += maxf(delta, 0.0)
		if _guard_time >= 1.0:
			_guard_time = 0.0
			if flat_ui_guard.is_valid():
				flat_ui_removed += int(flat_ui_guard.call(world))
		rig.call("step", delta)
		_auto_eye_height(delta)
		if weapon_system != null and is_instance_valid(weapon_system):
			weapon_system.call("advance", maxf(delta, 0.0))
		_update_vehicle_control(maxf(delta, 0.0))
		_sync_input_suspension()
		refresh_hud()
		_update_pointer()
		if hud != null:
			hud.decay_vignette(delta)


	# Sin perfil guardado: fundas y bolso se ajustan a la altura real de la cabeza (sin calibracion guiada).
	func _auto_eye_height(delta: float) -> void:
		if _eye_done or rig == null or rig.xr_camera == null:
			return
		_eye_timer += maxf(delta, 0.0)
		if _eye_timer < 2.0:
			return
		_eye_done = true
		var calibration = rig.get_meta("calibration", null)
		if calibration == null or calibration.last_status == "ok":
			return
		var eye: float = rig.xr_camera.global_position.y - rig.global_position.y
		if eye < CalibrationScript.EYE_RANGE.x or eye > CalibrationScript.EYE_RANGE.y:
			return
		calibration.profile["eye_height"] = eye
		calibration.apply_to_bag(bag)
		for hand in hands.values():
			if hand != null and hand.holsters != null and "offsets" in hand.holsters:
				hand.holsters.offsets = calibration.slot_offsets()


	func refresh_hud() -> void:
		if hud == null:
			return
		if rig != null and is_instance_valid(rig):
			hud.set_health(float(rig.get("health")), float(rig.get("max_health")))
		var held: String = "" if bag == null else str(bag.call("held_item"))
		if held != current_weapon:
			current_weapon = held
			if held.is_empty():
				hud.set_ammo_visible(false)
			else:
				var hand_name: String = "right" if str(bag.call("held_in", "right")) == held else "left"
				_mount_ammo(hand_name)
		if held.is_empty() or weapon_system == null:
			return
		var info: Dictionary = weapon_system.call("ammo_info", held)
		hud.set_ammo(
			int(info.get("mag", 0)), int(info.get("mag_size", 0)),
			int(info.get("reserve", 0)), bool(info.get("infinite", false))
		)
		if bool(info.get("reloading", false)):
			hud.set_reload(true, float(info.get("reload_progress", 0.0)))
		else:
			hud.set_reload(false, 0.0)


	func _mount_ammo(hand_name: String) -> void:
		var hand = hands.get(hand_name, null)
		if hand == null or hud == null:
			return
		var holder = hand.get("holder")
		if holder != null:
			hud.mount_ammo(holder)
			hud.set_ammo_visible(true)


	func _active_menu():
		if vehicle_spawn_menu != null and is_instance_valid(vehicle_spawn_menu) and bool(vehicle_spawn_menu.get("is_open")):
			return vehicle_spawn_menu
		if menu != null and is_instance_valid(menu) and bool(menu.get("is_open")):
			return menu
		return null


	func _update_pointer() -> void:
		var active = _active_menu()
		if active == null or hud == null or rig == null:
			if hud != null:
				hud.set_laser_enabled(false)
			return
		var controller = rig.call("controller_for", "right")
		if controller == null:
			return
		var origin: Vector3 = controller.global_transform.origin
		var direction: Vector3 = -controller.global_transform.basis.z
		var hit: Dictionary = active.call("pointer_hit", origin, direction)
		var length: float = 2.0
		if bool(hit.get("hit", false)):
			length = clampf(origin.distance_to(hit.get("point", origin)), 0.15, 3.0)
		hud.set_laser_length(length)
		hud.set_laser_enabled(true)
		active.call("try_press", origin, direction, bool(rig.call("is_trigger_pressed", "right")))


	func toggle_menu() -> void:
		if menu == null:
			return
		if bool(menu.get("is_open")):
			menu.call("close_menu")
			return
		var position := Vector3.ZERO
		var forward := Vector3.FORWARD
		var camera = rig.get("xr_camera") if rig != null else null
		if camera != null:
			position = camera.global_position
			forward = -camera.global_transform.basis.z
		elif rig != null:
			position = rig.global_position + Vector3(0.0, 1.6, 0.0)
		menu.call("open_in_front", position, forward)
		if rig != null:
			rig.call("set_inputs_suspended", true)


	func on_menu_closed() -> void:
		_sync_input_suspension()


	func _setup_vehicle_input() -> void:
		if vehicle_input != null:
			return
		vehicle_input = VrVehicleInputScript.new()
		vehicle_input.spawn_requested.connect(Callable(self, "_on_vehicle_spawn_requested"))


	func open_vehicle_spawn_menu() -> void:
		if world == null or not is_instance_valid(world):
			return
		_setup_vehicle_input()
		if vehicle_spawn_menu == null or not is_instance_valid(vehicle_spawn_menu):
			vehicle_spawn_menu = vehicle_input.build_spawn_menu(world)
			if vehicle_spawn_menu != null and vehicle_spawn_menu.has_signal("closed"):
				_connect_once(vehicle_spawn_menu, "closed", Callable(self, "_sync_input_suspension"))
		if vehicle_spawn_menu == null:
			return
		var position := Vector3.ZERO
		var forward := Vector3.FORWARD
		var camera = rig.get("xr_camera") if rig != null else null
		if camera != null:
			position = camera.global_position
			forward = -camera.global_transform.basis.z
		elif rig != null:
			position = rig.global_position + Vector3(0.0, 1.6, 0.0)
		vehicle_spawn_menu.call("open_in_front", position, forward)
		_sync_input_suspension()


	func _on_vehicle_spawn_requested(vehicle_id: String) -> void:
		if world != null and is_instance_valid(world) and world.has_method("spawn_vehicle_in_front"):
			world.call("spawn_vehicle_in_front", vehicle_id)
		if vehicle_spawn_menu != null and is_instance_valid(vehicle_spawn_menu) \
			and bool(vehicle_spawn_menu.get("is_open")):
			vehicle_spawn_menu.call("close_menu")
		_sync_input_suspension()


	func _controller_button(hand: String, button: StringName) -> bool:
		if rig == null or not is_instance_valid(rig):
			return false
		if rig.has_method("_controller_button"):
			return bool(rig.call("_controller_button", hand, button))
		var controller = rig.call("controller_for", hand)
		if controller != null and controller.has_method("is_button_pressed"):
			return bool(controller.call("is_button_pressed", button))
		return false


	func _grip_axis(hand: String) -> float:
		if rig == null or not is_instance_valid(rig):
			return 0.0
		var controller = rig.call("controller_for", hand)
		if controller != null and controller.has_method("get_float"):
			return clampf(float(controller.call("get_float", &"grip")), 0.0, 1.0)
		return 1.0 if bool(rig.call("is_grip_pressed", hand)) else 0.0


	func _trigger_axis(hand: String) -> float:
		if rig == null or not is_instance_valid(rig):
			return 0.0
		var controller = rig.call("controller_for", hand)
		if controller != null and controller.has_method("get_float"):
			return clampf(float(controller.call("get_float", &"trigger")), 0.0, 1.0)
		return 1.0 if bool(rig.call("is_trigger_pressed", hand)) else 0.0


	func _head_yaw_rate(delta: float) -> float:
		if rig == null or not is_instance_valid(rig) or rig.xr_camera == null or delta <= 0.0:
			return 0.0
		var current: Basis = rig.xr_camera.global_transform.basis
		var previous: Basis = _last_camera_basis
		_last_camera_basis = current
		if previous == Basis.IDENTITY:
			return 0.0
		var before_yaw: float = atan2(-previous.z.x, previous.z.z)
		var now_yaw: float = atan2(-current.z.x, current.z.z)
		return VrVehicleInputScript.wrap_angle(now_yaw - before_yaw) / delta


	func _vehicle_near(point: Vector3, radius: float = 1.0) -> Node3D:
		if world == null or not is_instance_valid(world) or not world.has_method("vehicles"):
			return null
		var best: Node3D = null
		var best_distance: float = radius
		for vehicle in world.call("vehicles"):
			if not (vehicle is Node3D) or not is_instance_valid(vehicle):
				continue
			if not (vehicle as Node3D).has_method("door_position"):
				continue
			var distance: float = (vehicle as Node3D).door_position().distance_to(point)
			if distance < best_distance:
				best_distance = distance
				best = vehicle as Node3D
		return best


	func _spawn_button_pressed() -> bool:
		return _controller_button("left", &"y")


	func _exit_button_pressed() -> bool:
		return _controller_button("left", &"x") or _controller_button("right", &"b")


	func _update_vehicle_control(delta: float) -> void:
		if rig == null or not is_instance_valid(rig) or vehicle_input == null:
			return
		var spawn_down: bool = _spawn_button_pressed()
		if spawn_down and not _spawn_button_down and not bool(vehicle_input.driving):
			open_vehicle_spawn_menu()
		_spawn_button_down = spawn_down
		if _active_menu() != null:
			_grab_prev = false
			_interact_button_down = _exit_button_pressed()
			return
		if not bool(vehicle_input.driving):
			var grabbed: bool = _grip_axis("left") > 0.6 or _trigger_axis("left") > 0.6
			var target: Node3D = null
			var hand_position: Vector3 = Vector3.ZERO
			for hand in ["left", "right"]:
				var pose: Variant = rig.call("get_pose", hand)
				if not (pose is Transform3D):
					continue
				var candidate: Node3D = _vehicle_near((pose as Transform3D).origin)
				if candidate != null:
					target = candidate
					hand_position = (pose as Transform3D).origin
					break
			if grabbed and not _grab_prev and target != null:
				vehicle_input.try_enter(hand_position, target, rig, true)
			_grab_prev = grabbed
			_interact_button_down = false
			return
		var poses: Dictionary = {
			"left": rig.call("get_pose", "left"),
			"right": rig.call("get_pose", "right"),
		}
		var grips: Dictionary = {
			"left": _grip_axis("left"),
			"right": _grip_axis("right"),
		}
		var triggers: Dictionary = {
			"left": _trigger_axis("left"),
			"right": _trigger_axis("right"),
		}
		vehicle_input.update(delta, poses, grips, triggers, _head_yaw_rate(delta))
		var exit_pressed: bool = _exit_button_pressed()
		var door_grab: bool = false
		var left_pose: Variant = rig.call("get_pose", "left")
		if left_pose is Transform3D and grips["left"] > 0.6:
			door_grab = _vehicle_near((left_pose as Transform3D).origin, 0.6) != null
		if (exit_pressed or door_grab) and not _interact_button_down:
			if float(vehicle_input.vehicle.call("speed")) <= VrVehicleInputScript.EXIT_MAX_SPEED:
				vehicle_input.exit()
		_interact_button_down = exit_pressed or door_grab


	func _sync_input_suspension() -> void:
		if rig == null or not is_instance_valid(rig):
			return
		var wanted: bool = _active_menu() != null or (vehicle_input != null and bool(vehicle_input.driving))
		if bool(rig.get("inputs_suspended")) != wanted:
			rig.call("set_inputs_suspended", wanted)


	func on_menu_button(button_id: String) -> void:
		match button_id:
			"resume":
				if menu != null:
					menu.call("close_menu")
			"gore":
				GameSessionScript.gore_enabled = not GameSessionScript.gore_enabled
			"map":
				_start_next_map()
			"quit":
				get_tree().quit(0)


	func _start_next_map() -> void:
		var next_index: int = int(selected_meta.get("choice_index", 0)) + 1
		var choice: Dictionary = MAP_CHOICES[posmod(next_index, MAP_CHOICES.size())]
		var params: Dictionary = {
			"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 4,
		}
		var meta: Dictionary
		var theme: String = str(choice["theme"])
		if theme.is_empty():
			meta = GeneratorScript.generate(int(choice["seed"]), params)
		else:
			params["theme"] = theme
			params["theme_density"] = 0.55
			params["time_of_day"] = "dia"
			meta = ThemesScript.generate(int(choice["seed"]), params)
		if not bool(meta.get("ok", false)):
			return
		meta["choice_index"] = posmod(next_index, MAP_CHOICES.size())
		meta["choice_label"] = str(choice["label"])
		if bool(choice["office"]):
			var office: Dictionary = (meta.get("theme_data", {}) as Dictionary).get("office", {})
			var inside: Array = office.get("spawns", [])
			if not inside.is_empty():
				var points: Array = (meta.get("spawn_points", []) as Array).duplicate()
				var spot: Vector3 = inside[0]
				points.push_front(Vector3(spot.x, 0.0, spot.z))
				meta["spawn_points"] = points
				meta["office_spawn"] = true
		GameSessionScript.vr_menu_confirmed = true
		GameSessionScript.start(meta, get_tree())


	func on_health_changed(current: float, maximum: float) -> void:
		if hud != null:
			hud.set_health(current, maximum)


	func on_weapon_taken(_weapon_id: String, hand_name: String) -> void:
		_mount_ammo(hand_name)
		refresh_hud()


	func on_weapon_stowed(_weapon_id: String, _hand_name: String) -> void:
		current_weapon = ""
		refresh_hud()


	func on_fired(_result: Dictionary) -> void:
		refresh_hud()


	func on_empty(_weapon_id: String) -> void:
		refresh_hud()


	func on_reload_started(_weapon_id: String) -> void:
		if hud != null:
			hud.set_reload(true, 0.0)


	func on_reload_finished(_weapon_id: String) -> void:
		if hud != null:
			hud.set_reload(false, 0.0)
		refresh_hud()


	func show_subtitle(text: String, npc: String) -> void:
		if hud != null:
			hud.call("show_subtitle", text, npc)


	func on_impact(info: Dictionary) -> void:
		if hud == null or rig == null or not bool(info.get("hit", false)):
			return
		var amount: float = float(info.get("damage", 0.0))
		if amount <= 0.0:
			return
		var camera = rig.get("xr_camera")
		if camera == null:
			return
		var point: Vector3 = info.get("position", Vector3.ZERO)
		hud.register_damage(
			-camera.global_transform.basis.z, camera.global_transform.basis.x,
			camera.global_position, point, clampf(amount / 50.0, 0.1, 1.0)
		)


class StartMenuHost extends Node3D:
	var menu = null
	var camera: Camera3D = null
	var chosen_meta: Dictionary = {}
	var beam: MeshInstance3D = null


	func configure(p_menu, p_camera: Camera3D, p_meta: Dictionary, p_beam: MeshInstance3D) -> void:
		menu = p_menu
		camera = p_camera
		chosen_meta = p_meta.duplicate(true)
		beam = p_beam
		if menu != null and menu.has_signal("button_pressed"):
			menu.connect("button_pressed", Callable(self, "on_button"))


	func on_button(button_id: String) -> void:
		if button_id == "recalibrate":
			return
		if button_id == "map_next":
			var next_index: int = int(chosen_meta.get("choice_index", 0)) + 1
			var choice: Dictionary = MAP_CHOICES[posmod(next_index, MAP_CHOICES.size())]
			var params: Dictionary = {
				"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 4,
			}
			var meta: Dictionary
			var theme: String = str(choice["theme"])
			if theme.is_empty():
				meta = GeneratorScript.generate(int(choice["seed"]), params)
			else:
				params["theme"] = theme
				params["theme_density"] = 0.55
				params["time_of_day"] = "dia"
				meta = ThemesScript.generate(int(choice["seed"]), params)
			if not bool(meta.get("ok", false)):
				return
			meta["choice_index"] = posmod(next_index, MAP_CHOICES.size())
			meta["choice_label"] = str(choice["label"])
			if bool(choice["office"]):
				var office: Dictionary = (meta.get("theme_data", {}) as Dictionary).get("office", {})
				var inside: Array = office.get("spawns", [])
				if not inside.is_empty():
					var points: Array = (meta.get("spawn_points", []) as Array).duplicate()
					var spot: Vector3 = inside[0]
					points.push_front(Vector3(spot.x, 0.0, spot.z))
					meta["spawn_points"] = points
					meta["office_spawn"] = true
			chosen_meta = meta
			if menu != null and menu.has_method("set_buttons"):
				var labeled: Array = START_BUTTONS.duplicate(true)
				menu.call("set_buttons", labeled)
			return
		if button_id == "play":
			GameSessionScript.vr_menu_confirmed = true
			GameSessionScript.start(chosen_meta.duplicate(true), get_tree())


	func _unhandled_input(event: InputEvent) -> void:
		if menu == null or camera == null or not bool(menu.get("is_open")):
			return
		if event is InputEventMouseMotion:
			var motion := event as InputEventMouseMotion
			_update_beam(camera.project_ray_origin(motion.position), camera.project_ray_normal(motion.position))
		elif event is InputEventMouseButton:
			var click := event as InputEventMouseButton
			if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
				return
			var origin := camera.project_ray_origin(click.position)
			var direction := camera.project_ray_normal(click.position)
			_update_beam(origin, direction)
			menu.call("try_press", origin, direction, true)


	func _update_beam(origin: Vector3, direction: Vector3) -> void:
		if beam == null or menu == null:
			return
		var hit: Dictionary = menu.call("pointer_hit", origin, direction)
		var length: float = 2.0
		if bool(hit.get("hit", false)):
			length = clampf(origin.distance_to(hit.get("point", origin)), 0.15, 3.0)
		beam.scale.y = length
		beam.position.z = -length * 0.5


static func xr_available() -> bool:
	if xr_available_override.is_valid():
		return bool(xr_available_override.call())
	if not ClassDB.class_exists("XRServer") or not ClassDB.class_exists("OpenXRInterface"):
		return false
	var interface = XRServer.find_interface("OpenXR")
	if interface == null:
		return false
	if interface.has_method("is_initialized") and not bool(interface.call("is_initialized")):
		return false
	return true


static func should_use_vr() -> bool:
	var platform: String = ""
	var session: Script = null
	if ResourceLoader.exists(SESSION_PATH):
		session = load(SESSION_PATH) as Script
	if session != null:
		platform = str(session.get("platform"))
		if platform.is_empty() and session.has_method("detect_platform"):
			platform = str(session.call("detect_platform"))
	return platform == "vr" and xr_available()


static func build(world: Node3D, available: bool) -> Node3D:
	if available:
		var rig = VrRigScript.new()
		rig.name = "Player"
		rig.auto_process = false
		rig.xr_availability_override = func() -> bool: return true
		if rig.build():
			world.add_child(rig)
			return rig
		rig.queue_free()
	return _build_player(world)


static func _build_player(world: Node3D) -> Node3D:
	if ResourceLoader.exists(PLAYER_SCENE):
		var packed := load(PLAYER_SCENE) as PackedScene
		if packed != null:
			var instance := packed.instantiate()
			if instance is Node3D:
				var player := instance as Node3D
				player.name = "Player"
				world.add_child(player)
				return player
			if instance != null:
				instance.free()
	var camera := Camera3D.new()
	camera.name = "FallbackCamera"
	world.add_child(camera)
	return camera


const FLAT_UI_NAMES: Array = ["GameHud", "TouchControls", "Hotbar", "HudLayer", "TouchLayer"]
const FLAT_UI_SCRIPTS: Array = [
	"res://core/game/game_hud.gd", "res://core/game/touch_controls.gd", "res://core/game/hotbar.gd",
]


static func _is_flat_ui(node: Node) -> bool:
	if not (node is Control or node is CanvasLayer):
		return false
	var cursor: Node = node.get_parent()
	while cursor != null:
		if cursor is SubViewport:
			return false
		cursor = cursor.get_parent()
	if FLAT_UI_NAMES.has(str(node.name)) or node is CanvasLayer:
		return true
	var script: Script = node.get_script() as Script
	if script != null and FLAT_UI_SCRIPTS.has(script.resource_path):
		return true
	# cualquier Control 2D suelto en el viewport principal (p. ej. un "100" de vida)
	return node.get_parent() != null and not (node.get_parent() is Control)


# HUD plano (pantalla) prohibido en VR: la informacion va en VrHud (arma y muñeca).
static func flat_ui_nodes(container: Node) -> Array:
	var found: Array = []
	if container == null:
		return found
	for node in container.find_children("*", "", true, false):
		if _is_flat_ui(node):
			found.append(node)
	return found


static func strip_flat_ui(container: Node) -> int:
	var removed: int = 0
	for node in flat_ui_nodes(container):
		if is_instance_valid(node) and node.get_parent() != null:
			node.get_parent().remove_child(node)
			node.queue_free()
			removed += 1
	return removed


# Coloca fundas y bolso segun el perfil guardado (defaults si falta o esta corrupto).
static func apply_calibration(rig: Node3D, path: String = "") -> bool:
	var calibration = CalibrationScript.new()
	if not path.is_empty():
		calibration.profile_path = path
	var loaded: bool = bool(calibration.load_profile())
	var bag = rig.get("bag")
	if bag != null:
		calibration.apply_to_bag(bag)
	for hand_name in ["left_hand", "right_hand"]:
		var hand = rig.get(hand_name)
		if hand != null:
			hand.holsters = calibration.make_holsters()
	rig.set_meta("calibration", calibration)
	return loaded


# Perfil de confort VR: valida con VrComfort y aplica al rig.
static func apply_comfort_profile(rig: Node3D, profile: Dictionary) -> Dictionary:
	var result := VrComfortScript.validate_profile(profile)
	if not result["ok"]:
		return result
	var canonical: Dictionary = result["profile"]
	var keys: Array = VrComfortScript.PROFILE_KEYS
	for key in keys:
		if canonical.has(key):
			rig.set(key, canonical[key])
	rig.set_meta("comfort_profile", canonical)
	return {"ok": true, "profile": canonical, "errors": []}


static func get_comfort_profile(rig: Node3D) -> Dictionary:
	if rig.has_meta("comfort_profile"):
		var stored = rig.get_meta("comfort_profile")
		if stored is Dictionary:
			return stored
	return VrComfortScript.default_profile()


static func apply_default_comfort_profile(rig: Node3D) -> Dictionary:
	return apply_comfort_profile(rig, VrComfortScript.default_profile())


static func setup(world: Node3D, rig: Node3D, meta: Dictionary) -> Dictionary:
	var result: Dictionary = {"rig": rig, "state": null, "weapon_system": null, "hud": null, "menu": null}
	RemoteLog.crumb("VR paso 1: entrada a setup")
	if rig == null or not is_instance_valid(rig) or not bool(rig.call("is_active")):
		return result
	RemoteLog.crumb("VR paso 2: antes strip_flat_ui")
	strip_flat_ui(world)
	RemoteLog.crumb("VR paso 3: despues strip_flat_ui")
	RemoteLog.crumb("VR paso 4: antes apply_calibration")
	apply_calibration(rig)
	RemoteLog.crumb("VR paso 5: despues apply_calibration")
	RemoteLog.crumb("VR paso 6: antes apply_default_comfort_profile")
	apply_default_comfort_profile(rig)
	RemoteLog.crumb("VR paso 7: despues apply_default_comfort_profile")
	RemoteLog.crumb("VR paso 8: antes crear WeaponSystem")
	var ws := WeaponSystemScript.new()
	ws.name = "VrWeaponSystem"
	ws.set_process(false)
	ws.spread_scale = 0.0
	RemoteLog.crumb("VR paso 9: WeaponSystem creado")
	RemoteLog.crumb("VR paso 10: antes add_child arma")
	world.add_child(ws)
	RemoteLog.crumb("VR paso 11: despues add_child arma")
	RemoteLog.crumb("VR paso 12: antes set_weapon_system")
	rig.call("set_weapon_system", ws)
	RemoteLog.crumb("VR paso 13: despues set_weapon_system")

	RemoteLog.crumb("VR paso 14: antes db/items")
	var db = ItemDbScript.new()
	DbScript.register_items(db)
	var inventory = InventoryScript.new(db, 20)
	RemoteLog.crumb("VR paso 15: db items registrados")
	LoadoutScript.give_starting_kit(inventory, db)
	RemoteLog.crumb("VR paso 16: inventario con kit")
	RemoteLog.crumb("VR paso 17: antes bag")
	var bag = rig.get("bag")
	if bag != null:
		bag.call("load_from_inventory", inventory, db)
		if (bag.call("items") as Array).is_empty():
			bag.call("set_items", DbScript.list_ids())

	RemoteLog.crumb("VR paso 18: despues bag")
	RemoteLog.crumb("VR paso 19: antes State.new")
	var state := State.new()
	state.name = "VrGameModeState"
	state.flat_ui_guard = strip_flat_ui
	RemoteLog.crumb("VR paso 20: antes add_child state")
	world.add_child(state)
	RemoteLog.crumb("VR paso 21: despues add_child state")
	RemoteLog.crumb("VR paso 22: antes state.configure")
	state.configure(world, rig, ws, meta)
	RemoteLog.crumb("VR paso 23: despues state.configure")

	# Solo la mano dominante nace armada (con ambas, la izquierda se llevaba la pistola).
	RemoteLog.crumb("VR paso 24: antes mano dominante")
	var calibration = rig.get_meta("calibration", null)
	var dominant: String = calibration.dominant_hand() if calibration != null else "right"
	var main_hand = (state.hands as Dictionary).get(dominant, null)
	if main_hand != null:
		main_hand.auto_equip = true
	RemoteLog.crumb("VR paso 25: antes armar resultado")
	result["state"] = state
	result["weapon_system"] = ws
	result["hud"] = state.hud
	result["menu"] = state.menu
	RemoteLog.crumb("VR paso 26: antes return")
	return result


static func build_start_menu(meta: Dictionary, tree: SceneTree):
	if tree == null or tree.root == null:
		return null
	var host := StartMenuHost.new()
	host.name = "VrStartMenu"
	tree.root.add_child(host)

	var camera := Camera3D.new()
	camera.name = "VrStartCamera"
	camera.position = Vector3(0.0, 1.6, 0.0)
	host.add_child(camera)
	camera.current = true
	# use_xr es del Viewport: lo activa el bootstrap solo si hay XR real
	(load(BOOTSTRAP_PATH) as Script).call("enable_viewport_xr", camera.get_viewport())

	var menu = VrMenuScript.new()
	menu.name = "VrStartMenuPanel"
	host.add_child(menu)
	menu.set_buttons(START_BUTTONS)
	menu.build()
	menu.open_in_front(Vector3(0.0, 1.6, 0.0), Vector3.FORWARD)

	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.001
	beam_mesh.bottom_radius = 0.001
	beam_mesh.height = 1.0
	var beam := MeshInstance3D.new()
	beam.name = "StartMenuLaser"
	beam.mesh = beam_mesh
	beam.rotation.x = PI * 0.5
	beam.position.z = -1.0
	camera.add_child(beam)

	host.configure(menu, camera, meta, beam)
	last_start_menu = menu
	return menu


static func default_map_meta(_seed_value: int = 4242) -> Dictionary:
	return map_choice_meta(0)


static func map_choice_meta(index: int) -> Dictionary:
	var choice: Dictionary = MAP_CHOICES[posmod(index, MAP_CHOICES.size())]
	var params: Dictionary = {
		"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 4,
	}
	var meta: Dictionary
	var theme: String = str(choice["theme"])
	if theme.is_empty():
		meta = GeneratorScript.generate(int(choice["seed"]), params)
	else:
		params["theme"] = theme
		params["theme_density"] = 0.55
		params["time_of_day"] = "dia"
		meta = ThemesScript.generate(int(choice["seed"]), params)
	if not bool(meta.get("ok", false)):
		return {}
	meta["choice_index"] = posmod(index, MAP_CHOICES.size())
	meta["choice_label"] = str(choice["label"])
	if bool(choice["office"]):
		_spawn_inside_office(meta)
	return meta


# El jugador nace dentro de la oficina; el resto de aparicion sigue como estaba.
static func _spawn_inside_office(meta: Dictionary) -> void:
	var office: Dictionary = (meta.get("theme_data", {}) as Dictionary).get("office", {})
	var inside: Array = office.get("spawns", [])
	if inside.is_empty():
		return
	var points: Array = (meta.get("spawn_points", []) as Array).duplicate()
	var spot: Vector3 = inside[0]
	points.push_front(Vector3(spot.x, 0.0, spot.z))
	meta["spawn_points"] = points
	meta["office_spawn"] = true
