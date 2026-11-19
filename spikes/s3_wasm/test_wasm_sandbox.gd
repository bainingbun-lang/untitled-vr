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

func read_wasm(path: String) -> PackedByteArray:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		printerr("could not read ", path)
	return bytes

func _initialize() -> void:
	# 1. Infinite loop cut by the fuel limit.
	var loop_sandbox := WasmSandbox.new()
	loop_sandbox.set_fuel_limit(1000000)
	var loop_loaded = loop_sandbox.load(read_wasm("res://wasm/loop.wasm"))
	check("load_loop_module", loop_loaded == true, str(loop_loaded))
	var sum_result = loop_sandbox.call("run", [10])
	check("loop_module_returns_value", sum_result == 45, str(sum_result))
	var spin_result = loop_sandbox.call("spin", [])
	check("fuel_limit_cuts_loop", is_err(spin_result, "fuel_limit"), str(spin_result))
	check("fuel_limit_last_error", loop_sandbox.get_last_error() != "")
	check("fuel_limit_kind", loop_sandbox.get_last_error_kind() == "fuel_limit",
		loop_sandbox.get_last_error_kind())
	print("  fuel error: ", loop_sandbox.get_last_error())
	var after_fuel = loop_sandbox.call("run", [4])
	check("call_after_fuel_reset", after_fuel == 6, str(after_fuel))

	# 2. Memory growth above the cap is denied (memory.grow returns -1).
	var mem_sandbox := WasmSandbox.new()
	mem_sandbox.set_memory_limit(64 * 1024 * 1024)
	var mem_loaded = mem_sandbox.load(read_wasm("res://wasm/mem.wasm"))
	check("load_memory_module", mem_loaded == true, str(mem_loaded))
	check("memory_limit_reported", mem_sandbox.get_memory_limit() == 64 * 1024 * 1024,
		str(mem_sandbox.get_memory_limit()))
	var grow_result = mem_sandbox.call("run", [])
	check("memory_growth_denied", grow_result == -1, str(grow_result))
	check("memory_growth_no_error", mem_sandbox.get_last_error() == "", mem_sandbox.get_last_error())

	# 3. Registered host function is imported by Wasm and returns the expected value.
	var host_sandbox := WasmSandbox.new()
	host_sandbox.register_host("add", func(a, b): return a + b)
	var host_loaded = host_sandbox.load(read_wasm("res://wasm/host.wasm"))
	check("load_host_module", host_loaded == true, str(host_loaded))
	var host_result = host_sandbox.call("run", [])
	check("host_call_returns_expected", host_result == 42, str(host_result))
	check("host_call_no_error", host_sandbox.get_last_error() == "", host_sandbox.get_last_error())

	# 4. A Wasm trap is reported and the process keeps running.
	var trap_sandbox := WasmSandbox.new()
	var trap_loaded = trap_sandbox.load(read_wasm("res://wasm/trap.wasm"))
	check("load_trap_module", trap_loaded == true, str(trap_loaded))
	var divzero_result = trap_sandbox.call("divzero", [])
	check("trap_divzero_controlled", is_err(divzero_result, "trap"), str(divzero_result))
	check("trap_divzero_last_error", trap_sandbox.get_last_error() != "")
	print("  divzero trap: ", trap_sandbox.get_last_error())
	var ok_result = trap_sandbox.call("ok", [])
	check("call_after_trap_works", ok_result == 7, str(ok_result))
	var unreachable_result = trap_sandbox.call("unreachable", [])
	check("trap_unreachable_controlled", is_err(unreachable_result, "trap"), str(unreachable_result))
	print("  unreachable trap: ", trap_sandbox.get_last_error())

	# 5. Invalid binary is rejected without crashing.
	var bad_sandbox := WasmSandbox.new()
	var bad_result = bad_sandbox.load(PackedByteArray([0, 97, 115, 109, 1, 0, 0, 0, 255]))
	check("invalid_module_controlled", is_err(bad_result, "load"), str(bad_result))
	print("  load error: ", bad_sandbox.get_last_error())

	# 6. Calling without a module is an error, not a crash.
	var empty_sandbox := WasmSandbox.new()
	var empty_result = empty_sandbox.call("run", [])
	check("call_without_module_controlled", is_err(empty_result, "not_loaded"), str(empty_result))

	print("CHECKS ", checks, " FAILURES ", failures)
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("SOME FAILED")
		quit(1)
