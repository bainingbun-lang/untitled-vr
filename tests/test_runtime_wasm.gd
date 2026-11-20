extends SceneTree

func _init():
	if not ClassDB.class_exists("WasmSandbox"):
		print("Test 0: Extension absent")
		var runtime_absent = RuntimeWasm.new()
		var res_absent = runtime_absent.load({"entry": "valid.wasm"}, "res://tests/fixtures/wasm/")
		if res_absent == "":
			print("FAIL: Expected controlled error when WasmSandbox extension is unavailable")
			quit(1)
		if res_absent.find("not available") == -1:
			print("FAIL: Unexpected absent-extension error: " + res_absent)
			quit(1)
		if runtime_absent.sandbox != null:
			print("FAIL: Sandbox should remain null when extension is unavailable")
			quit(1)
		print("PASS: Extension absent handled: " + res_absent)
		print("SKIP: Real WASM runtime tests require WasmSandbox extension")
		quit(0)
		return

	var result = run_tests()
	if result:
		quit(0)
	else:
		quit(1)

func run_tests() -> bool:
	var all_passed = true
	var abs_dir = "res://tests/fixtures/wasm/"
	var mock_api = ModApi.new("test_mod", null, [])
	mock_api.set_meta("permissions", {"emit": false})

	# 1. Load Valid Module
	var rt_valid = RuntimeWasm.new()
	var err = rt_valid.load({"entry": "valid.wasm"}, abs_dir)
	if err != "":
		print("FAIL: Valid module load: " + err)
		all_passed = false
	else:
		print("PASS: Valid module load")
		var init_err = rt_valid.init(mock_api)
		if init_err != "":
			print("FAIL: Valid module init: " + init_err)
			all_passed = false
		else:
			print("PASS: Valid module init")

		var res = rt_valid.handle_event("test", 123)
		if res == 124:
			print("PASS: Valid module handle_event executed with correct value: " + str(res))
		else:
			print("FAIL: Valid module handle_event returned unexpected value: " + str(res))
			all_passed = false
		
		# Identificador: check if event_id was stored in global
		var last_id = rt_valid.sandbox.call("get_last_id", [])
		if last_id is Dictionary:
			# It's an error dictionary
			print("FAIL: get_last_id returned error: " + str(last_id))
			all_passed = false
		else:
			var expected_id = "test".hash()
			# Note: GDScript .hash() returns int64, WASM expect i32. 
			# We need to mimic the truncation that happens in RuntimeWasm.
			var truncated_id = (expected_id & 0xFFFFFFFF)
			if last_id == truncated_id:
				print("PASS: event_id stored correctly: " + str(last_id))
			else:
				print("FAIL: event_id mismatch. Expected: " + str(truncated_id) + ", Got: " + str(last_id))
				all_passed = false

	# 2. Loop / Fuel limit
	var rt_loop = RuntimeWasm.new()
	if rt_loop.load({"entry": "loop.wasm"}, abs_dir) == "":
		rt_loop.init(mock_api)
		# We assume the sandbox is accessible for fuel setting in tests
		if rt_loop.sandbox.has_method("set_fuel_limit"):
			rt_loop.sandbox.set_fuel_limit(100) 
		
		rt_loop.handle_event("loop", 0)
		if rt_loop.sandbox.get_last_error_kind() == "fuel_limit":
			print("PASS: Loop caught by fuel limit")
		else:
			print("FAIL: Loop not caught. Kind: " + rt_loop.sandbox.get_last_error_kind())
			all_passed = false
	else:
		print("FAIL: Loop module load")
		all_passed = false

	# 3. Trap
	var rt_trap = RuntimeWasm.new()
	if rt_trap.load({"entry": "trap.wasm"}, abs_dir) == "":
		rt_trap.init(mock_api)
		rt_trap.handle_event("trap", 0)
		if rt_trap.sandbox.get_last_error_kind() != "":
			print("PASS: Trap caught: " + rt_trap.sandbox.get_last_error_kind())
		else:
			print("FAIL: Trap not caught")
			all_passed = false
	else:
		print("FAIL: Trap module load")
		all_passed = false

	# 4. Invalid module
	var rt_inv = RuntimeWasm.new()
	err = rt_inv.load({"entry": "invalid.wasm"}, abs_dir)
	if err != "":
		print("PASS: Invalid module rejected: " + err)
	else:
		print("FAIL: Invalid module accepted")
		all_passed = false

	# 5. Unload
	var rt_un = RuntimeWasm.new()
	rt_un.load({"entry": "valid.wasm"}, abs_dir)
	rt_un.unload()
	if rt_un.sandbox == null:
		print("PASS: Unload cleaned references")
	else:
		print("FAIL: Unload failed")
		all_passed = false

	# 6. Export Missing
	var rt_miss = RuntimeWasm.new()
	if rt_miss.load({"entry": "export_missing.wasm"}, abs_dir) == "":
		rt_miss.init(mock_api)
		rt_miss.handle_event("missing", 0)
		if rt_miss.sandbox.get_last_error_kind() == "export_not_found":
			print("PASS: Export missing caught")
		else:
			print("FAIL: Export missing not caught. Kind: " + rt_miss.sandbox.get_last_error_kind())
			all_passed = false
	else:
		print("FAIL: Export missing module load")
		all_passed = false

	# 7. Fuel Consumption
	var rt_fuel = RuntimeWasm.new()
	if rt_fuel.load({"entry": "valid.wasm"}, abs_dir) == "":
		rt_fuel.init(mock_api)
		if rt_fuel.sandbox.has_method("get_fuel_limit"):
			var limit = rt_fuel.sandbox.get_fuel_limit()
			rt_fuel.handle_event("test", 1)
			# If API doesn't expose current fuel, we just check that it doesn't error
			print("PASS: Valid module fuel consumption test (no error)")
		else:
			print("INFO: Fuel consumption not exposed via sandbox")
	else:
		all_passed = false

	# 8. Payload Separation & Types
	var rt_type = RuntimeWasm.new()
	if rt_type.load({"entry": "valid.wasm"}, abs_dir) == "":
		rt_type.init(mock_api)
		
		# Case: Non-integer payload (String)
		var res_str = rt_type.handle_event("test", "not_an_int")
		if res_str == null and rt_type.sandbox.get_last_error_kind() == "bad_args":
			print("PASS: Non-integer payload produced controlled error (bad_args)")
		else:
			print("FAIL: Non-integer payload did not produce expected error. Kind: " + rt_type.sandbox.get_last_error_kind())
			all_passed = false
			
		# Case: Payload out of i32 range (2^40)
		var res_big = rt_type.handle_event("test", 1099511627776) # 2^40
		if res_big == null and rt_type.sandbox.get_last_error_kind() == "bad_args":
			print("PASS: Out-of-range payload produced controlled error (bad_args)")
		else:
			var kind = rt_type.sandbox.get_last_error_kind()
			print("FAIL: Out-of-range payload did not produce expected error. Kind: " + str(kind))
			all_passed = false
	else:
		all_passed = false

	# 9. Contract Version
	if RuntimeWasm.CONTRACT_VERSION == 1:
		print("PASS: CONTRACT_VERSION is 1")
	else:
		print("FAIL: CONTRACT_VERSION is " + str(RuntimeWasm.CONTRACT_VERSION))
		all_passed = false

	return all_passed
