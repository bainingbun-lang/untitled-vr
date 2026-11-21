class_name VrSimHarness
extends RefCounted

const WorldScene = preload("res://scenes/world/game_world.tscn")
const SessionScript = preload("res://core/game/game_session.gd")
const VrGameModeScript = preload("res://core/vr/vr_game_mode.gd")
const ThemesScript = preload("res://core/maps/map_themes.gd")

const DT: float = 1.0 / 72.0
const EYE_HEIGHT: float = 1.7


# Proveedor de entrada falso: poses de rig-local (cabeza y manos), grip/gatillo analogicos, sticks y botones.
class FakeInput extends RefCounted:
	var rig = null
	var head: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, EYE_HEIGHT, 0.0))
	var poses: Dictionary = {
		"left": Transform3D(Basis.IDENTITY, Vector3(-0.25, 1.15, -0.30)),
		"right": Transform3D(Basis.IDENTITY, Vector3(0.25, 1.15, -0.30)),
	}
	var grips: Dictionary = {"left": 0.0, "right": 0.0}
	var triggers: Dictionary = {"left": 0.0, "right": 0.0}
	var sticks: Dictionary = {"left": Vector2.ZERO, "right": Vector2.ZERO}
	var buttons: Dictionary = {"a": false, "b": false, "x": false, "y": false, "menu": false}
	var haptics: Array = []

	func get_pose(hand: String) -> Transform3D:
		return rig.controller_for(hand).global_transform

	func is_grip_pressed(hand: String) -> bool:
		return float(grips.get(hand, 0.0)) > 0.5

	func is_trigger_pressed(hand: String) -> bool:
		return float(triggers.get(hand, 0.0)) > 0.5

	func get_stick(hand: String) -> Vector2:
		return sticks.get(hand, Vector2.ZERO)

	func is_menu_pressed(_hand: String = "left") -> bool:
		return bool(buttons["menu"])

	func is_reload_pressed(hand: String = "right") -> bool:
		return bool(buttons["a"]) if hand == "right" else bool(buttons["x"])

	func controller_for(hand: String):
		return rig.controller_for(hand)


var tree: SceneTree = null
var world: Node3D = null
var rig = null
var state = null
var ws = null
var input: FakeInput = null
var frames: int = 0


static func make_meta(themed: bool = true) -> Dictionary:
	if themed:
		return ThemesScript.generate(1001, {
			"theme": "urbano", "time_of_day": "dia", "theme_density": 0.55,
			"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 4,
		})
	return VrGameModeScript.default_map_meta(4242)


# Arma el mundo VR igual que el juego: GameWorld.setup -> VrGameMode.build/setup. Sin XRServer.
func start(p_tree: SceneTree, meta: Dictionary = {}) -> void:
	tree = p_tree
	SessionScript.platform_override = "vr"
	SessionScript.platform = "vr"
	SessionScript.vr_menu_confirmed = true
	VrGameModeScript.xr_available_override = func() -> bool: return true
	if meta.is_empty():
		meta = make_meta(true)
	world = WorldScene.instantiate()
	tree.root.add_child(world)
	await tree.process_frame
	world.setup(meta)
	await tree.process_frame
	await tree.physics_frame
	world.set_process(false)
	rig = world.actor
	state = world.vr_state
	ws = world.vr_result.get("weapon_system", null)
	input = FakeInput.new()
	input.rig = rig
	rig.set_input_provider(input)
	apply_poses()


func cleanup() -> void:
	if world != null and is_instance_valid(world):
		world.free()
	world = null
	VrGameModeScript.xr_available_override = Callable()
	SessionScript.platform_override = ""
	SessionScript.platform = ""
	SessionScript.vr_menu_confirmed = false


# Cabeza y manos estan en espacio del XROrigin; se aplican a los nodos reales del rig.
func apply_poses() -> void:
	if rig == null or not is_instance_valid(rig):
		return
	rig.xr_camera.transform = input.head
	rig.left_controller.transform = input.poses["left"]
	rig.right_controller.transform = input.poses["right"]


func step(count: int = 1, physics: bool = false) -> void:
	for i in count:
		apply_poses()
		state.tick(DT)
		frames += 1
		if physics and frames % 6 == 0:
			await tree.physics_frame
	apply_poses()


func head_world() -> Vector3:
	return rig.xr_camera.global_position


func hand_world(hand: String) -> Vector3:
	return rig.controller_for(hand).global_position


func set_hand_world(hand: String, point: Vector3) -> void:
	input.poses[hand] = Transform3D(Basis.IDENTITY, rig.xr_origin.global_transform.affine_inverse() * point)
	apply_poses()


func set_head_yaw(yaw: float) -> void:
	input.head = Transform3D(Basis(Vector3.UP, yaw), input.head.origin)
	apply_poses()


func origin_pos() -> Vector3:
	return rig.xr_origin.global_position


# AABB global de todos los MeshInstance3D bajo node.
static func global_aabb(node: Node) -> AABB:
	var box := AABB()
	var first := true
	var nodes: Array = [node]
	nodes.append_array(node.find_children("*", "MeshInstance3D", true, false))
	for item in nodes:
		if not (item is MeshInstance3D) or (item as MeshInstance3D).mesh == null:
			continue
		var mesh_node := item as MeshInstance3D
		if not mesh_node.is_visible_in_tree():
			continue
		var part: AABB = mesh_node.global_transform * mesh_node.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


static func longest(box: AABB) -> float:
	return maxf(box.size.x, maxf(box.size.y, box.size.z))


# AABB global aplicando el skin (el AABB crudo de una malla skinneada no coincide con lo dibujado).
static func skinned_aabb(node: Node, skip_path_part: String = "") -> AABB:
	var points := PackedVector3Array()
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		if not skip_path_part.is_empty() and str(mi.get_path()).contains(skip_path_part):
			continue
		var skeleton: Skeleton3D = mi.get_node_or_null(mi.skeleton) as Skeleton3D if mi.skin != null else null
		if skeleton == null:
			var box: AABB = mi.mesh.get_aabb()
			for corner in 8:
				points.append(mi.global_transform * box.get_endpoint(corner))
			continue
		var arrays: Array = mi.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per: int = bones.size() / maxi(verts.size(), 1)
		var palette: Array = []
		for bind in mi.skin.get_bind_count():
			var bone: int = mi.skin.get_bind_bone(bind)
			if bone < 0:
				bone = skeleton.find_bone(mi.skin.get_bind_name(bind))
			palette.append(skeleton.global_transform * skeleton.get_bone_global_pose(maxi(bone, 0)) * mi.skin.get_bind_pose(bind))
		for index in range(0, verts.size(), 3):
			var point := Vector3.ZERO
			for k in per:
				var weight: float = weights[index * per + k]
				if weight > 0.0:
					point += (palette[bones[index * per + k]] * verts[index]) * weight
			points.append(point)
	var result := AABB()
	for i in points.size():
		result = AABB(points[i], Vector3.ZERO) if i == 0 else result.expand(points[i])
	return result


# AABB de un lote de modelos (MultiMesh) en espacio global, para la instancia indicada.
static func batch_aabb(batch: Node, instance: int = 0) -> AABB:
	var result := AABB()
	var first := true
	for child in batch.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := (child as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null or instance >= mm.instance_count:
			continue
		var box: AABB = (child as MultiMeshInstance3D).global_transform * mm.get_instance_transform(instance) * mm.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


# AABB en el marco local del nodo (sin la inflacion por su giro).
static func local_aabb(node: Node3D) -> AABB:
	var inverse := node.global_transform.affine_inverse()
	var result := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var box: AABB = inverse * mi.global_transform * mi.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
