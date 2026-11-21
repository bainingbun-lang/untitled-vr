class_name MeshSlicer
extends Node

static var _root: Window = null


static func _get_root() -> Window:
	if _root == null:
		_root = Engine.get_main_loop().root
	return _root


static func slice_mesh(slice_transform: Transform3D, mesh: Mesh, cross_section_material: Material = null) -> Array:
	var combiner = CSGCombiner3D.new()

	var obj_csg: CSGMesh3D = CSGMesh3D.new()
	obj_csg.mesh = mesh

	var slicer_csg: CSGMesh3D = CSGMesh3D.new()
	slicer_csg.mesh = BoxMesh.new()
	slicer_csg.mesh.material = cross_section_material

	_get_root().add_child(combiner)
	combiner.add_child(obj_csg)
	combiner.add_child(slicer_csg)
	slicer_csg.transform = slice_transform

	var max_at = Vector3(-INF, -INF, -INF)
	var min_at = Vector3(INF, INF, INF)
	for v in mesh.get_faces():
		var lv = slicer_csg.to_local(v)
		max_at = max_at.max(lv)
		min_at = min_at.min(lv)

	max_at += Vector3(.1, .1, .1)
	min_at -= Vector3(.1, .1, .1)

	min_at.z = 0
	slicer_csg.position = slicer_csg.to_global((max_at + min_at) / 2.0)
	slicer_csg.mesh.size = (max_at - min_at)

	var out_mesh: Mesh
	var out_mesh2: Mesh

	slicer_csg.operation = CSGShape3D.OPERATION_SUBTRACTION
	combiner._update_shape()
	var meshes = combiner.get_meshes()
	if meshes:
		out_mesh = meshes[1]

	slicer_csg.operation = CSGShape3D.OPERATION_INTERSECTION
	combiner._update_shape()
	meshes = combiner.get_meshes()
	if meshes:
		out_mesh2 = meshes[1]

	combiner.queue_free()

	return [out_mesh, out_mesh2]


static func slice_skeletal_mesh_at_bone(
	skeleton: Skeleton3D,
	bone_idx: int,
	visual_root: Node3D,
	cross_section_material: Material = null
) -> Dictionary:
	"""
	Slice all meshes influenced by the given bone at the bone's position.
	Returns a dictionary with:
	- "detached_meshes": Array of MeshInstance3D for the detached limb portion
	- "stump_meshes": Array of MeshInstance3D for the remaining body with cut surface
	- "cut_transform": Transform3D of the cut plane in global space
	"""
	if skeleton == null or bone_idx < 0 or bone_idx >= skeleton.get_bone_count():
		return {"detached_meshes": [], "stump_meshes": [], "cut_transform": Transform3D.IDENTITY}

	var bone_name = String(skeleton.get_bone_name(bone_idx))
	var bone_global_pose = skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx)
	var cut_plane_origin = bone_global_pose.origin
	var cut_plane_normal = -bone_global_pose.basis.z.normalized()

	var cut_transform = Transform3D(Basis.looking_at(cut_plane_normal, Vector3.UP), cut_plane_origin)

	var all_meshes: Array[MeshInstance3D] = []
	_collect_skinned_meshes(visual_root, all_meshes)

	var influenced_meshes: Array[MeshInstance3D] = []
	for mesh_inst in all_meshes:
		if _mesh_influenced_by_bone(mesh_inst, skeleton, bone_idx):
			influenced_meshes.append(mesh_inst)

	if influenced_meshes.is_empty():
		return {"detached_meshes": [], "stump_meshes": [], "cut_transform": cut_transform}

	var detached_meshes: Array[MeshInstance3D] = []
	var stump_meshes: Array[MeshInstance3D] = []

	for mesh_inst in influenced_meshes:
		var mesh_res: Mesh = mesh_inst.mesh
		if mesh_res == null:
			continue

		var mesh_global_xform = mesh_inst.global_transform
		var slice_transform_local = mesh_global_xform.affine_inverse() * cut_transform

		var result = slice_mesh(slice_transform_local, mesh_res, cross_section_material)
		if result.size() >= 2:
			var mesh_a = result[0]
			var mesh_b = result[1]

			if mesh_a != null and mesh_b != null:
				var detached_inst = MeshInstance3D.new()
				detached_inst.mesh = mesh_a
				detached_inst.global_transform = mesh_global_xform
				var src_surface_count = mesh_res.get_surface_count()
				for i in range(mesh_a.get_surface_count()):
					if i < src_surface_count:
						var mat = mesh_res.surface_get_material(i)
						if mat != null:
							detached_inst.set_surface_override_material(i, mat)
					elif cross_section_material != null and i == mesh_a.get_surface_count() - 1:
						detached_inst.set_surface_override_material(i, cross_section_material)
				detached_meshes.append(detached_inst)

				var stump_inst = MeshInstance3D.new()
				stump_inst.mesh = mesh_b
				stump_inst.global_transform = mesh_global_xform
				for i in range(mesh_b.get_surface_count()):
					if i < src_surface_count:
						var mat = mesh_res.surface_get_material(i)
						if mat != null:
							stump_inst.set_surface_override_material(i, mat)
					elif cross_section_material != null and i == mesh_b.get_surface_count() - 1:
						stump_inst.set_surface_override_material(i, cross_section_material)
				stump_meshes.append(stump_inst)

	return {
		"detached_meshes": detached_meshes,
		"stump_meshes": stump_meshes,
		"cut_transform": cut_transform
	}


static func _collect_skinned_meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		var mesh = (node as MeshInstance3D).mesh
		if mesh != null and mesh.get_surface_count() > 0:
			var arrays = mesh.surface_get_arrays(0)
			if arrays.size() >= Mesh.ARRAY_WEIGHTS and arrays[Mesh.ARRAY_WEIGHTS].size() > 0:
				out.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_skinned_meshes(child, out)


static func _mesh_influenced_by_bone(mesh_inst: MeshInstance3D, skeleton: Skeleton3D, bone_idx: int) -> bool:
	var mesh = mesh_inst.mesh
	if mesh == null:
		return false

	for surface_idx in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(surface_idx)
		if arrays.size() < Mesh.ARRAY_WEIGHTS:
			continue
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays.size() > Mesh.ARRAY_BONES else PackedInt32Array()

		if weights.size() == 0:
			continue

		var vertices_per_weight = 4
		var weight_count = weights.size() / vertices_per_weight

		for i in range(weight_count):
			var bone_id_0 = bones[i * 4 + 0] if bones.size() > i * 4 + 0 else 0
			var bone_id_1 = bones[i * 4 + 1] if bones.size() > i * 4 + 1 else 0
			var bone_id_2 = bones[i * 4 + 2] if bones.size() > i * 4 + 2 else 0
			var bone_id_3 = bones[i * 4 + 3] if bones.size() > i * 4 + 3 else 0

			var w0 = weights[i * 4 + 0]
			var w1 = weights[i * 4 + 1]
			var w2 = weights[i * 4 + 2]
			var w3 = weights[i * 4 + 3]

			if (bone_id_0 == bone_idx and w0 > 0.01) or \
			   (bone_id_1 == bone_idx and w1 > 0.01) or \
			   (bone_id_2 == bone_idx and w2 > 0.01) or \
			   (bone_id_3 == bone_idx and w3 > 0.01):
				return true

	return false