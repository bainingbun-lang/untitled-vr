extends SceneTree

func _initialize() -> void:
	var probe := Probe.new()
	var version := probe.get_version()
	print("Probe.get_version() = ", version)
	if version == "s1":
		print("PASS test_probe")
		quit(0)
	else:
		printerr("FAIL test_probe: unexpected version: ", version)
		quit(1)
