extends SceneTree

const ModBackupScript = preload("res://core/mod_backup.gd")

const SRC := "user://test_mod_backup_src"
const BACKUPS := "user://test_mod_backup_root"
const DST := "user://test_mod_backup_dst"
const INTEGRITY := "user://test_mod_backup_integrity"

var _failures: Array = []
var _case := ""


func _init() -> void:
	_cleanup()

	_case = "snapshot recursivo con manifest"
	_test_snapshot()

	_case = "verify de snapshot intacto"
	var snapshot_id := _prepare_snapshot()
	_test_verify_ok(snapshot_id)

	_case = "restore reproduce contenido y crea pre-restore"
	_test_restore(snapshot_id)

	_case = "verify detecta archivo modificado"
	_test_modified(snapshot_id)

	_case = "restore de snapshot corrupto no restaura"
	_test_restore_corrupt(snapshot_id)

	_case = "delete exige confirm"
	_test_delete(snapshot_id)

	_case = "check_manifest detecta cambios"
	_test_check_manifest()

	_cleanup()

	if _failures.is_empty():
		print("TEST_OK")
		quit(0)
	else:
		print("TEST_FAIL: ", "; ".join(_failures))
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append("%s: %s" % [_case, message])


func _prepare_snapshot() -> String:
	_write(SRC.path_join("a.txt"), "alpha")
	_write(SRC.path_join("sub/b.txt"), "beta")
	var backup = ModBackupScript.new(BACKUPS)
	var result: Dictionary = backup.snapshot(SRC, "Base Snapshot")
	_expect(result["ok"], "snapshot inicial fallo: %s" % str(result["errors"]))
	_expect(result["files"] == 3, "se esperaban 3 archivos, se obtuvieron %d" % result["files"])
	return str(result["id"])


func _test_snapshot() -> void:
	_cleanup()
	_write(SRC.path_join("a.txt"), "alpha")
	_write(SRC.path_join("sub/b.txt"), "beta")
	var backup = ModBackupScript.new(BACKUPS)
	var result: Dictionary = backup.snapshot(SRC, "Base Snapshot")

	_expect(result["ok"], "snapshot debe ser ok: %s" % str(result["errors"]))
	_expect(result["files"] == 3, "files debe contar 2 archivos + manifest, fue %d" % result["files"])
	var id := str(result["id"])
	_expect(not id.is_empty(), "el id no debe estar vacio")
	_expect(id.begins_with("base-snapshot-"), "el id debe usar label sanitizado, fue '%s'" % id)

	var snapshot_dir := BACKUPS.path_join(id)
	var manifest_path := snapshot_dir.path_join("manifest.json")
	_expect(FileAccess.file_exists(manifest_path), "debe existir manifest.json")

	var manifest: Variant = _read_json(manifest_path)
	_expect(typeof(manifest) == TYPE_DICTIONARY, "manifest.json debe ser un objeto")
	if typeof(manifest) == TYPE_DICTIONARY:
		_expect(int(manifest.get("version", 0)) == 1, "manifest.version debe ser 1")
		var files: Variant = manifest.get("files", {})
		_expect(typeof(files) == TYPE_DICTIONARY, "manifest.files debe ser un objeto")
		if typeof(files) == TYPE_DICTIONARY:
			_expect(files.size() == 2, "manifest.files debe tener 2 entradas")
			_expect(files.has("a.txt"), "manifest debe incluir a.txt")
			_expect(files.has("sub/b.txt"), "manifest debe incluir sub/b.txt")
			_expect(
				str(files.get("a.txt", "")) == FileAccess.get_sha256(SRC.path_join("a.txt")),
				"el hash de a.txt debe coincidir"
			)

	_expect(_read(snapshot_dir.path_join("a.txt")) == "alpha", "snapshot debe copiar a.txt")
	_expect(_read(snapshot_dir.path_join("sub/b.txt")) == "beta", "snapshot debe copiar sub/b.txt")


func _test_verify_ok(id: String) -> void:
	var backup = ModBackupScript.new(BACKUPS)
	var result: Dictionary = backup.verify(id)
	_expect(result["ok"], "verify debe ser ok en snapshot intacto")
	_expect((result["mismatched"] as Array).is_empty(), "mismatched debe estar vacio")
	_expect((result["missing"] as Array).is_empty(), "missing debe estar vacio")
	_expect((result["extra"] as Array).is_empty(), "extra debe estar vacio")


func _test_restore(id: String) -> void:
	var backup = ModBackupScript.new(BACKUPS)
	_write(DST.path_join("viejo.txt"), "previo")

	var result: Dictionary = backup.restore(id, DST)
	_expect(result["ok"], "restore debe ser ok: %s" % str(result["errors"]))
	_expect(_read(DST.path_join("a.txt")) == "alpha", "restore debe copiar a.txt")
	_expect(_read(DST.path_join("sub/b.txt")) == "beta", "restore debe copiar sub/b.txt")

	var pre_restore_id := str(result["pre_restore_id"])
	_expect(not pre_restore_id.is_empty(), "restore debe crear pre-restore")
	_expect(pre_restore_id.begins_with("pre-restore-"), "pre-restore debe llevar su label")
	var pre_dir := BACKUPS.path_join(pre_restore_id)
	_expect(FileAccess.file_exists(pre_dir.path_join("manifest.json")), "pre-restore debe tener manifest")
	_expect(_read(pre_dir.path_join("viejo.txt")) == "previo", "pre-restore debe conservar viejo.txt")


func _test_modified(id: String) -> void:
	_write(BACKUPS.path_join(id).path_join("a.txt"), "alterado")
	var backup = ModBackupScript.new(BACKUPS)
	var result: Dictionary = backup.verify(id)
	_expect(not result["ok"], "verify debe fallar con archivo alterado")
	_expect((result["mismatched"] as Array).has("a.txt"), "mismatched debe incluir a.txt")
	_expect((result["missing"] as Array).is_empty(), "no debe haber faltantes")
	_expect((result["extra"] as Array).is_empty(), "no debe haber extras")


func _test_restore_corrupt(id: String) -> void:
	var backup = ModBackupScript.new(BACKUPS)
	var result: Dictionary = backup.restore(id, DST)
	_expect(not result["ok"], "restore debe fallar si el snapshot no verifica")
	_expect(_read(DST.path_join("a.txt")) == "alpha", "no debe sobrescribir el destino")
	_expect((result["pre_restore_id"] as String).is_empty(), "no debe crear pre-restore si aborta")


func _test_delete(id: String) -> void:
	var backup = ModBackupScript.new(BACKUPS)
	var snapshot_dir := BACKUPS.path_join(id)

	var refused: Dictionary = backup.delete(id, false)
	_expect(not refused["ok"], "delete sin confirm debe fallar")
	_expect(
		(refused["errors"] as Array).has("borrado requiere confirm=true"),
		"delete sin confirm debe explicar el motivo"
	)
	_expect(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(snapshot_dir)), "no debe borrar sin confirm")

	var accepted: Dictionary = backup.delete(id, true)
	_expect(accepted["ok"], "delete con confirm debe funcionar")
	_expect(
		not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(snapshot_dir)),
		"delete con confirm debe borrar el snapshot"
	)


func _test_check_manifest() -> void:
	_write(INTEGRITY.path_join("uno.txt"), "1")
	_write(INTEGRITY.path_join("sub/dos.txt"), "2")
	_write(INTEGRITY.path_join("manifest.json"), "{}")

	var manifest := ModBackupScript.make_manifest(INTEGRITY)
	_expect(manifest.size() == 2, "make_manifest debe excluir manifest.json")
	_expect(manifest.has("uno.txt"), "manifest debe incluir uno.txt")
	_expect(manifest.has("sub/dos.txt"), "manifest debe incluir sub/dos.txt")

	_write(INTEGRITY.path_join("uno.txt"), "cambiado")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(INTEGRITY.path_join("sub/dos.txt")))
	_write(INTEGRITY.path_join("extra.txt"), "3")

	var result := ModBackupScript.check_manifest(INTEGRITY, manifest)
	_expect(not result["ok"], "check_manifest debe fallar con cambios")
	_expect((result["mismatched"] as Array).has("uno.txt"), "mismatched debe incluir uno.txt")
	_expect((result["missing"] as Array).has("sub/dos.txt"), "missing debe incluir sub/dos.txt")
	_expect((result["extra"] as Array).has("extra.txt"), "extra debe incluir extra.txt")


func _cleanup() -> void:
	_remove_dir(SRC)
	_remove_dir(BACKUPS)
	_remove_dir(DST)
	_remove_dir(INTEGRITY)


func _write(path: String, content: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_expect(false, "no se pudo escribir '%s'" % path)
		return
	file.store_string(content)
	file.close()


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


func _remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var full := path.path_join(name)
		if dir.current_is_dir():
			_remove_dir(full)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(full))
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
