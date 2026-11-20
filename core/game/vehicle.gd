class_name Vehicle
extends VehicleBody3D

# Vehiculo con modelo GLB real: ruedas del modelo (giran y viran), suspension, frenos,
# luces, claxon, volante visible, entrada/salida, daño por choque y atropello.

signal entered(driver: Node3D)
signal exited(driver: Node3D)
signal damaged(amount: float, health: float)
signal destroyed
signal horn_sounded
signal ran_over(target: Node, damage: float)

const DbScript = preload("res://core/game/vehicle_db.gd")
const GoreFxScript = preload("res://core/game/gore_fx.gd")
const WHEEL_RADIUS := 0.3
const CAR_LENGTH := 4.6
const BUGGY_LENGTH := 3.0
const MAX_STEER := 0.5
const STEER_RATE := 2.5
const ENTER_TIME := 0.35
const CRASH_THRESHOLD := 4.0
const RUN_OVER_MIN_SPEED := 3.0
const SEAT := Vector3(0.3, 0.45, -0.1)
const STEERING_WHEEL_MODEL: String = "res://assets/models/vehicles/steering_wheel.glb"
const HORN_SOUND: String = "res://assets/audio/real/horn_01.ogg"
const ENGINE_SOUND: String = "res://assets/audio/real/engine_03.ogg"

static var _horn_stream: AudioStream = null
static var _engine_stream: AudioStream = null

var vehicle_id: String = ""
var def: Dictionary = {}
var health: float = 100.0
var max_health: float = 100.0
var driver: Node3D = null
var model: Node3D = null
var wheels: Array = []
var steering_wheel: Node3D = null
var headlights: Array = []
var brake_lights: Array = []
var headlights_on: bool = false
var horn_player: AudioStreamPlayer3D = null
var engine_player: AudioStreamPlayer3D = null
var rear_door: Node3D = null
var body_size: Vector3 = Vector3(1.5, 1.1, 2.6)
var body_center: Vector3 = Vector3(0.0, 0.7, 0.0)

var _throttle: float = 0.0
var _steer_input: float = 0.0
var _brake_input: float = 0.0
var _enter_t: float = 1.0
var _enter_from: Vector3 = Vector3.ZERO
var _tail_material: StandardMaterial3D = null
var _dead: bool = false
var _car_scale: Vector3 = Vector3.ONE


func setup(id: String) -> bool:
	def = DbScript.get_def(id)
	if def.is_empty() or not ResourceLoader.exists(str(def["model_path"])):
		return false
	var packed := load(str(def["model_path"])) as PackedScene
	if packed == null:
		return false
	vehicle_id = id
	name = "Vehicle_" + id
	mass = float(def["mass"])
	max_health = float(def["health"])
	health = max_health
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, 0.25, 0.0)
	contact_monitor = true
	max_contacts_reported = 4
	add_to_group("vehicles")
	_build_model(packed)
	_build_extras()
	return true


func _build_model(packed: PackedScene) -> void:
	var source := packed.instantiate() as Node3D
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	var found: Array = []
	_collect(source, Transform3D.IDENTITY, found)
	_car_scale = _fit_scale(found)
	var body_box := AABB()
	var has_box := false
	for entry in found:
		var node: MeshInstance3D = entry["node"]
		var xform: Transform3D = entry["xform"]
		node.get_parent().remove_child(node)
		node.owner = null
		var lname := str(node.name).to_lower()
		if lname == "character":
			node.queue_free()
			continue
		if lname.begins_with("wheel-") and lname != "wheel-back":
			_make_wheel(node, xform, lname)
			continue
		xform = Transform3D(Basis.from_scale(_car_scale), Vector3.ZERO) * xform
		node.transform = xform
		model.add_child(node)
		if lname == "door":
			rear_door = node
		elif lname == "body" or lname == vehicle_id or lname.begins_with("kart"):
			var box: AABB = xform * node.get_aabb()
			body_box = box if not has_box else body_box.merge(box)
			has_box = true
	source.free()
	if has_box:
		body_size = body_box.size
		body_center = body_box.get_center()
	var shape := CollisionShape3D.new()
	shape.name = "BodyShape"
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(body_size.x, maxf(body_size.y - 0.3, 0.4), body_size.z)
	shape.shape = box_shape
	shape.position = body_center
	add_child(shape)


# El kit de coches es "chibi" (sedan 1.5 x 1.15 x 2.55 m): el cuerpo se alarga hasta un largo realista
# (ancho y alto crecen menos, las ruedas conservan su tamano).
func _fit_scale(found: Array) -> Vector3:
	var box := AABB()
	var has_box := false
	for entry in found:
		var lname := str((entry["node"] as MeshInstance3D).name).to_lower()
		if lname == "body" or lname == vehicle_id or lname.begins_with("kart"):
			var part: AABB = (entry["xform"] as Transform3D) * (entry["node"] as MeshInstance3D).get_aabb()
			box = part if not has_box else box.merge(part)
			has_box = true
	if not has_box or box.size.z < 0.1:
		return Vector3.ONE
	var target: float = BUGGY_LENGTH if str(def.get("kind", "")) == "buggy" else CAR_LENGTH
	var k: float = clampf(target / box.size.z, 1.0, 2.5)
	return Vector3(1.0 + (k - 1.0) * 0.3, 1.0 + (k - 1.0) * 0.35, k)


func _collect(node: Node, parent_xform: Transform3D, out: Array) -> void:
	for child in node.get_children():
		var local := parent_xform
		if child is Node3D:
			local = parent_xform * (child as Node3D).transform
		if child is MeshInstance3D:
			out.append({"node": child, "xform": local})
		_collect(child, local, out)


func _make_wheel(node: MeshInstance3D, xform: Transform3D, lname: String) -> void:
	var front: bool = lname.contains("front")
	var center: Vector3 = xform * node.get_aabb().get_center()
	center = Vector3(center.x * _car_scale.x, center.y, center.z * _car_scale.z)
	var wheel := VehicleWheel3D.new()
	wheel.name = "Wheel_" + lname
	wheel.position = center
	wheel.wheel_radius = WHEEL_RADIUS
	wheel.wheel_rest_length = 0.12
	wheel.suspension_travel = 0.25
	wheel.suspension_stiffness = 38.0
	wheel.suspension_max_force = float(def["mass"]) * 12.0
	wheel.damping_compression = 2.2
	wheel.damping_relaxation = 2.8
	wheel.wheel_friction_slip = 3.2 if front else 2.4
	wheel.use_as_steering = front
	wheel.use_as_traction = true
	add_child(wheel)
	wheel.add_child(node)
	node.transform = Transform3D(Basis.IDENTITY, -node.get_aabb().get_center())
	wheels.append(wheel)


func _build_extras() -> void:
	steering_wheel = Node3D.new()
	steering_wheel.name = "SteeringWheel"
	steering_wheel.position = Vector3(SEAT.x, body_center.y + 0.1, SEAT.z + 0.35)
	add_child(steering_wheel)
	_attach_steering_wheel_model()
	_set_wheel_angle(0.0)
	var front_z: float = body_center.z + body_size.z * 0.5 - 0.02
	var rear_z: float = body_center.z - body_size.z * 0.5 + 0.02
	var half: float = body_size.x * 0.5 - 0.22
	var light_y: float = body_center.y - body_size.y * 0.15
	_tail_material = _flat(Color(0.35, 0.0, 0.0), 0.0)
	_tail_material.emission_enabled = true
	_tail_material.emission = Color(1.0, 0.0, 0.0)
	_tail_material.emission_energy_multiplier = 0.2
	var head_material := _flat(Color(1.0, 0.95, 0.8), 0.0)
	head_material.emission_enabled = true
	head_material.emission = Color(1.0, 0.95, 0.75)
	head_material.emission_energy_multiplier = 0.1
	for side in [-1.0, 1.0]:
		_light_box("Headlight", Vector3(side * half, light_y, front_z), head_material)
		_light_box("Taillight", Vector3(side * half, light_y, rear_z), _tail_material)
		var spot := SpotLight3D.new()
		spot.name = "HeadSpot"
		spot.position = Vector3(side * half, light_y, front_z + 0.05)
		spot.spot_range = 22.0
		spot.spot_angle = 32.0
		spot.light_energy = 2.0
		spot.shadow_enabled = false
		spot.visible = false
		add_child(spot)
		headlights.append(spot)
	horn_player = AudioStreamPlayer3D.new()
	horn_player.name = "Horn"
	horn_player.stream = horn_stream()
	add_child(horn_player)
	var engine_audio := engine_stream()
	if engine_audio != null:
		engine_player = AudioStreamPlayer3D.new()
		engine_player.name = "Engine"
		engine_player.stream = engine_audio
		engine_player.volume_db = -60.0
		engine_player.max_distance = 30.0
		add_child(engine_player)


func _light_box(label: String, pos: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = Vector3(0.2, 0.1, 0.03)
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = pos
	add_child(mesh)
	if label == "Taillight":
		brake_lights.append(mesh)


func _flat(color: Color, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	return material


func _attach_steering_wheel_model() -> void:
	if not ResourceLoader.exists(STEERING_WHEEL_MODEL):
		return
	var packed := load(STEERING_WHEEL_MODEL) as PackedScene
	if packed == null:
		return
	var instance := packed.instantiate()
	if not (instance is Node3D):
		if instance != null:
			instance.free()
		return
	var visual := instance as Node3D
	var box := _node_aabb(visual)
	var diameter: float = maxf(box.size.x, box.size.z)
	if diameter > 0.0001:
		var factor: float = 0.38 / diameter
		visual.scale = Vector3.ONE * factor
		visual.position = -box.get_center() * factor
	steering_wheel.add_child(visual)
	steering_wheel.set_meta("model_path", STEERING_WHEEL_MODEL)


func _node_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var found := false
	var stack: Array = [{"node": root, "xform": Transform3D.IDENTITY}]
	while not stack.is_empty():
		var entry: Dictionary = stack.pop_back()
		var node: Node = entry["node"]
		var xform: Transform3D = entry["xform"]
		if node is Node3D:
			xform = xform * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var child_box: AABB = xform * (node as MeshInstance3D).mesh.get_aabb()
			result = child_box if not found else result.merge(child_box)
			found = true
		for child in node.get_children():
			stack.append({"node": child, "xform": xform})
	return result


static func horn_stream() -> AudioStream:
	if _horn_stream != null:
		return _horn_stream
	_horn_stream = _load_audio(HORN_SOUND, false)
	return _horn_stream


static func engine_stream() -> AudioStream:
	if _engine_stream != null:
		return _engine_stream
	_engine_stream = _load_audio(ENGINE_SOUND, true)
	return _engine_stream


static func _load_audio(path: String, loop: bool) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var source := load(path)
	if not (source is AudioStream):
		return null
	var stream: AudioStream = (source as AudioStream).duplicate()
	if loop and stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream


# throttle [-1,1] (negativo = marcha atras), steer [-1,1] (+ = derecha), brake [0,1].
func set_drive_input(throttle: float, steer: float, brake: float) -> void:
	_throttle = clampf(throttle, -1.0, 1.0) if is_finite(throttle) else 0.0
	_steer_input = clampf(steer, -1.0, 1.0) if is_finite(steer) else 0.0
	_brake_input = clampf(brake, 0.0, 1.0) if is_finite(brake) else 0.0


func speed() -> float:
	return linear_velocity.length()


func forward_speed() -> float:
	return linear_velocity.dot(global_transform.basis.z)


func is_dead() -> bool:
	return _dead


func _physics_process(delta: float) -> void:
	var top: float = float(def.get("max_speed", 30.0))
	var limit: float = clampf(1.0 - forward_speed() / top, 0.0, 1.0) if _throttle > 0.0 else 1.0
	if _throttle < 0.0:
		limit = clampf(1.0 - absf(forward_speed()) / (top * 0.3), 0.0, 1.0) if forward_speed() < 0.0 else 1.0
	engine_force = 0.0 if _dead or driver == null else _throttle * float(def.get("engine_force", 2000.0)) * limit
	brake = _brake_input * float(def.get("brake", 50.0)) if driver != null else 4.0
	var fast: float = clampf(absf(forward_speed()) / top, 0.0, 1.0)
	var target: float = -_steer_input * MAX_STEER * lerpf(1.0, 0.3, fast)
	steering = move_toward(steering, target, STEER_RATE * delta)
	_set_wheel_angle(steering)
	var braking: bool = _brake_input > 0.05 or (_throttle < 0.0 and forward_speed() > 0.5)
	_tail_material.emission_energy_multiplier = 3.0 if braking else (1.0 if headlights_on else 0.2)
	_update_engine_audio(top)
	if driver != null and is_instance_valid(driver):
		_follow_driver(delta)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	for i in state.get_contact_count():
		var collider := state.get_contact_collider_object(i)
		if collider == null:
			continue
		var delta_v: float = state.get_contact_impulse(i).length() / maxf(mass, 1.0)
		if delta_v > 0.01:
			register_impact(delta_v, state.get_contact_local_position(i), state.get_contact_local_normal(i), collider)


func _set_wheel_angle(angle: float) -> void:
	if steering_wheel != null:
		steering_wheel.transform.basis = Basis(Vector3.RIGHT, deg_to_rad(-65.0)) * Basis(Vector3.UP, angle * 4.0)


func engine_rpm(top: float = 0.0) -> float:
	var limit: float = maxf(maxf(top, float(def.get("max_speed", 30.0))), 1.0)
	return clampf(absf(forward_speed()) / limit, 0.0, 1.0)


func engine_pitch(top: float = 0.0) -> float:
	var rpm: float = engine_rpm(top)
	return 0.72 + rpm * 0.92 + absf(_throttle) * 0.14


func _update_engine_audio(top: float) -> void:
	if engine_player == null:
		return
	engine_player.pitch_scale = engine_pitch(top)
	var running: bool = driver != null and is_instance_valid(driver) and not _dead
	engine_player.volume_db = (-26.0 + engine_rpm(top) * 11.0 + absf(_throttle) * 3.0) if running else -60.0
	if running and not engine_player.playing:
		engine_player.play()
	elif not running and engine_player.playing:
		engine_player.stop()


func _follow_driver(delta: float) -> void:
	var seat: Vector3 = to_global(Vector3(SEAT.x, SEAT.y, SEAT.z))
	if _enter_t < 1.0:
		_enter_t = minf(_enter_t + delta / ENTER_TIME, 1.0)
		seat = _enter_from.lerp(seat, smoothstep(0.0, 1.0, _enter_t))
	driver.global_position = seat - Vector3(0.0, 1.0 if driver.has_method("is_dead") else 0.0, 0.0)


func enter(new_driver: Node3D) -> bool:
	if new_driver == null or driver != null or _dead:
		return false
	driver = new_driver
	_enter_from = new_driver.global_position
	_enter_t = 0.0
	if new_driver is CollisionObject3D:
		add_collision_exception_with(new_driver)
		(new_driver as CollisionObject3D).add_collision_exception_with(self)
	entered.emit(new_driver)
	return true


func exit() -> Node3D:
	if driver == null:
		return null
	var leaving := driver
	driver = null
	if is_instance_valid(leaving):
		if leaving is CollisionObject3D:
			remove_collision_exception_with(leaving)
			(leaving as CollisionObject3D).remove_collision_exception_with(self)
		leaving.global_position = to_global(Vector3(body_size.x * 0.5 + 0.8, 0.8, SEAT.z))
	_throttle = 0.0
	_steer_input = 0.0
	exited.emit(leaving)
	return leaving


func door_position() -> Vector3:
	return to_global(Vector3(body_size.x * 0.5, SEAT.y + 0.3, SEAT.z))


func toggle_headlights() -> bool:
	headlights_on = not headlights_on
	for spot in headlights:
		spot.visible = headlights_on
	return headlights_on


func honk() -> void:
	if horn_player != null and not horn_player.playing:
		horn_player.play()
	horn_sounded.emit()


func toggle_rear_door() -> bool:
	if rear_door == null:
		return false
	var opened: bool = absf(rear_door.rotation.x) > 0.1
	var tween := create_tween()
	tween.tween_property(rear_door, "rotation:x", 0.0 if opened else -1.2, 0.4)
	return not opened


func take_damage(amount: float, _point: Vector3 = Vector3.ZERO, _normal: Vector3 = Vector3.UP, _source: Node = null) -> void:
	if _dead or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	damaged.emit(amount, health)
	if health <= 0.0:
		_dead = true
		engine_force = 0.0
		destroyed.emit()


# Choque o atropello: delta_v en m/s del impacto; collider = lo que se golpeo.
func register_impact(delta_v: float, point: Vector3, normal: Vector3, collider: Object) -> Dictionary:
	var result := {"crash_damage": 0.0, "run_over": false, "target_damage": 0.0}
	var target := _damageable_of(collider)
	var speed_now: float = maxf(delta_v, speed())
	if target != null and target != self and speed_now >= RUN_OVER_MIN_SPEED:
		var hurt: float = speed_now * 7.0
		target.call("take_damage", hurt, point, normal, self)
		if target.has_method("is_dead") and bool(target.call("is_dead")):
			GoreFxScript.on_death(self, point, 0.8)
		else:
			GoreFxScript.blood_hit(self, point, normal, hurt, global_transform.basis.z, hurt > 45.0)
		result["run_over"] = true
		result["target_damage"] = hurt
		ran_over.emit(target, hurt)
	if delta_v > CRASH_THRESHOLD:
		var hurt_self: float = (delta_v - CRASH_THRESHOLD) * 9.0
		take_damage(hurt_self, point, normal, null)
		result["crash_damage"] = hurt_self
	return result


func _damageable_of(collider: Object) -> Node:
	var node := collider as Node
	var depth := 0
	while node != null and depth < 6:
		if node != self and node.has_method("take_damage") and not node.is_in_group("vehicles"):
			return node
		node = node.get_parent()
		depth += 1
	return null
