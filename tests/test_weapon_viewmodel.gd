extends SceneTree

const ViewModelScript = preload("res://core/game/weapon_viewmodel.gd")
const MuzzleFxScript = preload("res://core/game/muzzle_fx.gd")
const WeaponDbScript = preload("res://core/game/weapon_db.gd")

var _failures: Array = []
var _checks := 0
var _case := ""
var _root: Node3D = null


func _initialize() -> void:
	_root = Node3D.new()
	root.add_child(_root)
	await process_frame

	_case = "resolucion de modelos CC0"
	for id in WeaponDbScript.list_ids():
		var path: String = ViewModelScript.model_path_for(id)
		_expect(not path.is_empty(), "ruta configurada para %s" % id)
		_expect(ResourceLoader.exists(path), "recurso importado para %s (%s)" % [id, path])
		var packed := load(path) as PackedScene
		_expect(packed != null, "GLB cargable para %s" % id)
		if packed == null:
			continue
		var instance := packed.instantiate()
		_expect(instance is Node3D, "modelo %s es escena 3D" % id)
		if not (instance is Node3D):
			instance.free()
			continue
		var meshes: Array = (instance as Node3D).find_children("*", "MeshInstance3D", true, false)
		_expect(meshes.size() > 0, "modelo %s tiene mallas reales" % id)
		var tris := _count_tris(instance)
		_expect(tris > 0, "modelo %s tiene triangulos" % id)
		_expect(tris <= 8000, "modelo %s respeta presupuesto de 8k tris (%d)" % [id, tris])
		instance.free()

	_case = "instancia y seleccion por id"
	var vm = ViewModelScript.new()
	_root.add_child(vm)
	await process_frame
	for id in WeaponDbScript.list_ids():
		_expect(vm.set_weapon(id), "set_weapon(%s)" % id)
		vm.advance(0.3)
		_expect(vm.current_weapon() == id, "id activo %s" % id)
		_expect(vm.has_model(), "modelo instanciado para %s" % id)
		_expect(vm.model_instance() != null and (vm.model_instance() as Node).name == "Model_" + id, "nodo del modelo %s" % id)
		_expect(not vm.is_switching(), "animacion de cambio terminada para %s" % id)

	_case = "posicion clasica de FPS"
	vm.set_weapon("pistol")
	vm.advance(0.3)
	var rest: Vector3 = vm.rig_position()
	_expect(rest.x > 0.0, "arma a la derecha de la camara")
	_expect(rest.y < 0.0, "arma por debajo de la camara")
	_expect(rest.z < 0.0, "arma por delante de la camara")

	_case = "retroceso con muelle"
	vm.set_weapon("assault_rifle")
	vm.advance(0.6)
	var before_recoil: Vector3 = vm.recoil_offset()
	_expect(before_recoil.length() < 0.002, "sin retroceso en reposo")
	vm.on_fired()
	vm.advance(0.016)
	var kicked: Vector3 = vm.recoil_offset()
	_expect(kicked.length() > 0.01, "el disparo desplaza el arma")
	_expect(kicked.y > 0.0 and kicked.z > 0.0, "el retroceso va arriba y atras")
	for i in range(90):
		vm.advance(0.016)
	var settled: Vector3 = vm.recoil_offset()
	_expect(settled.length() < 0.006, "el muelle devuelve el arma al reposo")
	_expect(settled.length() < kicked.length() * 0.2, "el retroceso se amortigua")

	_case = "recarga con la duracion indicada"
	vm.set_weapon("shotgun")
	vm.advance(0.4)
	var reload_rest: Vector3 = vm.rig_position()
	vm.on_reload_started(0.4)
	_expect(vm.is_reloading(), "recarga iniciada")
	vm.advance(0.2)
	_expect(vm.is_reloading(), "recarga en curso a mitad")
	_expect(vm.rig_position().y < reload_rest.y - 0.05, "el arma baja durante la recarga")
	vm.advance(0.25)
	_expect(not vm.is_reloading(), "recarga terminada en la duracion indicada")
	_expect(absf(vm.rig_position().y - reload_rest.y) < 0.01, "el arma vuelve a su posicion de reposo")

	_case = "bombeo de escopeta"
	vm.on_fired()
	_expect(vm.is_pumping(), "bombeo iniciado al disparar")
	vm.advance(0.16)
	_expect(vm.is_pumping(), "bombeo en curso")
	vm.advance(0.25)
	_expect(not vm.is_pumping(), "bombeo terminado")

	_case = "cambio de arma"
	vm.set_weapon("pistol")
	vm.advance(0.3)
	var previous_model: Node = vm.model_instance()
	_expect(vm.set_weapon("sniper_rifle"), "cambio a francotirador")
	_expect(vm.is_switching(), "animacion corta de cambio activa")
	_expect(vm.current_weapon() == "sniper_rifle", "id actualizado al cambiar")
	vm.advance(0.3)
	_expect(not vm.is_switching(), "animacion de cambio finalizada")
	_expect(vm.model_instance() != previous_model, "modelo anterior sustituido")
	_expect(vm.has_model(), "modelo nuevo visible tras el cambio")

	_case = "balanceo al caminar"
	vm.set_weapon("pistol")
	vm.advance(0.4)
	var bob_rest: float = vm.rig_position().y
	vm.set_walk_intensity(1.0)
	var bobbed := false
	for i in range(24):
		vm.advance(0.016)
		if absf(vm.rig_position().y - bob_rest) > 0.002:
			bobbed = true
	_expect(bobbed, "head bob mueve el arma al caminar")
	vm.set_walk_intensity(0.0)
	vm.advance(0.016)
	_expect(absf(vm.rig_position().y - bob_rest) < 0.001, "head bob desactivado")

	_case = "arma vacia"
	vm.on_empty()
	vm.advance(0.09)
	_expect(vm.rig_position().y < bob_rest - 0.005, "movimiento seco al quedar vacia")
	vm.advance(0.2)
	_expect(absf(vm.rig_position().y - bob_rest) < 0.01, "vuelve al reposo tras arma vacia")

	_case = "sin modelo, error controlado"
	var keep_id: String = vm.current_weapon()
	var keep_model: Node = vm.model_instance()
	_expect(not vm.set_weapon("__no_existe__"), "id desconocido rechazado sin fallo")
	_expect(vm.current_weapon() == keep_id, "se conserva el arma anterior")
	_expect(vm.model_instance() == keep_model, "no se destruye el modelo actual")
	_expect(ViewModelScript.model_path_for("__no_existe__").is_empty(), "sin ruta para id desconocido")

	_case = "attach_to para mano VR"
	var hand := Node3D.new()
	_root.add_child(hand)
	vm.set_walk_intensity(1.0)
	vm.attach_to(hand)
	_expect(vm.get_parent() == hand, "viewmodel colgado de la mano")
	_expect(vm.is_in_vr_hand(), "modo VR activado")
	_expect(vm.walk_intensity == 0.0, "sin bob automatico en VR")
	vm.advance(0.2)
	_expect(absf(vm.rig_position().y - bob_rest) < 0.01, "posicion estable en la mano VR")

	_case = "particiones moviles por modelo"
	for id in ["pistol", "submachine_gun", "assault_rifle", "shotgun", "sniper_rifle", "bat"]:
		_expect(vm.set_weapon(id), "seleccion %s para particion" % id)
		vm.advance(0.3)
		var parts = vm.parts()
		_expect(parts != null, "piezas construidas para %s" % id)
		if parts == null:
			continue
		_expect(parts.roles.size() >= 1, "al menos una pieza en %s" % id)
		if id == "bat":
			_expect(parts.has_role("body"), "bate con cuerpo sin piezas moviles")
		else:
			_expect(parts.has_role("magazine"), "cargador modelado en %s" % id)
			_expect(vm.eject_offset().length() > 0.0, "ventana de eyeccion configurada en %s" % id)

	_case = "corredera de pistola"
	vm.set_weapon("pistol")
	vm.advance(0.3)
	_expect(vm.parts().has_role("slide"), "pistola con corredera")
	vm.on_fired()
	vm.advance(0.04)
	_expect(vm.is_fire_stroking(), "ciclo de disparo activo")
	_expect(vm.part_offset("slide").x < -0.01, "corredera retrocede al disparar")
	vm.advance(0.25)
	_expect(not vm.is_fire_stroking(), "ciclo de disparo terminado")
	_expect(absf(vm.part_offset("slide").x) < 0.005, "corredera vuelve al reposo")

	_case = "cerrojo y palanca AK"
	vm.set_weapon("assault_rifle")
	vm.advance(0.3)
	vm.on_fired()
	vm.advance(0.04)
	_expect(vm.part_offset("bolt").x < -0.01, "cerrojo retrocede en cada disparo")
	_expect(vm.part_offset("charging_handle").x < -0.01, "palanca AK acompana al cerrojo")
	vm.advance(0.25)
	_expect(absf(vm.part_offset("bolt").x) < 0.005, "cerrojo vuelve al reposo")

	_case = "corredera trabada con cargador vacio"
	vm.set_weapon("pistol")
	vm.advance(0.3)
	vm.on_empty()
	vm.advance(0.25)
	_expect(vm.is_slide_locked(), "corredera queda atras al vaciarse")
	_expect(vm.part_offset("slide").x < -0.05, "corredera retenida")
	vm.on_reload_started(0.5)
	for i in range(30):
		vm.advance(0.02)
	_expect(not vm.is_slide_locked(), "corredera se libera al recargar")
	_expect(absf(vm.part_offset("slide").x) < 0.005, "corredera vuelve tras recarga")

	_case = "cargador cae y se recicla"
	MuzzleFxScript.clear()
	vm.set_weapon("assault_rifle")
	vm.advance(0.3)
	_expect(MuzzleFxScript.active_dropped_magazine_count() == 0, "sin cargadores caidos al inicio")
	vm.on_reload_started(0.5)
	vm.advance(0.02)
	_expect(vm.reload_phase() == "drop_mag", "fase soltar cargador")
	_expect(MuzzleFxScript.active_dropped_magazine_count() == 1, "cargador soltado como cuerpo rigido")
	_expect(MuzzleFxScript.dropped_magazine_at(0) is RigidBody3D, "cargador caido fisico")
	_expect(not vm.parts().node("magazine").visible, "cargador original oculto al caer")
	vm.advance(0.15)
	_expect(vm.reload_phase() == "insert_mag", "fase introducir cargador")
	_expect(vm.parts().node("magazine").visible, "cargador nuevo visible")
	_expect(vm.part_offset("magazine").y < -0.02, "cargador nuevo entra desde abajo")
	vm.advance(0.4)
	_expect(not vm.is_reloading(), "recarga finalizada")
	_expect(absf(vm.part_offset("magazine").y) < 0.005, "cargador asentado")
	MuzzleFxScript.advance(3.0)
	_expect(MuzzleFxScript.active_dropped_magazine_count() == 0, "cargador caido reciclado")

	_case = "fases de recarga en orden"
	vm.on_reload_started(0.5)
	for i in range(30):
		vm.advance(0.02)
	_expect(vm.reload_phases() == ["drop_mag", "insert_mag", "seat_mag", "charge"], "fases ordenadas: %s" % str(vm.reload_phases()))

	_case = "bombeo de escopeta y sonido"
	vm.set_weapon("shotgun")
	vm.advance(0.4)
	_expect(vm.parts().has_role("pump"), "escopeta con pieza de bombeo")
	vm.on_fired()
	vm.advance(0.12)
	_expect(vm.part_offset("pump").x < -0.05, "bombeo corre hacia atras")
	var pump_players: Array = []
	for node in _root.find_children("*", "AudioStreamPlayer3D", true, false):
		var player: AudioStreamPlayer3D = node as AudioStreamPlayer3D
		if player != null and player.stream == RecordedSfx.stream_for("shotgun", "pump"):
			pump_players.append(player)
	_expect(pump_players.size() > 0, "sonido pump sincronizado con el bombeo")
	vm.advance(0.3)
	_expect(absf(vm.part_offset("pump").x) < 0.005, "bombeo vuelve al frente")

	_case = "recarga cartucho a cartucho"
	vm.on_reload_started(0.6)
	vm.advance(0.10)
	_expect(vm.reload_phase() == "drop_mag", "apertura de escopeta")
	vm.advance(0.10)
	_expect(vm.reload_phase() == "insert_mag", "introduccion de cartuchos")
	_expect(vm.part_offset("pump").x < -0.01, "bombeo cicla por cartucho")
	vm.advance(0.45)
	_expect(not vm.is_reloading(), "recarga de escopeta terminada")

	_case = "casquillos por ventana de eyeccion"
	MuzzleFxScript.clear()
	var fx_test: MuzzleFx = vm.muzzle_fx()
	fx_test.fire(1.0, Vector3.FORWARD, Vector3(1.0, 0.0, 0.0))
	var last_casing := MuzzleFxScript.active_casing_at(MuzzleFxScript.active_casing_count() - 1)
	_expect(last_casing != null, "casquillo generado")
	if last_casing != null:
		_expect(last_casing.global_position.distance_to(fx_test.global_transform * Vector3(1.0, 0.0, 0.0)) < 0.001, "casquillo nace en la ventana")
	MuzzleFxScript.clear()

	_case = "topes globales de muzzle fx"
	MuzzleFxScript.clear()
	var fx = MuzzleFxScript.new()
	_root.add_child(fx)
	await process_frame
	for i in range(60):
		fx.fire(1.0)
	_expect(MuzzleFxScript.casing_count() == MuzzleFxScript.MAX_CASINGS, "pool de casquillos limitado a 24")
	_expect(MuzzleFxScript.active_casing_count() == MuzzleFxScript.MAX_CASINGS, "casquillos activos con tope")
	_expect(MuzzleFxScript.casing_at(0) is RigidBody3D, "casquillos son cuerpos rigidos")
	_expect(MuzzleFxScript.flash_count() <= MuzzleFxScript.MAX_FLASHES, "tope de fogonazos")
	_expect(MuzzleFxScript.smoke_count() <= MuzzleFxScript.MAX_SMOKE, "tope de humo")
	_expect(MuzzleFxScript.flash_light_count() > 0, "luz de fogonazo presente en el frame del disparo")
	MuzzleFxScript.advance(0.02)
	_expect(MuzzleFxScript.flash_light_count() == 0, "luz de fogonazo de un solo frame")
	_expect(MuzzleFxScript.flash_count() <= MuzzleFxScript.MAX_FLASHES, "particulas de fogonazo con tope")
	MuzzleFxScript.clear()
	_expect(MuzzleFxScript.active_casing_count() == 0, "limpieza de casquillos")

	for player_node in _root.find_children("*", "AudioStreamPlayer3D", true, false):
		var player: AudioStreamPlayer3D = player_node as AudioStreamPlayer3D
		if player != null and not player.is_queued_for_deletion():
			player.stop()
			player.stream = null
			player.free()
	MuzzleFxScript.shutdown()
	RecordedSfx._cache.clear()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _count_tris(root: Node) -> int:
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


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


func _expect_eq(actual, expected, message: String) -> void:
	_expect(actual == expected, "%s (esperado %s, obtenido %s)" % [message, str(expected), str(actual)])
