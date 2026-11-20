class_name RuntimeLua extends RuntimeAdapter

var sandbox

func load(manifest: Dictionary, dir: String) -> String:
	if not ClassDB.class_exists("LuaSandbox"):
		return "LuaSandbox extension not available"

	var entry_file = manifest.get("entry", "main.lua")
	var path = dir.path_join(entry_file)

	if not FileAccess.file_exists(path):
		return "entry file not found: " + path

	var source = FileAccess.get_file_as_string(path)

	sandbox = ClassDB.instantiate("LuaSandbox")
	var load_res = sandbox.load(source)
	if load_res is bool and load_res == true:
		return ""
	
	# The brief states: "The return of load() is true or an Error Dictionary; 
	# the adapter must check get_last_error_kind() and return the text."
	var err_kind = sandbox.get_last_error_kind()
	var err_msg = sandbox.get_last_error()
	
	# Ensure sandbox is cleaned up on failure
	sandbox.reset()
	sandbox = null
	
	if err_kind != "" or err_msg != "":
		return str(err_msg) if err_msg != "" else "Lua error: " + str(err_kind)
		
	return "unknown load error"

func init(api: ModApi) -> String:
	if not sandbox:
		return "sandbox not loaded"
	
	# The ModApi doesn't have a get_manifest() method. 
	# We use _permissions if available or check for a manifest passed in a custom way.
	# But the requirement says: "if the manifest does not declare permission 'emit', do not register emit"
	# Based on ModApi, the permissions are stored in _permissions.
	
	# Since _permissions is private, we should check how to access it or use ModApi's permissions.
	# We can check api._permissions directly in GDScript or add a getter to ModApi.
	# To avoid changing ModApi (unless necessary), we use api._permissions.
	
	var permissions = api._permissions
	
	if permissions.has("emit"):
		sandbox.register_host("emit", func(event: String, payload: Dictionary): api.emit(event, payload))
	
	if permissions.has("subscribe"):
		sandbox.register_host("subscribe", func(event: String, handler_name: String): 
			api.subscribe(event, func(payload): sandbox.call(handler_name, [payload]))
		)
	
	sandbox.call("_mod_init", [])
	if sandbox.get_last_error_kind() != "":
		return str(sandbox.get_last_error())
		
	return ""

func handle_event(event: String, payload: Variant) -> Variant:
	if not sandbox:
		return null
		
	var result = sandbox.call("handle_event", [event, payload])
	if sandbox.get_last_error_kind() != "":
		push_error("Lua handle_event error: " + str(sandbox.get_last_error()))
		return null
		
	return result

func get_instance() -> Object:
	return null

func unload():
	if sandbox:
		sandbox.reset()
		sandbox = null
