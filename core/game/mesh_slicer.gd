class_name MeshSlicer
extends Node

static var _root: Window = null


static func _get_root() -> Window:
	if _root == null:
		_root = Engine.get_main_loop().root
	return _root


static func slice_mesh(slice_transform: Transform3D, mesh: Mesh, cross_section_material: Material = null) -> Array[ArrayMesh]:
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