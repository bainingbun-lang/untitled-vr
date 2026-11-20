class_name TestUpdater
extends SceneTree

const UpdaterScript = preload("res://core/game/updater.gd")

var _updater: GameUpdater
var _test_results: Array = []

func _init() -> void:
	_updater = UpdaterScript.new()
	_run_tests()

func _run_tests() -> void:
	_test_version_compare()
	_test_version_equal()
	_test_version_newer()
	_test_version_with_v_prefix()
	_test_sha256_computation()
	_test_download_path()
	
	_print_results()
	# In a real test runner, we'd return exit code
	# For now just print results

func _test_version_compare() -> void:
	var tests = [
		["1.0.0", "1.0.0", true],
		["v1.0.0", "1.0.0", true],
		["1.0.0", "v1.0.0", true],
		["V1.0.0", "v1.0.0", true],
		["1.0.0", "2.0.0", false],
		["1.0.0", "1.0.1", false],
		["1.0.1", "1.0.0", false],
		["0.9.0", "1.0.0", false],
		["1.0.0-alpha", "1.0.0", false],
		["1.0.0", "1.0.0-alpha", false],
	]
	
	for t in tests:
		var a: String = t[0]
		var b: String = t[1]
		var expected: bool = t[2]
		var result: bool = _updater._version_equal(a, b)
		var passed: bool = (result == expected)
		_test_results.append({
			"test": "version_compare_%s_vs_%s" % [a, b],
			"passed": passed,
			"msg": "_version_equal('%s', '%s') = %s (expected %s)" % [a, b, result, expected]
		})

func _test_version_equal() -> void:
	# Same version should not trigger update
	_updater.set_current_version("1.0.0")
	var result: bool = _updater._version_equal("1.0.0", "1.0.0")
	_test_results.append({
		"test": "version_equal_same",
		"passed": result,
		"msg": "Same version strings should be equal"
	})

func _test_version_newer() -> void:
	# Different version should be detected
	_updater.set_current_version("0.9.0")
	var result: bool = _updater._version_equal("0.9.0", "1.0.0")
	_test_results.append({
		"test": "version_newer_detected",
		"passed": not result,
		"msg": "Different versions should not be equal: 0.9.0 vs 1.0.0"
	})

func _test_version_with_v_prefix() -> void:
	# v prefix should be stripped
	var result: bool = _updater._version_equal("v1.0.0", "1.0.0")
	_test_results.append({
		"test": "version_v_prefix_stripped",
		"passed": result,
		"msg": "v prefix should be stripped for comparison"
	})

func _test_sha256_computation() -> void:
	# Create a test file with known content
	var test_file: String = ProjectSettings.globalize_path("user://test_sha256.txt")
	var file: FileAccess = FileAccess.open(test_file, FileAccess.WRITE)
	if file != null:
		file.store_string("hello world")
		file.close()
	
	var sha256: String = _updater._compute_sha256(test_file)
	var expected: String = "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"
	var passed: bool = (sha256 == expected)
	
	_test_results.append({
		"test": "sha256_computation",
		"passed": passed,
		"msg": "SHA256 of 'hello world' = %s (expected %s)" % [sha256, expected]
	})
	
	# Cleanup
	var dir: DirAccess = DirAccess.open(ProjectSettings.globalize_path("user://"))
	if dir != null:
		dir.remove("test_sha256.txt")

func _test_download_path() -> void:
	var path: String = ProjectSettings.globalize_path("user://untitled_vr_update.apk")
	var expected_end: String = "user://untitled_vr_update.apk"
	# The path should contain the expected filename
	var passed: bool = path.ends_with("untitled_vr_update.apk")
	_test_results.append({
		"test": "download_path_format",
		"passed": passed,
		"msg": "Download path ends with expected filename: %s" % path
	})

func _print_results() -> void:
	var passed: int = 0
	var failed: int = 0
	for result in _test_results:
		if result.passed:
			print("PASS: %s - %s" % [result.test, result.msg])
			passed += 1
		else:
			printerr("FAIL: %s - %s" % [result.test, result.msg])
			failed += 1
	print("=== TestUpdater Results ===")
	print("PASS: %d, FAIL: %d" % [passed, failed])
	
	if failed > 0:
		quit(1)
	else:
		quit(0)