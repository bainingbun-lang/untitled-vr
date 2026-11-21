extends SceneTree

const CharacterModelScript = preload("res://core/game/character_model.gd")

var _failures: Array = []
var _checks := 0
var _case := ""
var _root: Node3D = null


func _initialize() -> void:
	_root = Node3D.new()
	root.add_child(_root)
	await process_frame

	_case = "manifiesto v2"
	var manifest: Dictionary = CharacterModelScript.v2_manifest()
	_expect(not manifest.is_empty(), "manifiesto cargado desde res://")
	var ids: Array = CharacterModelScript.v2_skin_ids()
	_expect(ids.size() >= 10, "al menos 10 modelos registrados: %d" % ids.size())
	_expect(CharacterModelScript.v2_roles().size() >= 6, "seis roles registrados")

	_case = "cobertura de roles y alias"
	for role in ["civil", "police", "soldier", "criminal", "office"]:
		_expect(not CharacterModelScript.v2_models(role).is_empty(), "rol con modelos: %s" % role)
	_expect(CharacterModelScript.v2_models("civil").size() >= 4, "cuatro o mas civiles")
	_expect(CharacterModelScript.v2_models("civilian").size() >= 4, "alias civilian")

	_case = "cada modelo: carga, altura, huesos, animaciones y presupuesto"
	var models: Dictionary = manifest.get("models", {})
	for id_value in ids:
		var id := str(id_value)
		var entry: Dictionary = models[id]
		var path := str(entry.get("file", ""))
		_expect(ResourceLoader.exists(path), "archivo cargable: %s" % id)
		var packed := load(path) as PackedScene
		_expect(packed != null, "PackedScene: %s" % id)
		if packed != null:
			var instance := packed.instantiate()
			_expect(instance is Node3D, "instancia Node3D: %s" % id)
			if instance is Node3D:
				var tris := _count_triangles(instance)
				_expect(tris > 0 and tris <= 15000, "presupuesto <=15k tris: %s (%d)" % [id, tris])
				instance.free()

		var role := str(entry.get("role", ""))
		var seed := _seed_for(role, id)
		_expect(seed >= 0, "semilla que selecciona %s" % id)
		if seed < 0:
			continue
		var model: CharacterModel = CharacterModelScript.spawn_v2(_root, role, seed)
		await process_frame
		_expect(model.is_loaded(), "modelo instanciado: %s" % id)
		_expect_eq(model.v2_model_id(), id, "id resuelto: %s" % id)
		_expect_eq(model.v2_role(), role, "rol resuelto: %s" % id)
		_expect(model.height() >= 1.6 and model.height() <= 1.9, "altura 1.6-1.9 m: %s (%.3f)" % [id, model.height()])
		_expect(model.skeleton != null and model.skeleton.get_bone_count() >= 10, "esqueleto real: %s" % id)
		_expect(model.animation_player != null, "AnimationPlayer: %s" % id)
		var bones: Dictionary = entry.get("key_bones", {})
		for bone_key in bones.keys():
			_expect(model.skeleton.find_bone(str(bones[bone_key])) >= 0, "hueso clave %s=%s en %s" % [bone_key, str(bones[bone_key]), id])
		var mapping: Dictionary = entry.get("anim_map", {})
		var anims: Array = []
		for name in model.animation_player.get_animation_list():
			anims.append(String(name))
		for logical in CharacterModelScript.LOGICAL_ANIMS:
			var real := str(mapping.get(logical, ""))
			_expect(not real.is_empty(), "mapeo real de %s en %s" % [logical, id])
			_expect(anims.has(real), "clip real existe: %s/%s (%s)" % [id, logical, real])
			_expect(str(model.resolved_animations().get(logical, "")) == real, "animacion logica resuelta: %s/%s" % [id, logical])

	_case = "variacion determinista por semilla"
	var a: Dictionary = CharacterModelScript.v2_resolve("civil", 1234)
	var b: Dictionary = CharacterModelScript.v2_resolve("civil", 1234)
	_expect(not a.is_empty() and not b.is_empty(), "resolve devuelve datos")
	_expect_eq(str(a.get("id", "")), str(b.get("id", "")), "mismo id con la misma semilla")
	_expect(is_equal_approx(float(a.get("scale", 0.0)), float(b.get("scale", 0.0))), "misma escala con la misma semilla")
	_expect(a.get("tint") == b.get("tint"), "mismo tinte con la misma semilla")
	var scale_a := float(a.get("scale", 0.0))
	_expect(scale_a >= 0.95 and scale_a <= 1.05, "escala dentro de 0.95-1.05: %.3f" % scale_a)
	var c: Dictionary = CharacterModelScript.v2_resolve("civil", 77)
	_expect(str(c.get("id", "")) != str(a.get("id", "")) or not is_equal_approx(float(c.get("scale", 0.0)), scale_a) or c.get("tint") != a.get("tint"), "semilla distinta cambia aspecto")
	var seen: Dictionary = {}
	for s in range(40):
		seen[str(CharacterModelScript.v2_resolve("civil", s).get("id", ""))] = true
	_expect(seen.size() >= 3, "varias semillas cubren varios modelos: %d" % seen.size())

	_case = "variacion aplicada a la escena"
	var m1: CharacterModel = CharacterModelScript.spawn_v2(_root, "civil", 4321)
	var m2: CharacterModel = CharacterModelScript.spawn_v2(_root, "civil", 4321)
	await process_frame
	_expect_eq(m1.v2_model_id(), m2.v2_model_id(), "mismo modelo con la misma semilla")
	_expect(is_equal_approx(m1.variation_scale(), m2.variation_scale()), "misma escala aplicada")
	_expect(m1.variation_tint() == m2.variation_tint(), "mismo tinte aplicado")
	_expect(is_equal_approx(m1.height(), 1.75 * m1.variation_scale()), "altura coherente con escala")
	_expect(_count_overrides(m1) > 0, "tinte aplicado como override de material")

	_case = "retrocompatibilidad de la API legacy"
	_expect_eq(CharacterModelScript.skin_ids().size(), 4, "los cuatro ids legacy siguen disponibles")
	var legacy: CharacterModel = CharacterModelScript.spawn(_root, "civil")
	await process_frame
	_expect(legacy.is_loaded(), "spawn legacy sin semilla sigue funcionando")
	_expect(legacy.v2_model_id().is_empty(), "spawn legacy no usa el manifest")

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _seed_for(role: String, id: String) -> int:
	for seed in range(512):
		if str(CharacterModelScript.v2_resolve(role, seed).get("id", "")) == id:
			return seed
	return -1


func _collect_meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, out)


func _count_triangles(node: Node) -> int:
	var meshes: Array = []
	_collect_meshes(node, meshes)
	var total := 0
	for mesh_instance in meshes:
		var mesh := (mesh_instance as MeshInstance3D).mesh
		if mesh == null:
			continue
		for surface in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var indices: Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: Array = arrays[Mesh.ARRAY_VERTEX]
			if indices != null and indices.size() > 0:
				total += indices.size() / 3
			elif vertices != null:
				total += vertices.size() / 3
	return total


func _count_overrides(node: Node) -> int:
	var meshes: Array = []
	_collect_meshes(node, meshes)
	var total := 0
	for mesh_instance in meshes:
		var instance := mesh_instance as MeshInstance3D
		var mesh := instance.mesh
		if mesh == null or not instance.has_method("get_surface_override_material"):
			continue
		for surface in range(mesh.get_surface_count()):
			if instance.call("get_surface_override_material", surface) != null:
				total += 1
	return total


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


func _expect_eq(actual, expected, message: String) -> void:
	_expect(actual == expected, "%s (esperado %s, obtenido %s)" % [message, str(expected), str(actual)])
