extends SceneTree

const CharacterModelScript = preload("res://core/game/character_model.gd")
const SessionScript = preload("res://core/game/game_session.gd")

var _failures: Array = []
var _checks := 0
var _case := ""
var _root: Node3D = null
var _gore_before := true


func _initialize() -> void:
	_root = Node3D.new()
	root.add_child(_root)
	await process_frame
	_gore_before = bool(SessionScript.gore_enabled)

	_case = "registro y carga de modelos reales"
	_expect_eq(CharacterModelScript.skin_ids().size(), 4, "cuatro variantes registradas")
	var loaded: Array = []
	for id in ["civil", "soldier", "enemy", "robot"]:
		var model: CharacterModel = CharacterModelScript.spawn(_root, id)
		await process_frame
		_expect(model.is_loaded(), "modelo cargado: %s" % id)
		_expect(absf(model.height() - 1.75) < 0.02, "altura normalizada 1.75 m: %s" % id)
		_expect(model.skeleton != null and model.skeleton.get_bone_count() >= 20, "esqueleto real: %s" % id)
		_expect(model.animation_player != null, "AnimationPlayer presente: %s" % id)
		_expect(model.model_root != null, "nodo de modelo instanciado: %s" % id)
		loaded.append(model)

	_case = "alias en espanol"
	var Spanish: CharacterModel = CharacterModelScript.spawn(_root, "soldado")
	await process_frame
	_expect_eq(Spanish.skin_id, "soldier", "alias soldado resuelve a soldier")
	var Enemy: CharacterModel = CharacterModelScript.spawn(_root, "enemigo")
	await process_frame
	_expect_eq(Enemy.skin_id, "enemy", "alias enemigo resuelve a enemy")
	var Missing: CharacterModel = CharacterModelScript.spawn(_root, "inexistente")
	_expect(not Missing.is_loaded(), "id desconocido no carga nada")

	_case = "mapa de animaciones logicas"
	var soldier: CharacterModel = loaded[1]
	var resolved: Dictionary = soldier.resolved_animations()
	for logical in CharacterModelScript.LOGICAL_ANIMS:
		_expect(not str(resolved.get(logical, "")).is_empty(), "animacion logica resuelta: %s" % logical)
	_expect_eq(str(resolved.get("idle")), "Idle", "idle usa clip real")
	_expect_eq(str(resolved.get("walk")), "Walk", "walk usa clip real")
	_expect_eq(str(resolved.get("run")), "Run", "run usa clip real")
	_expect_eq(str(resolved.get("aim")), "Idle_Gun_Pointing", "aim usa clip real")
	_expect_eq(str(resolved.get("shoot")), "Gun_Shoot", "shoot usa clip real")
	_expect_eq(str(resolved.get("hit")), "HitRecieve", "hit usa clip real")
	_expect_eq(str(resolved.get("die")), "Death", "die usa clip real")
	var robot: CharacterModel = loaded[3]
	var robot_anims: Dictionary = robot.resolved_animations()
	for logical in CharacterModelScript.LOGICAL_ANIMS:
		_expect(not str(robot_anims.get(logical, "")).is_empty(), "fallback de animacion en robot: %s" % logical)
	_expect_eq(str(robot_anims.get("die")), "death", "fallback de muerte en minúsculas")

	_case = "play y stop"
	_expect(soldier.play("idle"), "reproducir idle")
	_expect_eq(soldier.current_animation(), "idle", "animacion actual registrada")
	_expect(soldier.play("run", false), "reproducir run sin bucle")
	_expect_eq(soldier.current_animation(), "run", "cambio de animacion")
	_expect(not soldier.play("no_existe"), "animacion inexistente rechazada sin error")
	soldier.stop()
	_expect_eq(soldier.current_animation(), "", "stop limpia animacion actual")

	_case = "ragdoll con PhysicalBone3D"
	CharacterModelScript.clear_ragdolls()
	var rag := soldier.make_ragdoll(Vector3(5.0, 2.0, 0.0), soldier.global_position + Vector3.UP)
	_expect(rag != null, "make_ragdoll devuelve nodo")
	await physics_frame
	_expect(_count_physical(soldier) >= 8, "esqueleto convertido en cuerpos fisicos")
	_expect_eq(CharacterModelScript.ragdoll_count(), 1, "ragdoll registrado")
	_expect(soldier.animation_player.is_playing() == false, "animacion detenida al hacer ragdoll")
	_expect(soldier.play("idle") == false, "no se reproducen animaciones sobre ragdoll")

	_case = "tope global de ragdolls"
	for i in range(10):
		var extra: CharacterModel = CharacterModelScript.spawn(_root, "civil")
		await process_frame
		var extra_rag := extra.make_ragdoll(Vector3.RIGHT, extra.global_position)
		_expect(extra_rag != null, "ragdoll adicional %d" % i)
	_expect_eq(CharacterModelScript.ragdoll_count(), CharacterModelScript.MAX_RAGDOLLS, "tope global de 8 ragdolls")
	CharacterModelScript.clear_ragdolls()
	_expect_eq(CharacterModelScript.ragdoll_count(), 0, "limpieza de ragdolls")

	_case = "wound y detach con gore apagado"
	var model: CharacterModel = loaded[0]
	SessionScript.gore_enabled = false
	var child_before := model.get_child_count()
	var wound_off := model.apply_wound("Head", Vector3.FORWARD, 0.2)
	var limb_off := model.detach_limb("UpperArm.L")
	_expect(wound_off == null, "sin herida con gore apagado")
	_expect(limb_off == null, "sin desmembramiento con gore apagado")
	_expect_eq(model.get_child_count(), child_before, "gore apagado no crea nodos")

	_case = "wound y detach con gore encendido"
	SessionScript.gore_enabled = true
	var wound := model.apply_wound("Head", Vector3.FORWARD, 0.2)
	_expect(wound is MeshInstance3D, "decal de sangre creado")
	_expect(wound.name == "CharacterWound", "nombre del decal")
	var limb := model.detach_limb("UpperArm.L")
	_expect(limb is RigidBody3D, "miembro lanzado como cuerpo rigido")
	_expect(_is_limb_hidden(model, "UpperArm.L"), "hueso del miembro escalado a cero")
	_expect(model.get_child_count() > child_before, "gore encendido crea nodos")
	var unknown_wound := model.apply_wound("hueso_inexistente", Vector3.UP, 0.2)
	_expect(unknown_wound is MeshInstance3D, "herida con hueso desconocido usa centro del cuerpo")
	var unknown_limb := model.detach_limb("hueso_inexistente")
	_expect(unknown_limb == null, "desmembrar hueso desconocido no falla")

	_case = "modelo sin animacion definida"
	var empty: CharacterModel = CharacterModelScript.new()
	_root.add_child(empty)
	await process_frame
	_expect(absf(empty.height() - 1.75) < 0.001, "altura por defecto sin modelo")
	_expect(not empty.play("idle"), "play sin AnimationPlayer no falla")
	empty.stop()
	_expect(empty.bone_names().is_empty(), "sin esqueleto no hay huesos")
	var empty_rag := empty.make_ragdoll(Vector3.FORWARD, empty.global_position)
	_expect(empty_rag != null, "ragdoll de respaldo sin esqueleto")
	_expect(_count_physical(empty) > 0 || _count_physical(empty_rag) > 0, "segmentos rigidos de respaldo")
	var empty_wound := empty.apply_wound("Head", Vector3.UP, 0.3)
	_expect(empty_wound is MeshInstance3D, "herida sin esqueleto no falla")
	_expect(empty.detach_limb("Head") == null, "desmembrar sin esqueleto no falla")

	SessionScript.gore_enabled = _gore_before
	CharacterModelScript.clear_ragdolls()
	await process_frame
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _count_physical(node: Node) -> int:
	var count := 0
	if node is PhysicalBone3D or node is RigidBody3D:
		count += 1
	for child in node.get_children():
		count += _count_physical(child)
	return count


func _is_limb_hidden(model: CharacterModel, bone_name: String) -> bool:
	if model.skeleton == null:
		return false
	var idx := model.skeleton.find_bone(bone_name)
	if idx < 0:
		return false
	var scale := model.skeleton.get_bone_pose_scale(idx)
	return scale.x < 0.01 and scale.y < 0.01 and scale.z < 0.01


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


func _expect_eq(actual, expected, message: String) -> void:
	_expect(actual == expected, "%s (esperado %s, obtenido %s)" % [message, str(expected), str(actual)])
