extends SceneTree

const CharacterModelScript = preload("res://core/game/character_model.gd")

var _failures: Array = []
var _checks := 0
var _case := ""


func _initialize() -> void:
	await process_frame

	_case = "CharacterModel: SKINS dictionary tiene humano no enemy"
	_expect(CharacterModelScript.SKINS.has("humano"), "SKINS tiene clave 'humano'")
	_expect(not CharacterModelScript.SKINS.has("enemy"), "SKINS no tiene clave 'enemy'")
	_expect(str(CharacterModelScript.SKINS["humano"]).contains("criminal_punk.gltf"), "humano usa modelo criminal_punk.gltf")

	_case = "CharacterModel: ALIASES mapea enemigo y zombie a humano"
	_expect_eq(str(CharacterModelScript.ALIASES.get("enemigo", "")), "humano", "alias 'enemigo' resuelve a 'humano'")
	_expect_eq(str(CharacterModelScript.ALIASES.get("zombie", "")), "humano", "alias 'zombie' resuelve a 'humano'")
	_expect(not CharacterModelScript.ALIASES.has("enemy"), "ALIASES no tiene clave 'enemy'")

	_case = "CharacterModel: ANIM_CANDIDATES tiene animaciones humano_"
	_expect(CharacterModelScript.ANIM_CANDIDATES.has("humano_idle"), "tiene humano_idle")
	_expect(CharacterModelScript.ANIM_CANDIDATES.has("humano_walk"), "tiene humano_walk")
	_expect(CharacterModelScript.ANIM_CANDIDATES.has("humano_run"), "tiene humano_run")
	_expect(CharacterModelScript.ANIM_CANDIDATES.has("humano_attack"), "tiene humano_attack")
	_expect(not CharacterModelScript.ANIM_CANDIDATES.has("zombie_idle"), "no tiene zombie_idle")
	_expect(not CharacterModelScript.ANIM_CANDIDATES.has("zombie_walk"), "no tiene zombie_walk")
	_expect(not CharacterModelScript.ANIM_CANDIDATES.has("zombie_run"), "no tiene zombie_run")
	_expect(not CharacterModelScript.ANIM_CANDIDATES.has("zombie_attack"), "no tiene zombie_attack")

	_case = "CharacterModel: metodo is_humano y set_humano"
	var model: CharacterModel = CharacterModelScript.new()
	root.add_child(model)
	await process_frame
	_expect(model.has_method("is_humano"), "tiene metodo is_humano")
	_expect(model.has_method("set_humano"), "tiene metodo set_humano")
	_expect(not model.has_method("is_zombie"), "no tiene metodo is_zombie")
	_expect(not model.has_method("set_zombie"), "no tiene metodo set_zombie")
	_expect(model.is_humano() == false, "is_humano por defecto es false")
	model.set_humano(true)
	_expect(model.is_humano() == true, "set_humano(true) cambia a true")

	_case = "npc_types.json: tipo humano en lugar de zombie"
	var npc_types_file = FileAccess.open("res://data/base/npc_types.json", FileAccess.READ)
	_expect(npc_types_file != null, "puede leer npc_types.json")
	if npc_types_file != null:
		var text = npc_types_file.get_as_text()
		npc_types_file.close()
		var parsed = JSON.parse_string(text)
		_expect(parsed != null and typeof(parsed) == TYPE_DICTIONARY, "JSON parseado correctamente")
		if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
			var content = parsed.get("content", [])
			var humano_found = false
			var zombie_found = false
			for entry in content:
				var id = str(entry.get("id", ""))
				if id == "untitled.base:humano":
					humano_found = true
					_expect_eq(str(entry.get("name", "")), "Humano", "nombre es 'Humano'")
					_expect_eq(str(entry.get("role", "")), "humano", "role es 'humano'")
					_expect(entry.get("zombie", true) == false, "zombie flag es false")
					_expect(entry.get("aliases", []).has("enemigo"), "aliases incluye 'enemigo'")
					_expect(entry.get("aliases", []).has("humano"), "aliases incluye 'humano'")
				if id == "untitled.base:zombie":
					zombie_found = true
			_expect(humano_found, "existe tipo untitled.base:humano")
			_expect(not zombie_found, "no existe tipo untitled.base:zombie")

	_case = "ScoreBoard: add_kill usa is_humano en codigo fuente"
	var score_board_file = FileAccess.open("res://core/game/score_board.gd", FileAccess.READ)
	_expect(score_board_file != null, "puede leer score_board.gd")
	if score_board_file != null:
		var text = score_board_file.get_as_text()
		score_board_file.close()
		_expect(text.contains("is_humano"), "codigo fuente contiene 'is_humano'")
		_expect(not text.contains("is_zombie"), "codigo fuente no contiene 'is_zombie'")

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


func _expect_eq(actual, expected, message: String) -> void:
	_expect(actual == expected, "%s (esperado %s, obtenido %s)" % [message, str(expected), str(actual)])