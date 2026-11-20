extends SceneTree

const ModLintScript = preload("res://core/mod_lint.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("USO: --headless --path <proyecto> --script res://tools/validate_mod.gd -- <ruta_del_mod>")
		print("La ruta debe comenzar con res:// o user://")
		quit(1)
		return

	var dir := str(args[0])
	var report: Dictionary = ModLintScript.check(dir)

	print("MOD: %s" % dir)
	if report["errors"].is_empty():
		print("ERRORES: ninguno")
	else:
		print("ERRORES:")
		for error in report["errors"]:
			print("  - %s" % error)
	if report["warnings"].is_empty():
		print("AVISOS: ninguno")
	else:
		print("AVISOS:")
		for warning in report["warnings"]:
			print("  - %s" % warning)

	if report["ok"]:
		print("VALIDATION_OK")
		quit(0)
	else:
		print("VALIDATION_FAIL")
		quit(1)
