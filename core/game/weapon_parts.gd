class_name WeaponParts
extends RefCounted

const REQUIRED_ROLES := {
	"pistol": ["slide", "magazine", "hammer", "trigger"],
	"submachine_gun": ["bolt", "magazine", "charging_handle"],
	"assault_rifle": ["bolt", "magazine", "charging_handle"],
	"shotgun": ["pump", "bolt", "magazine"],
	"sniper_rifle": ["bolt", "magazine", "charging_handle"],
	"bat": ["body"],
}

const WEAPON_NOTES := {
	"pistol": "planos AABB: corredera superior, cargador del grip, martillo y gatillo",
	"submachine_gun": "planos AABB: cerrojo central, cargador bajo receptor, palanca de montaje",
	"assault_rifle": "planos AABB: cerrojo central, cargador curvo, palanca de montaje AK",
	"shotgun": "planos AABB: bombeo inferior delantero, cargador tubular, cerrojo",
	"sniper_rifle": "planos AABB: cerrojo superior, cargador bajo receptor, palanca",
	"bat": "isla unica: cuerpo rigido sin piezas moviles",
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

	var clean_islands: bool = island_total >= 2 and largest_island <= maxi(3, triangle_total / 2)
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
				var p0: Vector3 = rel.xform(verts[i0])
				var p1: Vector3 = rel.xform(verts[i1])
				var p2: Vector3 = rel.xform(verts[i2])
				var centroid: Vector3 = (p0 + p1 + p2) / 3.0
				var role := _role_for(centroid, bounds, id, clean_islands)
				var key: String = "%s|%d|%d" % [role, mi.get_instance_id(), surface]
				if not buckets.has(key):
					buckets[key] = {
						"role": role,
						"material": material,
						"vertices": PackedVector3Array(),
						"normals": PackedVector3Array(),
						"uvs": PackedVector2Array(),
						"colors": PackedColorArray(),
						"indices": PackedInt32Array(),
						"remap": {},
					}
				var bucket: Dictionary = buckets[key]
				var remap: Dictionary = bucket["remap"]
				for vi in [i0, i1, i2]:
					var local_index: int = vi
					if not remap.has(local_index):
						var world_vertex: Vector3 = rel.xform(verts[vi])
						remap[local_index] = (bucket["vertices"] as PackedVector3Array).size()
						(bucket["vertices"] as PackedVector3Array).append(world_vertex)
						var transformed_normal := Vector3.UP
						if normals != null and vi < (normals as PackedVector3Array).size():
							transformed_normal = (rel.basis.xform((normals as PackedVector3Array)[vi])).normalized()
						(bucket["normals"] as PackedVector3Array).append(transformed_normal)
						if uvs != null and vi < (uvs as PackedVector2Array).size():
							(bucket["uvs"] as PackedVector2Array).append((uvs as PackedVector2Array)[vi])
						else:
							(bucket["uvs"] as PackedVector2Array).append(Vector2.ZERO)
						if colors != null and vi < (colors as PackedColorArray).size():
							(bucket["colors"] as PackedColorArray).append((colors as PackedColorArray)[vi])
						else:
							(bucket["colors"] as PackedColorArray).append(Color.WHITE)
					(bucket["indices"] as PackedInt32Array).append(int(remap[local_index]))

	var role_vertices: Dictionary = {}
	for key in buckets:
		var bucket: Dictionary = buckets[key]
		var role: String = str(bucket["role"])
		if not role_vertices.has(role):
			role_vertices[role] = PackedVector3Array()
		for v in (bucket["vertices"] as PackedVector3Array):
			(role_vertices[role] as PackedVector3Array).append(v)

	for role in role_vertices:
		var pivot_box := AABB()
		var first := true
		for v in (role_vertices[role] as PackedVector3Array):
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
			for v in (bucket["vertices"] as PackedVector3Array):
				local_vertices.append(v - pivot)
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = local_vertices
			arrays[Mesh.ARRAY_NORMAL] = bucket["normals"]
			arrays[Mesh.ARRAY_TEX_UV] = bucket["uvs"]
			arrays[Mesh.ARRAY_COLOR] = bucket["colors"]
			arrays[Mesh.ARRAY_INDEX] = bucket["indices"]
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
		_: return 0.50


static func _role_y(role: String) -> float:
	match role:
		"magazine": return 0.20
		"pump": return 0.28
		"bolt", "slide": return 0.72
		"charging_handle": return 0.82
		"hammer": return 0.66
		"trigger": return 0.34
		_: return 0.50


static func _role_sx(role: String) -> float:
	match role:
		"magazine": return 0.14
		"pump": return 0.16
		"bolt", "slide": return 0.18
		"charging_handle": return 0.05
		"hammer": return 0.05
		"trigger": return 0.04
		_: return 0.5


static func _role_sy(role: String) -> float:
	match role:
		"magazine": return 0.30
		"pump": return 0.22
		"bolt", "slide": return 0.16
		"charging_handle": return 0.06
		"hammer": return 0.10
		"trigger": return 0.12
		_: return 0.5


static func _role_sz(role: String) -> float:
	match role:
		"magazine": return 0.45
		"pump": return 0.85
		"bolt", "slide": return 0.75
		"charging_handle": return 0.15
		"hammer": return 0.15
		"trigger": return 0.12
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
