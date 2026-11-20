extends SceneTree

const WeaponPartsScript = preload("res://core/game/weapon_parts.gd")

const IDS := ["pistol", "submachine_gun", "assault_rifle", "shotgun", "sniper_rifle", "bat"]

var _failures: Array = []
var _checks := 0
var _case := ""


func _initialize() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	await process_frame
	for id in IDS:
		_case = "particion " + id
		var path := "res://assets/models/weapons/%s.glb" % id
		var packed := load(path) as PackedScene
		_expect(packed != null, "GLB cargable para %s" % id)
		if packed == null:
			continue
		var model := packed.instantiate() as Node3D
		_expect(model != null, "modelo 3D para %s" % id)
		if model == null:
			continue
		model.name = "Model_" + id
		holder.add_child(model)
		var original_tris := _count_visible_tris(model)
		var result = WeaponPartsScript.build(model, id)
		_expect(result != null, "WeaponParts.build(%s)" % id)
		if result == null:
			model.free()
			continue
		print("WEAPON ", result.summary())
		_expect(not result.method.is_empty(), "metodo documentado para %s" % id)
		_expect(result.roles.size() >= (1 if id == "bat" else 3), "varias piezas para %s" % id)
		_expect(result.stats.get("islands", 0) > 0, "islas analizadas para %s" % id)
		_expect(int(result.stats.get("triangles", 0)) == original_tris, "triangulos conservados en %s" % id)
		_expect(result.rear_axis.length() > 0.5, "eje de retroceso definido para %s" % id)

		for role in WeaponPartsScript.REQUIRED_ROLES.get(id, []):
			_expect(result.has_role(role), "rol %s presente en %s" % [role, id])
			var pivot := result.node(role)
			_expect(pivot != null and pivot.get_parent() == model, "pivote de %s/%s colgado del modelo" % [id, role])
			_expect(pivot != null and pivot.name == "Part_" + role, "nombre de pivote %s/%s" % [id, role])
			var visual := _first_mesh(pivot)
			_expect(visual != null and visual.mesh != null, "malla real en %s/%s" % [id, role])
			if visual != null and visual.mesh != null:
				var center: Vector3 = visual.mesh.get_aabb().get_center()
				var size: Vector3 = visual.mesh.get_aabb().size
				var tolerance: float = maxf(0.002, maxf(size.x, maxf(size.y, size.z)) * 0.55)
				_expect(center.length() <= tolerance, "pivote centrado en %s/%s (%.4f)" % [id, role, center.length()])
				_expect(_has_material(visual), "material conservado en %s/%s" % [id, role])

		var part_tris := _count_visible_tris(model)
		_expect(part_tris <= original_tris + 24, "presupuesto de triangulos en %s (%d/%d)" % [id, part_tris, original_tris])
		_expect(_original_meshes_hidden(model), "malla rigida original oculta en %s" % id)

		if id == "pistol":
			var slide := result.node("slide")
			var magazine := result.node("magazine")
			_expect(slide.position.y > magazine.position.y, "corredera sobre el cargador en pistola")
			_expect(slide.position.x > magazine.position.x, "corredera por delante del cargador en pistola")
		if id == "shotgun":
			var pump := result.node("pump")
			var magazine := result.node("magazine")
			_expect(pump.position.x > magazine.position.x, "bombeo por delante del cargador en escopeta")

		model.free()

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _first_mesh(child)
		if found != null:
			return found
	return null


func _has_material(mi: MeshInstance3D) -> bool:
	if mi.material_override != null:
		return true
	for surface in range(mi.mesh.get_surface_count()):
		if mi.mesh.surface_get_material(surface) != null:
			return true
	return false


func _count_visible_tris(root: Node3D) -> int:
	var total := 0
	for item in root.find_children("*", "MeshInstance3D", true, false):
		var mi := item as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		for surface in range(mi.mesh.get_surface_count()):
			var arrays: Array = mi.mesh.surface_get_arrays(surface)
			var indices = arrays[Mesh.ARRAY_INDEX]
			if indices != null and (indices as PackedInt32Array).size() > 0:
				total += (indices as PackedInt32Array).size() / 3
			else:
				var vertices = arrays[Mesh.ARRAY_VERTEX]
				if vertices != null:
					total += (vertices as PackedVector3Array).size() / 3
	return total


func _original_meshes_hidden(root: Node3D) -> bool:
	for item in root.find_children("*", "MeshInstance3D", true, false):
		var mi := item as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		if mi.name.begins_with("Mesh_"):
			continue
		if mi.visible:
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])
