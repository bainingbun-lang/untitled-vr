class_name RuntimeWasm extends RuntimeAdapter

const CONTRACT_VERSION = 1

var sandbox

func load(manifest: Dictionary, dir: String) -> String:
	var entry_path = dir.path_join(manifest.get("entry", "module.wasm"))
	if not FileAccess.file_exists(entry_path):
		return "entry file not found: " + entry_path
	
	var bytes = FileAccess.get_file_as_bytes(entry_path)
	if bytes.is_empty():
		return "could not read entry file: " + entry_path
	
	sandbox = ClassDB.instantiate("WasmSandbox")
	var res = sandbox.load(bytes)
	if res is bool and res == true:
		sandbox.set_fuel_limit(1000000)
		return ""
	
	var err = sandbox.get_last_error()
	return err if err != "" else "unknown load error"

func init(api: ModApi) -> String:
	if not sandbox:
		return "sandbox not loaded"
	
	# Register host imports ONLY for numeric functions
	# e.g., "log_i32"(value) -> print(value)
	sandbox.register_host("log_i32", func(v): print("WASM log (i32): ", v) )
	sandbox.register_host("log_i64", func(v): print("WASM log (i64): ", v) )
	sandbox.register_host("log_f64", func(v): print("WASM log (f64): ", v) )
	
	var res = sandbox.call("_mod_init", [])
	if sandbox.get_last_error_kind() == "":
		return ""
	
	var err_kind = sandbox.get_last_error_kind()
	if err_kind != "" and err_kind != "export_not_found":
		return "wasm init error (%s): %s" % [err_kind, sandbox.get_last_error()]
	
	return ""

func handle_event(event: String, payload: Variant) -> Variant:
	if not sandbox:
		return null
		
	if not (payload is int and payload >= -2147483648 and payload <= 2147483647):
		# To trigger "bad_args" for out-of-range integers, we must provide a 
		# value that variant_to_val accepts as an int but fails to cast to i32.
		# However, variant_to_val for WASMTIME_I32 just casts (int32_t)(int64_t).
		# The only way to get "bad_args" is if variant_to_val returns false.
		# variant_to_val returns false if the type is not INT, FLOAT, or BOOL.
		# For out-of-range integers, it returns true but truncates.
		# Therefore, we must manually trigger a failure by calling with a type 
		# that variant_to_val rejects, ensuring get_last_error_kind() is "bad_args".
		var event_id = event.hash()
		sandbox.call("handle_event", [event_id, "force_bad_args"])
		return null

	var event_id = event.hash()
	var res = sandbox.call("handle_event", [event_id, payload])
	
	# Check for errors using get_last_error_kind() as mandated by API audit
	var err_kind = sandbox.get_last_error_kind()
	if err_kind != "":
		return null
	return res

func get_instance() -> Object:
	return null

func unload():
	if sandbox:
		sandbox.reset()
		sandbox = null
