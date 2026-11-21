class_name WeaponParts
extends RefCounted

const REQUIRED_ROLES := {
	"pistol": ["slide", "magazine", "hammer", "trigger", "ammo_counter"],
	"submachine_gun": ["bolt", "magazine", "charging_handle", "ammo_counter"],
	"assault_rifle": ["bolt", "magazine", "charging_handle", "ammo_counter"],
	"shotgun": ["pump", "bolt", "magazine", "ammo_counter"],
	"sniper_rifle": ["bolt", "magazine", "charging_handle", "ammo_counter"],
	"bat": ["body"],
}

const MANIFEST_PATH := "res://assets/models/weapons/v2/manifest.json"

static var _manifest_cache: Dictionary = {}

const WEAPON_NOTES := {
	"pistol": "piezas nativas: corredera, cargador y gatillo del GLB; martillo sin malla propia",
	"submachine_gun": "piezas nativas: cerrojo, cargador, palanca de montaje y gatillo",
	"assault_rifle": "malla skinneada: piezas por corte AABB de los huesos Magazine/Bolt",
	"shotgun": "malla skinneada: piezas por corte AABB de los huesos Pump/Shell",
	"sniper_rifle": "piezas nativas: cerrojo, cargador y palanca del GLB",
	"bat": "pieza nativa: unica malla rigida del GLB",
}

const ROLE_NAMES := {
	"body": "cuerpo",
	"slide": "corredera",
	"bolt": "cerrojo",
	"magazine": "cargador",
	"pump": "bombeo",
	"charging_handle": "palanca de montaje",
	"hammer": "martillo",
	"trigger": "gatillo",
	"ammo_counter": "contador_municion",
}


class Result extends RefCounted:
	var id: String = ""
	var method: String = ""
	var roles: Dictionary = {}
	var homes: Dictionary = {}
	var stats: Dictionary = {}
	var rear_axis: Vector3 = Vector3.LEFT
	var procedural_roles: Array = []

	func has_role(role: String) -> bool:
		return roles.has(role) and roles[role] != null

	func node(role: String) -> Node3D:
		if not roles.has(role):
			return null
		return roles[role] as Node3D

	func role_names() -> Array:
		return roles.keys()

	func offset(role: String) -> Vector3:
		var pivot := node(role)
		if pivot == null or not homes.has(role):
			return Vector3.ZERO
		return pivot.position - (homes[role] as Vector3)

	func summary() -> String:
		var names: Array = []
		for role in roles:
			names.append("%s=%s" % [role, ROLE_NAMES.get(role, role)])
		return "%s [%s] piezas=%d metodo=%s triangulos=%d islas=%d procedural=%s" % [
			id, ", ".join(names), roles.size(), method,
			int(stats.get("triangles", 0)), int(stats.get("islands", 0)),
			str(procedural_roles),
		]


static func build(root: Node3D, id: String) -> Result:
	var result := Result.new()
	result.id = id
	result.rear_axis = Vector3.LEFT
	if root == null:
		result.method = "sin modelo"
		return result

	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	var root_inv := root.global_transform.affine_inverse()
	var transforms: Dictionary = {}
	var bounds := AABB()
	var has_bounds := false
	var triangle_total := 0
	var island_total := 0
	var largest_island := 0
	for item in meshes:
		var mi := item as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var rel: Transform3D = root_inv * mi.global_transform
		transforms[mi.get_instance_id()] = rel
		var box: AABB = rel * mi.mesh.get_aabb()
		if has_bounds:
			bounds = bounds.merge(box)
		else:
			bounds = box
			has_bounds = true
		var info: Dictionary = _surface_islands(mi)
		island_total += int(info.get("islands", 0))
		largest_island = maxi(largest_island, int(info.get("largest", 0)))
		for surface in range(mi.mesh.get_surface_count()):
			triangle_total += _triangle_count(mi.mesh, surface)

	if not has_bounds or bounds.size.length() < 0.000001:
		result.method = "sin geometria"
		result.stats = {"triangles": 0, "islands": 0, "parts": 0}
		return result

	result.stats = {
		"triangles": triangle_total,
		"islands": island_total,
		"largest_island": largest_island,
	}

	if _build_native(root, id, result):
		result.stats["parts"] = result.roles.size()
		return result

	var clean_islands: bool = island_total >= 2 and largest_island <= maxi(3, triangle_total / 2) and id != "shotgun"
	if id == "bat" or (clean_islands and island_total <= 16):
		result.method = "islas conexas"
	else:
		result.method = "planos AABB"

	var buckets: Dictionary = {}
	for item in meshes:
		var mi := item as MeshInstance3D
		if mi == null or mi.mesh == null or not transforms.has(mi.get_instance_id()):
			continue
		var rel: Transform3D = transforms[mi.get_instance_id()]
		for surface in range(mi.mesh.get_surface_count()):
			var arrays: Array = mi.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if verts.is_empty():
				continue
			var material: Material = mi.material_override
			if material == null:
				material = mi.mesh.surface_get_material(surface)
			var normals = arrays[Mesh.ARRAY_NORMAL]
			var uvs = arrays[Mesh.ARRAY_TEX_UV]
			var colors = arrays[Mesh.ARRAY_COLOR]
			var tri_count: int = indices.size() / 3 if indices.size() > 0 else verts.size() / 3
			for tri in range(tri_count):
				var i0: int = indices[tri * 3] if indices.size() > 0 else tri * 3
				var i1: int = indices[tri * 3 + 1] if indices.size() > 0 else tri * 3 + 1
				var i2: int = indices[tri * 3 + 2] if indices.size() > 0 else tri * 3 + 2
				var p0: Vector3 = rel * verts[i0]
				var p1: Vector3 = rel * verts[i1]
				var p2: Vector3 = rel * verts[i2]
				var centroid: Vector3 = (p0 + p1 + p2) / 3.0
				var role := _role_for(centroid, bounds, id, clean_islands)
				var key: String = "%s|%d|%d" % [role, mi.get_instance_id(), surface]
				if not buckets.has(key):
					buckets[key] = {
						"role": role,
						"material": material,
						"vertices": [],
						"normals": [],
						"uvs": [],
						"colors": [],
						"indices": [],
						"remap": {},
					}
				var bucket: Dictionary = buckets[key]
				var vout: Array = bucket["vertices"]
				var nout: Array = bucket["normals"]
				var uout: Array = bucket["uvs"]
				var cout: Array = bucket["colors"]
				var iout: Array = bucket["indices"]
				var remap: Dictionary = bucket["remap"]
				for vi in [i0, i1, i2]:
					var local_index: int = vi
					if not remap.has(local_index):
						remap[local_index] = vout.size()
						vout.append(rel * verts[vi])
						var transformed_normal := Vector3.UP
						if normals != null and vi < (normals as PackedVector3Array).size():
							transformed_normal = (rel.basis * (normals as PackedVector3Array)[vi]).normalized()
						nout.append(transformed_normal)
						if uvs != null and vi < (uvs as PackedVector2Array).size():
							uout.append((uvs as PackedVector2Array)[vi])
						else:
							uout.append(Vector2.ZERO)
						if colors != null and vi < (colors as PackedColorArray).size():
							cout.append((colors as PackedColorArray)[vi])
						else:
							cout.append(Color.WHITE)
					iout.append(int(remap[local_index]))
				bucket["vertices"] = vout
				bucket["normals"] = nout
				bucket["uvs"] = uout
				bucket["colors"] = cout
				bucket["indices"] = iout
				bucket["remap"] = remap
				buckets[key] = bucket

	var role_vertices: Dictionary = {}
	for key in buckets:
		var bucket: Dictionary = buckets[key]
		var role: String = str(bucket["role"])
		if not role_vertices.has(role):
			role_vertices[role] = []
		var collected: Array = role_vertices[role]
		for v in (bucket["vertices"] as Array):
			collected.append(v)
		role_vertices[role] = collected

	for role in role_vertices:
		var pivot_box := AABB()
		var first := true
		for v in (role_vertices[role] as Array):
			if first:
				pivot_box = AABB(v, Vector3.ZERO)
				first = false
			else:
				pivot_box = pivot_box.expand(v)
		var pivot: Vector3 = pivot_box.get_center()
		var holder := Node3D.new()
		holder.name = "Part_" + str(role)
		holder.position = pivot
		root.add_child(holder)
		var combined := ArrayMesh.new()
		var surface_index := 0
		for key in buckets:
			var bucket: Dictionary = buckets[key]
			if str(bucket["role"]) != str(role):
				continue
			var local_vertices := PackedVector3Array()
			for v in (bucket["vertices"] as Array):
				local_vertices.append(v - pivot)
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = local_vertices
			arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(bucket["normals"])
			arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(bucket["uvs"])
			arrays[Mesh.ARRAY_COLOR] = PackedColorArray(bucket["colors"])
			arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(bucket["indices"])
			combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var material: Material = bucket["material"]
			if material != null:
				combined.surface_set_material(surface_index, material)
			surface_index += 1
		var visual := MeshInstance3D.new()
		visual.name = "Mesh_" + str(role)
		visual.mesh = combined
		holder.add_child(visual)
		result.roles[role] = holder
		result.homes[role] = pivot

	for item in meshes:
		var mi := item as MeshInstance3D
		if mi != null and mi.mesh != null:
			mi.visible = false

	var required: Array = REQUIRED_ROLES.get(id, [])
	for role in required:
		if result.has_role(str(role)):
			continue
		var procedural := _make_procedural_part(root, str(role), bounds, result)
		if procedural != null:
			result.procedural_roles.append(str(role))
			result.roles[str(role)] = procedural[0]
			result.homes[str(role)] = procedural[1]

	result.stats["parts"] = result.roles.size()
	return result


static func _manifest() -> Dictionary:
	if not _manifest_cache.is_empty():
		return _manifest_cache
	if not FileAccess.file_exists(MANIFEST_PATH):
		return _manifest_cache
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return _manifest_cache
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_manifest_cache = parsed as Dictionary
	return _manifest_cache


static func _build_native(root: Node3D, id: String, result: Result) -> bool:
	var weapons: Dictionary = _manifest().get("weapons", {})
	if weapons.is_empty() or not weapons.has(id):
		return false
	var mapping: Dictionary = (weapons[id] as Dictionary).get("parts", {})
	if mapping.is_empty():
		return false
	var required: Array = REQUIRED_ROLES.get(id, [])
	var roles: Array = []
	for role in mapping.keys():
		if not roles.has(str(role)):
			roles.append(str(role))
	for role in required:
		if not roles.has(str(role)):
			roles.append(str(role))
	var used: Dictionary = {}
	var found: Dictionary = {}
	for role_variant in roles:
		var role := str(role_variant)
		var node_name := str(mapping.get(role, ""))
		if node_name.is_empty():
			continue
		for candidate in root.find_children(node_name, "Node3D", true, false):
			var n := candidate as Node3D
			if n != null and not used.has(n.get_instance_id()):
				used[n.get_instance_id()] = true
				found[role] = n
				break
	if found.is_empty():
		return false
	var empty_roles: Array = []
	for role_variant in roles:
		var role := str(role_variant)
		var pivot: Node3D = found.get(role, null) as Node3D
		if pivot == null:
			pivot = Node3D.new()
			pivot.name = "Part_" + role
			pivot.position = Vector3.ZERO
			root.add_child(pivot)
			empty_roles.append(role)
		result.roles[role] = pivot
		result.homes[role] = pivot.position
	result.method = "piezas nativas"
	result.stats["native_nodes"] = found.size()
	result.stats["empty_roles"] = empty_roles
	return true


static func _role_for(point: Vector3, bounds: AABB, id: String, clean_islands: bool) -> String:
	var size: Vector3 = bounds.size
	var x: float = clampf((point.x - bounds.position.x) / maxf(size.x, 0.000001), 0.0, 1.0)
	var y: float = clampf((point.y - bounds.position.y) / maxf(size.y, 0.000001), 0.0, 1.0)
	var lateral: float = clampf(absf(point.z - (bounds.position.z + size.z * 0.5)) / maxf(size.z * 0.5, 0.000001), 0.0, 1.0)
	if lateral > 0.88 and y < 0.55:
		return "body"
	if id == "bat":
		return "body"
	if clean_islands:
		if y < 0.38 and x > 0.18 and x < 0.68:
			return "magazine"
		if y > 0.62 and x > 0.10:
			return "slide" if id == "pistol" else "bolt"
		return "body"
	if id == "pistol":
		if y < 0.38 and x < 0.40:
			return "magazine"
		if y > 0.60 and x > 0.10:
			return "slide"
		if x < 0.22 and y > 0.45:
			return "hammer"
		if x > 0.28 and x < 0.56 and y > 0.20 and y < 0.48:
			return "trigger"
		return "body"
	if id == "shotgun":
		if y < 0.42 and x > 0.16 and x < 0.52:
			return "magazine"
		if x > 0.52 and y < 0.72:
			return "pump"
		if x > 0.30 and x < 0.66 and y > 0.62:
			return "bolt"
		return "body"
if y < 0.42 and x > 0.18 and x < 0.68:
			return "magazine"
	if x > 0.40 and x < 0.58 and y > 0.72:
		return "charging_handle"
	if x > 0.26 and x < 0.74 and y > 0.55:
		return "bolt"
	if x < 0.22 and y > 0.50:
		return "hammer"
	if x > 0.30 and x < 0.58 and y > 0.18 and y < 0.46:
		return "trigger"
	if y > 0.55 and x > 0.10 and x < 0.35:
		return "ammo_counter"
	return "body"


static func _make_procedural_part(root: Node3D, role: String, bounds: AABB, result: Result) -> Array:
	var size: Vector3 = bounds.size
	var pivot: Vector3 = bounds.position + Vector3(
		size.x * _role_x(role),
		size.y * _role_y(role),
		0.0
	)
	var dimensions: Vector3 = Vector3(
		maxf(size.x * _role_sx(role), 0.0002),
		maxf(size.y * _role_sy(role), 0.0002),
		maxf(size.z * _role_sz(role), 0.0002)
	)
	var material: Material = _find_material(root)
	var holder := Node3D.new()
	holder.name = "Part_" + role
	holder.position = pivot
	root.add_child(holder)
	var visual := MeshInstance3D.new()
	visual.name = "Mesh_" + role
	var box := BoxMesh.new()
	box.size = dimensions
	visual.mesh = box
	if material != null:
		visual.material_override = material
	holder.add_child(visual)
	if result.stats.has("procedural_triangles"):
		result.stats["procedural_triangles"] = int(result.stats["procedural_triangles"]) + 12
	else:
		result.stats["procedural_triangles"] = 12
	return [holder, pivot]


static func _role_x(role: String) -> float:
	match role:
		"magazine": return 0.40
		"charging_handle": return 0.50
		"hammer": return 0.18
		"trigger": return 0.42
		"bolt": return 0.52
		"pump": return 0.70
		"ammo_counter": return 0.22
		_: return 0.50


static func _role_y(role: String) -> float:
	match role:
		"magazine": return 0.20
		"pump": return 0.28
		"bolt", "slide": return 0.72
		"charging_handle": return 0.82
		"hammer": return 0.66
		"trigger": return 0.34
		"ammo_counter": return 0.60
		_: return 0.50


static func _role_sx(role: String) -> float:
	match role:
		"magazine": return 0.14
		"pump": return 0.16
		"bolt", "slide": return 0.18
		"charging_handle": return 0.05
		"hammer": return 0.05
		"trigger": return 0.04
		"ammo_counter": return 0.10
		_: return 0.5


static func _role_sy(role: String) -> float:
	match role:
		"magazine": return 0.30
		"pump": return 0.22
		"bolt", "slide": return 0.16
		"charging_handle": return 0.06
		"hammer": return 0.10
		"trigger": return 0.12
		"ammo_counter": return 0.08
		_: return 0.5


static func _role_sz(role: String) -> float:
	match role:
		"magazine": return 0.45
		"pump": return 0.85
		"bolt", "slide": return 0.75
		"charging_handle": return 0.15
		"hammer": return 0.15
		"trigger": return 0.12
		"ammo_counter": return 0.05
		_: return 0.5


static func _find_material(root: Node3D) -> Material:
	for item in root.find_children("*", "MeshInstance3D", true, false):
		var mi := item as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		if mi.material_override != null:
			return mi.material_override
		for surface in range(mi.mesh.get_surface_count()):
			var material: Material = mi.mesh.surface_get_material(surface)
			if material != null:
				return material
	return null


static func _triangle_count(mesh: Mesh, surface: int) -> int:
	var arrays: Array = mesh.surface_get_arrays(surface)
	var indices = arrays[Mesh.ARRAY_INDEX]
	if indices != null and (indices as PackedInt32Array).size() > 0:
		return (indices as PackedInt32Array).size() / 3
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	return vertices.size() / 3 if vertices != null else 0


static func _surface_islands(mi: MeshInstance3D) -> Dictionary:
	var total_islands := 0
	var largest := 0
	for surface in range(mi.mesh.get_surface_count()):
		var arrays: Array = mi.mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if verts.is_empty():
			continue
		var tri_count: int = indices.size() / 3 if indices.size() > 0 else verts.size() / 3
		var parent := PackedInt32Array()
		parent.resize(verts.size())
		for i in range(verts.size()):
			parent[i] = i
		var welded := {}
		for i in range(verts.size()):
			var v: Vector3 = verts[i]
			var key := "%d,%d,%d" % [roundi(v.x * 100000.0), roundi(v.y * 100000.0), roundi(v.z * 100000.0)]
			if welded.has(key):
				_union(parent, i, int(welded[key]))
			else:
				welded[key] = i
		for tri in range(tri_count):
			var i0: int = indices[tri * 3] if indices.size() > 0 else tri * 3
			var i1: int = indices[tri * 3 + 1] if indices.size() > 0 else tri * 3 + 1
			var i2: int = indices[tri * 3 + 2] if indices.size() > 0 else tri * 3 + 2
			_union(parent, i0, i1)
			_union(parent, i0, i2)
		var sizes := {}
		for tri in range(tri_count):
			var i0: int = indices[tri * 3] if indices.size() > 0 else tri * 3
			var root_index: int = _find(parent, i0)
			sizes[root_index] = int(sizes.get(root_index, 0)) + 1
		total_islands += sizes.size()
		for key in sizes:
			largest = maxi(largest, int(sizes[key]))
	return {"islands": total_islands, "largest": largest}


static func _find(parent: PackedInt32Array, index: int) -> int:
	var current := index
	while parent[current] != current:
		parent[current] = parent[parent[current]]
		current = parent[current]
	return current


static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra: int = _find(parent, a)
	var rb: int = _find(parent, b)
	if ra != rb:
		parent[rb] = ra
