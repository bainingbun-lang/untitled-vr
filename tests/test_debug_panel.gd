extends SceneTree

const DebugPanelScript = preload("res://core/game/debug_panel.gd")

var _panel: DebugPanel
var _checks: int = 0
var _passed: int = 0
var _failed: int = 0
var _case: String = ""
var _done: bool = false

func _init() -> void:
	_setup()

func _process(_delta: float) -> bool:
	if _done and _checks > 0 and _passed + _failed >= _checks:
		_print_summary()
		quit()
	return false

func _setup() -> void:
	_panel = DebugPanel.new()
	_register_default_commands()
	
	_test_command_parsing()
	_test_command_execution()
	_test_history()
	_test_help()
	_test_unknown_command()
	
	_done = true

func _register_default_commands() -> void:
	_panel.register_command("help", Callable(_panel, "help"), "Show available commands", "help")
	_panel.register_command("version", Callable(self, "_cmd_version"), "Show version info", "version")
	_panel.register_command("spawn", Callable(self, "_cmd_spawn"), "Spawn entity", "spawn <type> [name]")
	_panel.register_command("give", Callable(self, "_cmd_give"), "Give item to player", "give <item> [count]")
	_panel.register_command("timescale", Callable(self, "_cmd_timescale"), "Set game timescale", "timescale <value>")
	_panel.register_command("kill", Callable(self, "_cmd_kill"), "Kill entity", "kill <target>")
	_panel.register_command("tp", Callable(self, "_cmd_tp"), "Teleport", "tp <target> <position>")

func _cmd_version(args: Array) -> Dictionary:
	return {"ok": true, "output": "Debug Panel v1.0"}

func _cmd_spawn(args: Array) -> Dictionary:
	return {"ok": true, "output": "Spawned: " + str(args)}

func _cmd_give(args: Array) -> Dictionary:
	return {"ok": true, "output": "Gave: " + str(args)}

func _cmd_timescale(args: Array) -> Dictionary:
	if args.size() > 0:
		return {"ok": true, "output": "Timescale set to " + args[0]}
	return {"ok": false, "error": "usage: timescale <value>"}

func _cmd_kill(args: Array) -> Dictionary:
	return {"ok": true, "output": "Killed: " + str(args)}

func _cmd_tp(args: Array) -> Dictionary:
	return {"ok": true, "output": "Teleported: " + str(args)}

func _test_command_parsing() -> void:
	_case = "command parsing"
	
	var result = _panel.execute("help")
	_expect(result.ok == true, "help command ok")
	var help_output = str(result.result)
	_expect("Commands:" in help_output or "spawn" in help_output, "help shows commands list")
	
	result = _panel.execute("spawn npc zombie")
	_expect(result.ok == true, "spawn with args returns ok")
	
	result = _panel.execute('spawn "big enemy"')
	_expect(result.ok == true, "quoted args work")
	
	result = _panel.execute('give "assault rifle" 5')
	_expect(result.ok == true, "quoted multi-word with number")
	
	result = _panel.execute("timescale 2.5")
	_expect(result.ok == true, "timescale with float")

func _test_command_execution() -> void:
	_case = "command execution"
	
	var result = _panel.execute("help")
	_expect(result.ok == true, "help executes")
	
	result = _panel.execute("version")
	_expect(result.ok == true, "version executes")
	_expect("Debug Panel" in str(result.result), "version shows panel name")

func _test_history() -> void:
	_case = "command history"
	
	_panel.clear_history()
	_panel.execute("help")
	_panel.execute("version")
	_panel.execute("spawn npc")
	
	var history = _panel.get_history()
	_expect(history.size() == 3, "history has 3 entries")
	_expect(history[0] == "help", "history[0] = help")
	_expect(history[1] == "version", "history[1] = version")
	_expect(history[2] == "spawn npc", "history[2] = spawn npc")
	
	_panel.clear_history()
	_expect(_panel.get_history().is_empty(), "history cleared")

func _test_help() -> void:
	_case = "help command"
	
	var result = _panel.execute("help")
	_expect(result.ok == true, "help ok")
	var lines: Array = result.result
	_expect(lines.size() > 5, "help lists multiple commands")
	var help_str: String = str(lines)
	_expect("spawn" in help_str, "help lists spawn")
	_expect("kill" in help_str, "help lists kill")
	_expect("give" in help_str, "help lists give")
	_expect("tp" in help_str, "help lists tp")

func _test_unknown_command() -> void:
	_case = "unknown command"
	
	var result = _panel.execute("thiscommanddoesnotexist123")
	_expect(result.ok == false, "unknown command returns ok=false")
	var err_msg = str(result.get("error", ""))
	_expect("unknown" in err_msg.to_lower() or "desconocido" in err_msg.to_lower(), "shows unknown command error")

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		_passed += 1
		print("PASS: [", _case, "] ", message)
	else:
		_failed += 1
		print("FAIL: [", _case, "] ", message)

func _print_summary() -> void:
	print("\n=== Test Summary ===")
	print("Total: ", _checks)
	print("Passed: ", _passed)
	print("Failed: ", _failed)
	if _failed > 0:
		print("RESULT: FAIL")
	else:
		print("RESULT: PASS")