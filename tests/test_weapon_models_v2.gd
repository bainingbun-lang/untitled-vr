extends SceneTree

const WeaponPartsScript = preload("res://core/game/weapon_parts.gd")
const WeaponViewmodelScript = preload("res://core/game/weapon_viewmodel.gd")

const MANIFEST_PATH := "res://assets/models/weapons/v2/manifest.json"
const V2_DIR := "res://assets/models/weapons/v2/"
const IDS := ["pistol", "submachine_gun", "assault_rifle", "shotgun", "sniper_rifle", "bat"]
const NATIVE_IDS := ["pistol", "submachine_gun", "sniper_rifle", "bat"]

var _failures: Array = []
var _checks := 0
var _case := ""


func _initialize() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	await process_frame
	var manifest := _load_manifest()
	_case = "manifest"
	_expect(not manifest.is_empty(), "manifest.json cargado")
	var weapons: Dictionary = manifest.get("weapons", {})

	for id in IDS:
		_case = "v2 " + id
		_expect(weapons.has(id), "entrada en manifest para %s" % id)
		if not weapons.has(id):
			continue
		var entry: Dictionary = weapons[id] as Dictionary
		var path := str(entry.get("file", ""))
		_expect(path.begins_with(V2_DIR), "ruta v2 para %s" % id)
		_expect(ResourceLoader.exists(path), "recurso existe: %s" % path)
		if not ResourceLoader.exists(path):
			continue
		var packed := load(path) as PackedScene
		_expect(packed != null, "PackedScene cargable para %s" % id)
		if packed == null:
			continue
		var model := packed.instantiate() as Node3D
		_expect(model != null, "modelo 3D para %s" % id)
		if model == null:
			continue
		model.name = "Model_" + id
		holder.add_child(model)
		var size := _aabb(model).size
		var longest := maxf(size.x, maxf(size.y, size.z))
		var tris := _count_tris(model)
		var tex := _max_texture_size(model)
		_expect(tris == int(entry.get("triangles", -1)), "triangulos manifest/estructura en %s (%d/%d)" % [id, tris, int(entry.get("triangles", -1))])
		_expect(tris <= 8000, "presupuesto 8k tris en %s (%d)" % [id, tris])
		_expect(tex <= 1024, "texturas <=1024 en %s (%d)" % [id, tex])
		var scaled := longest * float(entry.get("scale", 0.0))
		var target := float(entry.get("length", 0.0))
		_expect(absf(scaled - target) <= 0.01, "escala realista en %s (%.3f/%.3f)" % [id, scaled, target])
		_expect(WeaponViewmodelScript.model_path_for(id) == path, "viewmodel apunta al v2 de %s" % id)

		for declared in entry.get("nodes", []):
			var node_name := str(declared)
			if node_name.begins_with("Skeleton3D:"):
				_expect(_has_bone(model, node_name.substr(11)), "hueso documentado %s/%s" % [id, node_name])
			else:
				_expect(not model.find_children(node_name, "", true, false).is_empty(), "nodo documentado %s/%s" % [id, node_name])

		var result = WeaponPartsScript.build(model, id)
		_expect(result != null, "WeaponParts.build(%s)" % id)
		if result != null:
			print("V2PARTS ", result.summary())
			_expect(not result.method.is_empty(), "metodo documentado para %s" % id)
			for role in WeaponPartsScript.REQUIRED_ROLES.get(id, []):
				_expect(result.has_role(str(role)), "rol %s presente en %s" % [role, id])
				var pivot := result.node(str(role))
				_expect(pivot != null and (pivot == model or model.is_ancestor_of(pivot)), "pivote %s/%s colgado del modelo" % [id, role])
				if pivot != null:
					pivot.position += Vector3(0.01, 0.0, 0.0)
					_expect(result.offset(str(role)).length() > 0.0, "offset medible en %s/%s" % [id, role])
					pivot.position -= Vector3(0.01, 0.0, 0.0)
			var mapping: Dictionary = entry.get("parts", {})
			if IDS.has(id) and NATIVE_IDS.has(id):
				_expect(result.method == "piezas nativas", "piezas nativas en %s" % id)
				_expect(int(result.stats.get("native_nodes", 0)) >= (1 if id == "bat" else 3), "nodos nativos reutilizados en %s" % id)
				for role in mapping.keys():
					var node_name := str(mapping[role])
					if node_name.is_empty():
						continue
					var part := result.node(str(role))
					_expect(part != null and part.name == node_name, "rol %s usa nodo real %s" % [role, node_name])
			else:
				_expect(result.method != "piezas nativas", "corte AABB en malla skinneada %s" % id)
				_expect(result.stats.get("islands", 0) > 0, "islas analizadas en %s" % id)
		model.free()

	_case = "brazos FPS"
	for key in ["fps_arms", "fps_arms_animated"]:
		_expect(manifest.has(key), "entrada %s en manifest" % key)
		if not manifest.has(key):
			continue
		var entry: Dictionary = manifest[key] as Dictionary
		var path := str(entry.get("file", ""))
		_expect(ResourceLoader.exists(path), "recurso existe: %s" % path)
		if not ResourceLoader.exists(path):
			continue
		var model := (load(path) as PackedScene).instantiate() as Node3D
		holder.add_child(model)
		var bones := _bone_names(model)
		_expect(bones.size() >= int(entry.get("bones", 99)) - 5, "huesos de %s (%d)" % [key, bones.size()])
		_expect(_count_tris(model) == int(entry.get("triangles", -1)), "triangulos de %s" % key)
		_expect(_max_texture_size(model) <= 1024, "texturas de %s <=1024" % key)
		if entry.has("animations"):
			var clips := _anim_names(model)
			for clip in entry.get("animations", []):
				_expect(clips.has(str(clip)), "clip %s en %s" % [clip, key])
		model.free()

	_case = "manos VR"
	var hands: Dictionary = manifest.get("vr_hands", {})
	for side in ["left", "right"]:
		var path := str(hands.get(side, ""))
		_expect(ResourceLoader.exists(path), "mano %s existe" % side)
		if not ResourceLoader.exists(path):
			continue
		var model := (load(path) as PackedScene).instantiate() as Node3D
		holder.add_child(model)
		_expect(_bone_names(model).size() >= 20, "esqueleto de mano %s" % side)
		_expect(_count_tris(model) <= 8000, "tris de mano %s" % side)
		_expect(_max_texture_size(model) <= 1024, "texturas de mano %s" % side)
		model.free()

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _aabb(root: Node3D) -> AABB:
	var result := AABB()
	var found := false
	var inv := root.global_transform.affine_inverse()
	for item in root.find_children("*", "MeshInstance3D", true, false):
		var mi := item as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var box: AABB = (inv * mi.global_transform) * mi.mesh.get_aabb()
		if found:
			result = result.merge(box)
		else:
			result = box
			found = true
	return result


func _count_tris(root: Node3D) -> int:
	var total := 0
	for item in root.find_children("*", "MeshInstance3D", true, false):
		var mi := item as MeshInstance3D
		if mi == null or mi.mesh == null:
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


func _max_texture_size(root: Node3D) -> int:
	var largest := 0
	const PROPS := [
		"albedo_texture", "normal_texture", "roughness_texture", "metallic_texture",
		"emission_texture", "ao_texture", "height_texture", "detail_texture",
	]
	for item in root.find_children("*", "MeshInstance3D", true, false):
		var mi := item as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var candidates: Array = [mi.material_override]
		for surface in range(mi.mesh.get_surface_count()):
			candidates.append(mi.mesh.surface_get_material(surface))
		for candidate in candidates:
			if not (candidate is StandardMaterial3D):
				continue
			for prop in PROPS:
				var texture := candidate.get(prop) as Texture2D
				if texture != null:
					var s := texture.get_size()
					largest = maxi(largest, maxi(s.x, s.y))
	return largest


func _bone_names(root: Node3D) -> Array:
	var names: Array = []
	for item in root.find_children("*", "Skeleton3D", true, false):
		var skeleton := item as Skeleton3D
		for i in range(skeleton.get_bone_count()):
			names.append(skeleton.get_bone_name(i))
	return names


func _has_bone(root: Node3D, name: String) -> bool:
	return _bone_names(root).has(name)


func _anim_names(root: Node3D) -> Array:
	var names: Array = []
	for item in root.find_children("*", "AnimationPlayer", true, false):
		for clip in (item as AnimationPlayer).get_animation_list():
			names.append(str(clip))
	return names


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])
