extends SceneTree

const ModResolverScript = preload("res://core/mod_resolver.gd")

var _failures: Array = []
var _case := ""


func _init() -> void:
	_case = "satisfies exacto y comparadores"
	_test_satisfies_comparators()

	_case = "satisfies caret"
	_test_satisfies_caret()

	_case = "is_valid_range"
	_test_valid_range()

	_case = "compare numerico"
	_test_compare()

	_case = "cadena simple"
	_test_chain()

	_case = "diamante"
	_test_diamond()

	_case = "dependencia inexistente"
	_test_missing_dependency()

	_case = "version que no cumple y propagacion"
	_test_version_mismatch()

	_case = "ciclo"
	_test_cycle()

	_case = "autodependencia"
	_test_self_dependency()

	_case = "id duplicado"
	_test_duplicate_id()

	_case = "empate de prioridades"
	_test_priority_ties()

	_case = "determinismo"
	_test_determinism()

	_case = "manifiesto envuelto"
	_test_wrapped_manifest()

	if _failures.is_empty():
		print("TEST_OK")
		quit(0)
	else:
		print("TEST_FAIL: ", "; ".join(_failures))
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append("%s: %s" % [_case, message])


func _mod(id: String, version: String, depends: Dictionary, priority: int = 100) -> Dictionary:
	return {
		"id": id,
		"version": version,
		"depends": depends,
		"priority": priority,
	}


func _errors_text(result: Dictionary) -> String:
	return " | ".join(result["errors"])


func _expect_error(result: Dictionary, needle: String) -> void:
	_expect(not result["ok"], "se esperaba ok=false")
	var text := _errors_text(result)
	_expect(
		text.contains(needle),
		"se esperaba un error que contenga '%s', errores: %s" % [needle, text]
	)


func _expect_order(result: Dictionary, expected: Array) -> void:
	var order: Array = result["order"]
	_expect(
		order == expected,
		"orden incorrecto: se esperaba %s, se obtuvo %s" % [str(expected), str(order)]
	)


func _test_satisfies_comparators() -> void:
	_expect(ModResolverScript.satisfies("1.2.3", "1.2.3"), "exacto igual debe cumplir")
	_expect(not ModResolverScript.satisfies("1.2.4", "1.2.3"), "exacto distinto no debe cumplir")
	_expect(ModResolverScript.satisfies("1.0.0", ">=1.0.0"), ">= limite debe cumplir")
	_expect(not ModResolverScript.satisfies("0.9.9", ">=1.0.0"), ">= menor no debe cumplir")
	_expect(ModResolverScript.satisfies("1.9.9", "<2.0.0"), "< debe cumplir")
	_expect(not ModResolverScript.satisfies("2.0.0", "<2.0.0"), "< limite no debe cumplir")
	_expect(ModResolverScript.satisfies("1.9.9", ">=1.0.0 <2.0.0"), "combinacion 1.9.9 debe cumplir")
	_expect(not ModResolverScript.satisfies("2.0.0", ">=1.0.0 <2.0.0"), "combinacion 2.0.0 no debe cumplir")
	_expect(not ModResolverScript.satisfies("0.9.9", ">=1.0.0 <2.0.0"), "combinacion 0.9.9 no debe cumplir")
	_expect(ModResolverScript.satisfies("0.0.0", "*"), "* debe cumplir todo")
	_expect(ModResolverScript.satisfies("9.9.9", "*"), "* debe cumplir todo")
	_expect(not ModResolverScript.satisfies("1.2", ">=1.0.0"), "version invalida no debe cumplir")
	_expect(not ModResolverScript.satisfies("1.2.3", ">=abc"), "rango invalido no debe cumplir")


func _test_satisfies_caret() -> void:
	_expect(ModResolverScript.satisfies("1.5.0", "^1.2.0"), "^1.2.0 debe aceptar 1.5.0")
	_expect(not ModResolverScript.satisfies("2.0.0", "^1.2.0"), "^1.2.0 no debe aceptar 2.0.0")
	_expect(not ModResolverScript.satisfies("1.1.9", "^1.2.0"), "^1.2.0 no debe aceptar 1.1.9")
	_expect(ModResolverScript.satisfies("1.2.0", "^1.2.0"), "^1.2.0 debe aceptar 1.2.0")
	_expect(ModResolverScript.satisfies("0.2.9", "^0.2.0"), "^0.2.0 debe aceptar 0.2.9")
	_expect(not ModResolverScript.satisfies("0.3.0", "^0.2.0"), "^0.2.0 no debe aceptar 0.3.0")


func _test_valid_range() -> void:
	_expect(not ModResolverScript.is_valid_range(""), "rango vacio debe ser invalido")
	_expect(not ModResolverScript.is_valid_range(">=1"), ">=1 debe ser invalido")
	_expect(not ModResolverScript.is_valid_range("^abc"), "^abc debe ser invalido")
	_expect(ModResolverScript.is_valid_range(">=1.0.0 <2.0.0"), "combinacion debe ser valida")
	_expect(ModResolverScript.is_valid_range("*"), "* debe ser valido")
	_expect(ModResolverScript.is_valid_range("^1.2.0"), "^1.2.0 debe ser valido")
	_expect(ModResolverScript.is_valid_range("1.2.3"), "exacto debe ser valido")


func _test_compare() -> void:
	_expect(ModResolverScript.compare("1.10.0", "1.9.0") == 1, "1.10.0 debe ser mayor que 1.9.0")
	_expect(ModResolverScript.compare("1.9.0", "1.10.0") == -1, "1.9.0 debe ser menor que 1.10.0")
	_expect(ModResolverScript.compare("1.0.0", "1.0.0") == 0, "iguales deben ser 0")


func _test_chain() -> void:
	var result := ModResolverScript.resolve([
		_mod("mod.a", "1.0.0", {"mod.b": "*"}),
		_mod("mod.b", "1.0.0", {"mod.c": "*"}),
		_mod("mod.c", "1.0.0", {}),
	])
	_expect(result["ok"], "errores inesperados: %s" % _errors_text(result))
	_expect_order(result, ["mod.c", "mod.b", "mod.a"])


func _test_diamond() -> void:
	var result := ModResolverScript.resolve([
		_mod("dm.d", "1.0.0", {"dm.b": "*", "dm.c": "*"}),
		_mod("dm.b", "1.0.0", {"dm.a": "*"}),
		_mod("dm.c", "1.0.0", {"dm.a": "*"}),
		_mod("dm.a", "1.0.0", {}),
	])
	_expect(result["ok"], "errores inesperados: %s" % _errors_text(result))
	_expect_order(result, ["dm.a", "dm.b", "dm.c", "dm.d"])


func _test_missing_dependency() -> void:
	var result := ModResolverScript.resolve([
		_mod("miss.x", "1.0.0", {"ghost.mod": ">=1.0.0"}),
		_mod("miss.z", "1.0.0", {}),
	])
	_expect_error(result, "miss.x")
	_expect_error(result, "ghost.mod")
	_expect_error(result, "no está instalado")
	_expect_order(result, ["miss.z"])
	_expect(not result["versions"].has("miss.x"), "miss.x no debe tener version cargada")


func _test_version_mismatch() -> void:
	var result := ModResolverScript.resolve([
		_mod("ver.y", "1.0.0", {}),
		_mod("ver.x", "1.0.0", {"ver.y": ">=2.0.0"}),
		_mod("ver.w", "1.0.0", {"ver.x": "*"}),
		_mod("ver.z", "1.0.0", {}),
	])
	_expect_error(result, "ver.x requiere ver.y >=2.0.0, instalada 1.0.0")
	_expect_error(result, "ver.w no se carga porque ver.x no se carga")
	_expect_order(result, ["ver.y", "ver.z"])


func _test_cycle() -> void:
	var result := ModResolverScript.resolve([
		_mod("cy.a", "1.0.0", {"cy.b": "*"}),
		_mod("cy.b", "1.0.0", {"cy.a": "*"}),
		_mod("cy.z", "1.0.0", {}),
	])
	_expect_error(result, "circular")
	_expect_error(result, "cy.a")
	_expect_error(result, "cy.b")
	_expect_order(result, ["cy.z"])


func _test_self_dependency() -> void:
	var result := ModResolverScript.resolve([
		_mod("sf.a", "1.0.0", {"sf.a": "1.0.0"}),
	])
	_expect_error(result, "circular")
	_expect_error(result, "sf.a")
	_expect_order(result, [])


func _test_duplicate_id() -> void:
	var result := ModResolverScript.resolve([
		_mod("dup.a", "1.0.0", {}),
		_mod("dup.a", "2.0.0", {}),
		_mod("other.b", "1.0.0", {}),
	])
	_expect_error(result, "id duplicado")
	_expect_error(result, "dup.a")
	_expect_order(result, ["other.b"])
	_expect(not result["versions"].has("dup.a"), "dup.a no debe cargarse")

	var equal_result := ModResolverScript.resolve([
		_mod("same.a", "1.0.0", {}),
		_mod("same.a", "1.0.0", {}),
	])
	_expect_error(equal_result, "id duplicado")
	_expect_order(equal_result, [])


func _test_priority_ties() -> void:
	var result := ModResolverScript.resolve([
		_mod("tie.high", "1.0.0", {}, 100),
		_mod("tie.low", "1.0.0", {}, 50),
	])
	_expect(result["ok"], "errores inesperados: %s" % _errors_text(result))
	_expect_order(result, ["tie.low", "tie.high"])

	var alphabetical := ModResolverScript.resolve([
		_mod("zeta.mod", "1.0.0", {}, 100),
		_mod("alfa.mod", "1.0.0", {}, 100),
	])
	_expect(alphabetical["ok"], "errores inesperados: %s" % _errors_text(alphabetical))
	_expect_order(alphabetical, ["alfa.mod", "zeta.mod"])


func _test_determinism() -> void:
	var manifests := [
		_mod("det.d", "1.0.0", {"det.b": "*", "det.c": "*"}),
		_mod("det.c", "1.0.0", {"det.a": "*"}),
		_mod("det.b", "1.0.0", {"det.a": "*"}),
		_mod("det.a", "1.0.0", {}),
		_mod("det.e", "1.0.0", {}, 10),
	]
	var reversed: Array = manifests.duplicate()
	reversed.reverse()
	var forward_result := ModResolverScript.resolve(manifests)
	var reversed_result := ModResolverScript.resolve(reversed)
	_expect(forward_result["ok"], "errores inesperados: %s" % _errors_text(forward_result))
	_expect(reversed_result["ok"], "errores inesperados: %s" % _errors_text(reversed_result))
	_expect(
		forward_result["order"] == reversed_result["order"],
		"el orden debe ser determinista: %s vs %s"
		% [str(forward_result["order"]), str(reversed_result["order"])]
	)
	_expect_order(forward_result, ["det.e", "det.a", "det.b", "det.c", "det.d"])


func _test_wrapped_manifest() -> void:
	var result := ModResolverScript.resolve([
		{"manifest": _mod("wrap.a", "1.0.0", {}), "ok": true, "errors": []},
	])
	_expect(result["ok"], "errores inesperados: %s" % _errors_text(result))
	_expect_order(result, ["wrap.a"])
