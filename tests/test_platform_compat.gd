extends SceneTree

const CORE_ROOT := "res://core"
const TESTS_ROOT := "res://tests"
const SELF_FILE := "res://tests/test_platform_compat.gd"

class PlatformCompatChecker extends RefCounted:
	var scanned_files: Array = []
	var findings: Array = []
	var _case_seen: Dictionary = {}

	func _piece(parts: Array) -> String:
		var out := ""
		for part in parts:
			out += str(part)
		return out

	func _needles() -> Dictionary:
		return {
			"abs": [
				_piece(["/", "sdcard"]),
				_piece(["/", "data", "/", "data", "/"]),
				_piece(["/", "home", "/"]),
				_piece(["/", "usr", "/"]),
				_piece(["/", "tmp", "/"]),
				_piece(["/", "mnt", "/"]),
				_piece(["/", "etc", "/"]),
				_piece(["/", "root", "/"]),
				_piece(["/", "storage", "/", "emulated"]),
				_piece(["/", "proc", "/"]),
				_piece(["/", "sys", "/"]),
			],
			"proc": [
				_piece(["OS", ".", "execute"]),
				_piece(["OS", ".", "shell_open"]),
				_piece(["OS", ".", "create_process"]),
			],
			"cdb_inst": [_piece(["ClassDB", ".", "instantiate"])],
			"cdb_guard": [_piece(["ClassDB", ".", "class_exists"])],
			"so": [_piece([".", "so"])],
			"fallback": ["fallback", "has_method", "has_feature", "class_exists"],
		}

	func analyze(roots: Array) -> Array:
		scanned_files = []
		findings = []
		_case_seen = {}
		var queue: Array = roots.duplicate()
		while not queue.is_empty():
			var dir_path := str(queue.pop_front())
			var dir := DirAccess.open(dir_path)
			if dir == null:
				continue
			for file_name in dir.get_files():
				if not str(file_name).ends_with(".gd"):
					continue
				var file_path := dir_path.path_join(str(file_name))
				scanned_files.append(file_path)
				_scan_file(file_path)
			for dir_name in dir.get_directories():
				var child := str(dir_name)
				if child == "." or child == "..":
					continue
				queue.append(dir_path.path_join(child))
		return findings

	func _scan_file(file_path: String) -> void:
		var content := FileAccess.get_file_as_string(file_path)
		var file := FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			return
		var line_no := 0
		while not file.eof_reached():
			var line := file.get_line()
			line_no += 1
			_check_line(file_path, line_no, line, content)
		file.close()

	func _add(severity: String, code: String, file: String, line: int, message: String) -> void:
		findings.append({
			"file": file,
			"line": line,
			"severity": severity,
			"code": code,
			"message": message,
		})

	func _has_path_backslash(line: String) -> bool:
		var tail := line.length() - 1
		while tail >= 0 and (line.unicode_at(tail) == 32 or line.unicode_at(tail) == 9):
			tail -= 1
		if tail >= 0 and line.unicode_at(tail) == 92:
			return false
		if line.contains("contains(") or line.contains("replace(") or line.contains("_PATTERN"):
			return false
		for i in range(line.length() - 1):
			if line.unicode_at(i) != 92:
				continue
			var next_code := line.unicode_at(i + 1)
			if next_code in [116, 110, 114, 34, 39, 92, 115, 100]:
				continue
			return true
		return false

	func _contains_so(value: String, needle: String) -> bool:
		var from := 0
		while from < value.length():
			var i := value.find(needle, from)
			if i < 0:
				return false
			var end := i + needle.length()
			if end >= value.length():
				return true
			var c := value.unicode_at(end)
			var word_char := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) \
				or (c >= 97 and c <= 122) or c == 95
			if not word_char:
				return true
			from = end
		return false

	func _extract_paths(line: String) -> Array:
		var out: Array = []
		for prefix in ["res://", "user://"]:
			var head := str(prefix)
			var from := 0
			while from < line.length():
				var i := line.find(head, from)
				if i < 0:
					break
				var j := i + head.length()
				while j < line.length():
					var c := line.unicode_at(j)
					if c == 34 or c == 39 or c == 32 or c == 9 or c == 44:
						break
					j += 1
				if j > i + head.length():
					out.append(line.substr(i, j - i))
				from = j + 1
		return out

	func _check_line(file: String, line_no: int, line: String, content: String) -> void:
		var needles := _needles()
		for needle in needles["abs"]:
			if line.contains(str(needle)):
				_add("GRAVE", "RUTA_ABSOLUTA", file, line_no,
					"ruta absoluta de Linux/Android; solo se permiten res:// y user://")
				break
		for needle in needles["proc"]:
			if line.contains(str(needle)):
				_add("GRAVE", "PROCESO_EXTERNO", file, line_no,
					"llamada a proceso externo; no disponible en Android/VR")
				break
		for needle in needles["cdb_inst"]:
			if line.contains(str(needle)):
				var guarded := false
				for guard in needles["cdb_guard"]:
					if content.contains(str(guard)):
						guarded = true
				if not guarded:
					_add("GRAVE", "CLASSDB_SIN_GUARDA", file, line_no,
						"instanciacion dinamica de extension sin guarda de existencia")
				break
		for needle in needles["so"]:
			if _contains_so(line, str(needle)):
				var fallback := false
				for token in needles["fallback"]:
					if content.contains(str(token)):
						fallback = true
				if not fallback:
					_add("GRAVE", "SO_SIN_FALLBACK", file, line_no,
						"dependencia nativa sin alternativa")
				break
		if _has_path_backslash(line):
			_add("ADVISORY", "BACKSLASH", file, line_no,
				"posible separador backslash en una ruta; no portable a Android")
		for path in _extract_paths(line):
			var key := str(path).to_lower()
			if _case_seen.has(key) and str(_case_seen[key]) != str(path):
				_add("ADVISORY", "CASO_INCONSISTENTE", file, line_no,
					"misma ruta con distinta capitalizacion: %s / %s" % [str(_case_seen[key]), str(path)])
			else:
				_case_seen[key] = str(path)

var _checks := 0
var _failures: Array = []


func _init() -> void:
	var checker := PlatformCompatChecker.new()

	_expect(_has_code(_probe(_join(["x = ", "/", "data", "/", "data", "/", "x"])), "RUTA_ABSOLUTA"), \
		"el detector de rutas absolutas debe dispararse")
	_expect(not _has_code(_probe(_join(["x = ", "res", "://", "core", "/", "a.gd"])), "RUTA_ABSOLUTA"), \
		"res:// no debe considerarse ruta absoluta")
	_expect(_has_code(_probe(_join(["x = ", "OS", ".", "execute", "()"])), "PROCESO_EXTERNO"), \
		"el detector de procesos externos debe dispararse")
	_expect(not _has_code(_probe("var x = 1"), "PROCESO_EXTERNO"), \
		"el codigo limpio no debe disparar proceso externo")
	_expect(_has_code(_probe(_join(["x = ", "ClassDB", ".", "instantiate", "()"]), ""), "CLASSDB_SIN_GUARDA"), \
		"el detector de ClassDB sin guarda debe dispararse")
	_expect(not _has_code(_probe(_join(["x = ", "ClassDB", ".", "instantiate", "()"]), \
		_join(["ClassDB", ".", "class_exists"])), "CLASSDB_SIN_GUARDA"), \
		"la guarda class_exists debe evitar el hallazgo")
	_expect(_has_code(_probe(_join(["ruta", char(92), "archivo.pck"])), "BACKSLASH"), \
		"el detector de backslash debe dispararse")
	_expect(not _has_code(_probe(_join(["x = ", char(9)])), "BACKSLASH"), \
		"un tabulador no es un separador de ruta")
	_expect(_has_code(_probe(_join(["x = ", "lib", ".", "so"]), ""), "SO_SIN_FALLBACK"), \
		"el detector de dependencia nativa debe dispararse")
	_expect(not _has_code(_probe(_join(["x = ", "lib", ".", "so"]), "fallback"), "SO_SIN_FALLBACK"), \
		"un fallback debe evitar el hallazgo de dependencia nativa")

	var case_checker := PlatformCompatChecker.new()
	case_checker._check_line("prueba", 1, _join(["x = ", "res", "://", "Core", "/", "a.gd"]), "")
	case_checker._check_line("prueba", 2, _join(["x = ", "res", "://", "core", "/", "a.gd"]), "")
	_expect(_has_code(case_checker.findings, "CASO_INCONSISTENTE"), \
		"debe detectar la misma ruta con distinta capitalizacion")

	checker.analyze([CORE_ROOT, TESTS_ROOT])
	_expect(checker.scanned_files.size() > 0, "debe escanear archivos .gd de core/ y tests/")
	_expect(checker.scanned_files.has("res://core/boot.gd"), "debe escanear core/boot.gd")
	_expect(checker.scanned_files.has("res://tests/test_boot.gd"), "debe escanear tests/test_boot.gd")
	var scope_ok := true
	for path in checker.scanned_files:
		if not (str(path).begins_with("res://core/") or str(path).begins_with("res://tests/")):
			scope_ok = false
	_expect(scope_ok, "el analisis debe cubrir solo core/ y tests/")
	_expect(checker.findings.size() > 0, "el analisis debe reportar los hallazgos presentes en el codigo")

	_expect(_finding_exists(checker.findings, "res://core/runtime_lua.gd", "CLASSDB_SIN_GUARDA"), \
		"debe hallar ClassDB sin guarda en core/runtime_lua.gd")
	_expect(_finding_exists(checker.findings, "res://core/runtime_wasm.gd", "CLASSDB_SIN_GUARDA"), \
		"debe hallar ClassDB sin guarda en core/runtime_wasm.gd")
	_expect(_finding_exists(checker.findings, "res://tests/test_example_mod.gd", "PROCESO_EXTERNO"), \
		"debe hallar proceso externo en tests/test_example_mod.gd")
	_expect(_finding_exists(checker.findings, "res://tests/test_runtime_lua.gd", "RUTA_ABSOLUTA"), \
		"debe hallar ruta absoluta en tests/test_runtime_lua.gd")
	_expect(_finding_exists(checker.findings, "res://tests/test_runtime_wasm.gd", "RUTA_ABSOLUTA"), \
		"debe hallar ruta absoluta en tests/test_runtime_wasm.gd")
	_expect(_finding_exists(checker.findings, "res://tests/test_mod_manifest.gd", "BACKSLASH"), \
		"debe hallar el literal con backslash en tests/test_mod_manifest.gd")
	_expect(not _finding_exists(checker.findings, SELF_FILE, ""), \
		"el analizador no debe auto-flagarse al escanear tests/")

	var format_ok := true
	for finding in checker.findings:
		if not str(finding["file"]).begins_with("res://"):
			format_ok = false
		if int(finding["line"]) < 1:
			format_ok = false
		if not ["GRAVE", "ADVISORY"].has(str(finding["severity"])):
			format_ok = false
	_expect(format_ok, "todos los hallazgos deben tener archivo:linea y severidad valida")

	for finding in checker.findings:
		print("%s:%d: %s [%s] %s" % [
			finding["file"], finding["line"], finding["severity"], finding["code"], finding["message"],
		])

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _join(parts: Array) -> String:
	var out := ""
	for part in parts:
		out += str(part)
	return out


func _probe(line: String, content: String = "") -> Array:
	var probe_checker := PlatformCompatChecker.new()
	probe_checker._check_line("prueba", 1, line, content)
	return probe_checker.findings


func _has_code(findings: Array, code: String) -> bool:
	for finding in findings:
		if str(finding["code"]) == code:
			return true
	return false


func _finding_exists(findings: Array, file: String, code: String) -> bool:
	for finding in findings:
		if str(finding["file"]) == file and (code.is_empty() or str(finding["code"]) == code):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
