extends SceneTree

# B1 (a): al spawnear el mundo no debe haber armas duplicadas ni mal colocadas:
# una sola arma por NPC (punto de aparicion) y colocada junto al NPC.

const HarnessScript = preload("res://tests/vr_sim_harness.gd")
const GeneratorScript = preload("res://core/maps/map_generator.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""


func _initialize() -> void:
	await process_frame
	await _run()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + str(failure))
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


func _run() -> void:
	var harness = HarnessScript.new()
	await harness.start(self, GeneratorScript.generate(4242, {
		"width": 24, "height": 18, "obstacle_density": 0.12, "spawn_count": 5,
	}))
	var world = harness.world
	await process_frame
	await physics_frame

	_case = "NPC spawneados sin duplicados"
	var tree_npcs: Array = get_nodes_in_group("armed_npc")
	_expect(world.npcs.size() >= 6, "hay al menos 6 NPCs (%d)" % world.npcs.size())
	_expect(tree_npcs.size() == world.npcs.size(),
		"el arbol tiene los mismos NPCs que el mundo (%d vs %d)" % [tree_npcs.size(), world.npcs.size()])
	var unique: bool = true
	for i in range(world.npcs.size()):
		for j in range(i + 1, world.npcs.size()):
			var a: Node3D = world.npcs[i]
			var b: Node3D = world.npcs[j]
			if a.global_position.distance_to(b.global_position) < 0.5:
				unique = false
	_expect(unique, "ningun punto de aparicion tiene dos NPCs encima")

	_case = "una sola arma por NPC y colocada en sitio valido"
	for npc in world.npcs:
		var mount: Node = npc.get_node_or_null("WeaponMount")
		_expect(mount != null, "el NPC %s tiene WeaponMount" % str(npc.get("npc_id")))
		if mount == null:
			continue
		var models: Array = []
		for child in mount.get_children():
			if str(child.name) != "WeaponVisual":
				models.append(child)
		var weapon_id: String = str(npc.get("weapon_id"))
		if weapon_id.is_empty():
			_expect(models.is_empty(), "NPC %s sin arma no tiene modelo de arma suelto (%d)" % [str(npc.get("npc_id")), models.size()])
		else:
			_expect(models.size() == 1, "NPC %s con arma '%s' tiene exactamente 1 modelo en WeaponMount (%d)" % [
				str(npc.get("npc_id")), weapon_id, models.size()])
			for model in models:
				var box: AABB = _global_aabb(model)
				var dist: float = box.get_center().distance_to(npc.global_position)
				_expect(dist < 2.5, "el arma de %s esta junto al NPC (distancia %.2f m)" % [str(npc.get("npc_id")), dist])
				var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
				_expect(longest > 0.05 and longest < 5.0,
					"el arma de %s tiene tamano realista (%.2f m)" % [str(npc.get("npc_id")), longest])
				_expect(box.has_point(Vector3(npc.global_position.x, box.get_center().y, npc.global_position.z)) or dist < 2.5,
					"el arma de %s no esta dentro de un obstaculo lejano" % str(npc.get("npc_id")))

	_case = "sin armas sueltas tiradas al arrancar"
	var dropped: Array = []
	for node in root.find_children("DroppedWeapon_*", "Node3D", true, false):
		dropped.append(node)
	_expect(dropped.is_empty(), "no hay DroppedWeapon en el mapa al arrancar (%d)" % dropped.size())

	_case = "NPC dentro de limites"
	for npc in world.npcs:
		_expect(world.bounds.has_point(npc.global_position),
			"NPC %s dentro de los limites del mapa" % str(npc.get("npc_id")))

	harness.cleanup()
	await process_frame


func _global_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	var nodes: Array = [node]
	nodes.append_array(node.find_children("*", "MeshInstance3D", true, false))
	for item in nodes:
		if not (item is MeshInstance3D) or (item as MeshInstance3D).mesh == null:
			continue
		var mi := item as MeshInstance3D
		var box: AABB = mi.global_transform * mi.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
