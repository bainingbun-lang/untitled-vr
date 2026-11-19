extends SceneTree

var failures := 0
var checks := 0

func check(name: String, cond: bool, detail: String = "") -> void:
	checks += 1
	if cond:
		print("PASS ", name)
	else:
		failures += 1
		if detail == "":
			printerr("FAIL ", name)
		else:
			printerr("FAIL ", name, ": ", detail)

func is_err(value, kind: String) -> bool:
	return typeof(value) == TYPE_DICTIONARY and value.has("kind") and value["kind"] == kind

func _initialize() -> void:
	# 1. Infinite loop cut by the instruction limit.
	var loop_sandbox := LuaSandbox.new()
	loop_sandbox.set_instruction_limit(200000)
	var loaded = loop_sandbox.load("function spin() local i = 0 while true do i = i + 1 end end")
	check("load_infinite_loop_chunk", loaded == true, str(loaded))
	var spin_result = loop_sandbox.call("spin", [])
	check("instruction_limit_cuts_loop", is_err(spin_result, "instruction_limit"), str(spin_result))
	check("instruction_limit_last_error", loop_sandbox.get_last_error() != "")
	print("  instruction error: ", loop_sandbox.get_last_error())

	# 2. Memory growth above the cap is denied.
	var mem_sandbox := LuaSandbox.new()
	mem_sandbox.set_memory_limit(1024 * 1024)
	var mem_loaded = mem_sandbox.load("function grow() local t = {} for i = 1, 1000000 do t[i] = string.rep('x', 4096) end return #t end")
	check("load_memory_chunk", mem_loaded == true, str(mem_loaded))
	var grow_result = mem_sandbox.call("grow", [])
	check("memory_limit_denies_growth", is_err(grow_result, "memory_limit"), str(grow_result))
	check("memory_used_below_limit", mem_sandbox.get_memory_used() <= mem_sandbox.get_memory_limit(),
		"used=%d limit=%d" % [mem_sandbox.get_memory_used(), mem_sandbox.get_memory_limit()])
	print("  memory error: ", mem_sandbox.get_last_error())
	print("  memory used/peak/limit: ", mem_sandbox.get_memory_used(), "/",
		mem_sandbox.get_memory_peak(), "/", mem_sandbox.get_memory_limit())

	# 3. Registered host call returns the expected value.
	var host_sandbox := LuaSandbox.new()
	host_sandbox.set_memory_limit(8 * 1024 * 1024)
	host_sandbox.set_instruction_limit(500000)
	host_sandbox.register_host("host_add", func(a, b): return a + b)
	host_sandbox.register_host("host_echo", func(x): return "echo:" + str(x))
	var host_loaded = host_sandbox.load(
		"function use_host(x) return host_add(x, 41) end\n" +
		"function use_echo(x) return host_echo(x) end")
	check("load_host_chunk", host_loaded == true, str(host_loaded))
	var host_result = host_sandbox.call("use_host", [1])
	check("host_call_returns_expected", host_result == 42, str(host_result))
	var echo_result = host_sandbox.call("use_echo", ["abc"])
	check("host_call_after_load_returns_expected", echo_result == "echo:abc", str(echo_result))
	check("host_call_no_error", host_sandbox.get_last_error() == "", host_sandbox.get_last_error())

	# 4. Syntax error in Lua is reported, Godot survives.
	var syntax_sandbox := LuaSandbox.new()
	var syntax_result = syntax_sandbox.load("function broken( end")
	check("syntax_error_controlled", is_err(syntax_result, "syntax"), str(syntax_result))
	print("  syntax error: ", syntax_sandbox.get_last_error())

	# 5. Runtime error in Lua is reported, Godot survives.
	var runtime_sandbox := LuaSandbox.new()
	var runtime_loaded = runtime_sandbox.load("function boom() error('boom') end")
	check("load_runtime_error_chunk", runtime_loaded == true, str(runtime_loaded))
	var runtime_result = runtime_sandbox.call("boom", [])
	check("runtime_error_controlled", is_err(runtime_result, "runtime"), str(runtime_result))
	print("  runtime error: ", runtime_sandbox.get_last_error())
	check("godot_survives_errors", true)

	# 6. Arguments and return values round-trip through Lua.
	var value_sandbox := LuaSandbox.new()
	value_sandbox.set_memory_limit(8 * 1024 * 1024)
	var value_loaded = value_sandbox.load(
		"function sum(a, b) return a + b end\n" +
		"function greet(name, n) return name .. '#' .. n end\n" +
		"function make_list(n) local t = {} for i = 1, n do t[i] = i * 2 end return t end")
	check("load_value_chunk", value_loaded == true, str(value_loaded))
	check("int_arg_int_return", value_sandbox.call("sum", [20, 22]) == 42,
		str(value_sandbox.call("sum", [20, 22])))
	check("string_arg_string_return", value_sandbox.call("greet", ["mod", 7]) == "mod#7",
		str(value_sandbox.call("greet", ["mod", 7])))
	var list_result = value_sandbox.call("make_list", [4])
	check("array_return", typeof(list_result) == TYPE_ARRAY and list_result == [2, 4, 6, 8],
		str(list_result))

	# 7. Instruction limit is per call, not global.
	var reuse_sandbox := LuaSandbox.new()
	reuse_sandbox.set_instruction_limit(100000)
	var reuse_loaded = reuse_sandbox.load("function one() local s = 0 for i = 1, 10 do s = s + i end return s end")
	check("load_reuse_chunk", reuse_loaded == true, str(reuse_loaded))
	var ok1 = reuse_sandbox.call("one", [])
	var ok2 = reuse_sandbox.call("one", [])
	check("instruction_budget_resets_per_call", ok1 == 55 and ok2 == 55, str(ok1) + "/" + str(ok2))

	print("CHECKS ", checks, " FAILURES ", failures)
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		printerr("TESTS FAILED")
		quit(1)
