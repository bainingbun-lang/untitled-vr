extends SceneTree

const ModCapabilitiesScript = preload("res://core/mod_capabilities.gd")

const VALID_STATUSES := [
	"ALLOWED",
	"ALLOWED_AFTER_RESTART",
	"NEEDS_PERMISSION",
	"REQUIRES_RECOMPILE",
	"IMPOSSIBLE_ON_PLATFORM",
	"UNVERIFIED",
	"UNKNOWN_INPUT",
]

var _failures: Array = []
var _case := ""


func _init() -> void:
	_case = "pc/core_script"
	_test_core_script()

	_case = "pc/native_extension"
	_test_native_extension()

	_case = "android/script"
	_test_android_script()

	_case = "kind desconocido"
	_test_unknown()

	_case = "status fuera de la lista"
	_test_valid_statuses()

	_case = "todas las combinaciones"
	_test_all_combinations()

	if _failures.is_empty():
		print("TEST_OK")
		quit(0)
	else:
		print("TEST_FAIL: ", "; ".join(_failures))
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append("%s: %s" % [_case, message])


func _test_core_script() -> void:
	var result := ModCapabilitiesScript.describe("core_script", "pc")
	_expect(result["status"] == "ALLOWED_AFTER_RESTART", "core_script/pc debe requerir reinicio")
	_expect((result["flags"] as Array).has("STABILITY_WARNING"), "debe advertir inestabilidad")


func _test_native_extension() -> void:
	var result := ModCapabilitiesScript.describe("native_extension", "pc")
	_expect(result["status"] == "REQUIRES_RECOMPILE", "native_extension/pc debe requerir recompilar")
	_expect((result["flags"] as Array).has("NEEDS_PERMISSION"), "debe indicar NEEDS_PERMISSION")
	_expect((result["flags"] as Array).has("RISK_NATIVE_CODE"), "debe indicar RISK_NATIVE_CODE")
	_expect(str(result["note"]).contains("NO PROBADO"), "la nota debe decir NO PROBADO")


func _test_android_script() -> void:
	var result := ModCapabilitiesScript.describe("script", "android")
	_expect(result["status"] == "UNVERIFIED", "script/android debe ser UNVERIFIED")
	_expect(str(result["note"]) == "no probado en esta plataforma", "la nota debe indicar no probado")


func _test_unknown() -> void:
	var unknown_kind := ModCapabilitiesScript.describe("inventado", "pc")
	_expect(unknown_kind["status"] == "UNKNOWN_INPUT", "kind desconocido debe ser UNKNOWN_INPUT")
	_expect((unknown_kind["flags"] as Array).is_empty(), "UNKNOWN_INPUT no debe inventar flags")

	var unknown_platform := ModCapabilitiesScript.describe("script", "consola")
	_expect(
		unknown_platform["status"] == "UNKNOWN_INPUT",
		"platform desconocida debe ser UNKNOWN_INPUT"
	)


func _test_valid_statuses() -> void:
	for kind in ModCapabilitiesScript.all_kinds():
		for platform in ModCapabilitiesScript.all_platforms():
			var result := ModCapabilitiesScript.describe(str(kind), str(platform))
			var status := str(result["status"])
			_expect(
				VALID_STATUSES.has(status),
				"status invalido '%s' para %s/%s" % [status, kind, platform]
			)


func _test_all_combinations() -> void:
	var kinds: Array = ModCapabilitiesScript.all_kinds()
	var platforms: Array = ModCapabilitiesScript.all_platforms()
	_expect(kinds.size() == 8, "all_kinds debe devolver 8 tipos")
	_expect(platforms.size() == 3, "all_platforms debe devolver 3 plataformas")

	var count := 0
	for kind in kinds:
		for platform in platforms:
			var result := ModCapabilitiesScript.describe(str(kind), str(platform))
			_expect(typeof(result) == TYPE_DICTIONARY, "describe debe devolver Dictionary")
			_expect(result.has("status"), "describe debe incluir status")
			_expect(result.has("flags"), "describe debe incluir flags")
			_expect(result.has("note"), "describe debe incluir note")
			_expect(typeof(result["flags"]) == TYPE_ARRAY, "flags debe ser Array")
			_expect(typeof(result["note"]) == TYPE_STRING, "note debe ser String")
			_expect(
				VALID_STATUSES.has(str(result["status"])),
				"status invalido '%s' para %s/%s" % [str(result["status"]), kind, platform]
			)
			count += 1

	_expect(count == kinds.size() * platforms.size(), "deben probarse todas las combinaciones")
