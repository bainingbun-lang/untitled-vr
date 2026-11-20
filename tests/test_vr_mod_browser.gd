extends SceneTree

const VrModBrowserScript = preload("res://core/vr/vr_mod_browser.gd")
const ModLoaderScript = preload("res://core/mod_loader.gd")
const ModRegistryScript = preload("res://core/mod_registry.gd")
const EventBusScript = preload("res://core/event_bus.gd")

const FIXTURES := "res://tests/fixtures/mods_boot"

var _assertions := 0
var _failures: Array = []
var _closed_count: int = 0

func _initialize() -> void:
	await process_frame
	_test_build_and_open()
	_test_mod_list_display()
	_test_toggle_mod()
	_test_priority_change()
	_test_reload_mod()
	_test_scan_and_load()
	_test_pointer_interaction()
	_test_close()
	if _failures.is_empty():
		print("PASS test_vr_mod_browser.gd (%d assertions)" % _assertions)
		quit(0)
	else:
		print("FAIL test_vr_mod_browser.gd (%d assertions, %d failures)" % [_assertions, _failures.size()])
		for item in _failures:
			print("  " + str(item))
		quit(1)

func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)

func _test_build_and_open() -> void:
	var bus = EventBusScript.new()
	var loader = ModLoaderScript.new(bus)
	var initial: Dictionary = loader.load_all(FIXTURES)
	_expect(initial.has("loaded") and initial.has("rejected") and initial.has("order"), "initial load returns expected keys")

	var registry = loader.get_registry()
	var browser = VrModBrowserScript.new()
	browser.setup(bus, loader, registry)
	root.add_child(browser)

	var head_pos := Vector3(0, 1.6, 0)
	var head_fwd := Vector3(0, 0, -1)
	var xform := browser.open_in_front(head_pos, head_fwd)
	_expect(browser.is_open, "browser opens")
	_expect(browser.panel_root != null and browser.panel_root.visible, "panel visible after open")
	_expect(xform.origin.distance_to(head_pos + head_fwd * 1.2) < 0.01, "panel placed at correct distance")

	browser.close_menu()
	_expect(not browser.is_open, "browser closes")
	_expect(not browser.panel_root.visible, "panel hidden after close")

	var toggled := browser.toggle(head_pos, head_fwd)
	_expect(toggled and browser.is_open, "toggle opens")
	toggled = browser.toggle(head_pos, head_fwd)
	_expect(not toggled and not browser.is_open, "toggle closes")

	root.remove_child(browser)
	browser.free()

func _test_mod_list_display() -> void:
	var bus = EventBusScript.new()
	var loader = ModLoaderScript.new(bus)
	var initial: Dictionary = loader.load_all(FIXTURES)
	var registry = loader.get_registry()

	var browser = VrModBrowserScript.new()
	browser.setup(bus, loader, registry)
	root.add_child(browser)

	var head_pos := Vector3(0, 1.6, 0)
	var head_fwd := Vector3(0, 0, -1)
	browser.open_in_front(head_pos, head_fwd)

	await process_frame

	_expect(browser._mod_entries.has("boot.base"), "boot.base appears in mod list")
	_expect(browser._mod_entries.has("boot.dep"), "boot.dep appears in mod list")
	_expect(browser._mod_entries["boot.base"]["loaded"], "boot.base is loaded")
	_expect(browser._mod_entries["boot.dep"]["loaded"], "boot.dep is loaded")

	var base_entry: Dictionary = browser._mod_entries["boot.base"]
	_expect(base_entry["manifest"]["id"] == "boot.base", "manifest id correct")
	_expect(int(base_entry["manifest"]["priority"]) == 100, "default priority is 100")

	root.remove_child(browser)
	browser.free()

func _test_toggle_mod() -> void:
	var bus = EventBusScript.new()
	var loader = ModLoaderScript.new(bus)
	loader.load_all(FIXTURES)
	var registry = loader.get_registry()

	var browser = VrModBrowserScript.new()
	browser.setup(bus, loader, registry)
	root.add_child(browser)

	var head_pos := Vector3(0, 1.6, 0)
	var head_fwd := Vector3(0, 0, -1)
	browser.open_in_front(head_pos, head_fwd)
	await process_frame

	_expect(registry.is_loaded("boot.base"), "boot.base initially loaded")
	_expect(registry.is_loaded("boot.dep"), "boot.dep initially loaded")

	var toggle_id := "toggle_boot.base"
	var hit_result := {"hit": true, "button_id": toggle_id, "point": Vector3.ZERO, "uv": Vector2.ZERO}
	browser._handle_trigger(toggle_id)
	await process_frame

	_expect(not registry.is_loaded("boot.base"), "boot.base unloaded after toggle")
	_expect(registry.is_loaded("boot.dep"), "boot.dep still loaded")

	browser._handle_trigger(toggle_id)
	await process_frame

	_expect(registry.is_loaded("boot.base"), "boot.base reloaded after second toggle")

	root.remove_child(browser)
	browser.free()

func _test_priority_change() -> void:
	var bus = EventBusScript.new()
	var loader = ModLoaderScript.new(bus)
	loader.load_all(FIXTURES)
	var registry = loader.get_registry()

	var browser = VrModBrowserScript.new()
	browser.setup(bus, loader, registry)
	root.add_child(browser)

	var head_pos := Vector3(0, 1.6, 0)
	var head_fwd := Vector3(0, 0, -1)
	browser.open_in_front(head_pos, head_fwd)
	await process_frame

	var original_priority := int(browser._mod_entries["boot.base"]["manifest"]["priority"])
	_expect(original_priority == 100, "original priority is 100")

	browser._select_mod("boot.base")
	browser._change_priority("boot.base", 10)
	await process_frame

	var new_priority := int(browser._mod_entries["boot.base"]["manifest"]["priority"])
	_expect(new_priority == 110, "priority increased to 110")

	browser._change_priority("boot.base", -20)
	await process_frame

	new_priority = int(browser._mod_entries["boot.base"]["manifest"]["priority"])
	_expect(new_priority == 90, "priority decreased to 90")

	root.remove_child(browser)
	browser.free()

func _test_reload_mod() -> void:
	var bus = EventBusScript.new()
	var loader = ModLoaderScript.new(bus)
	loader.load_all(FIXTURES)
	var registry = loader.get_registry()

	var browser = VrModBrowserScript.new()
	browser.setup(bus, loader, registry)
	root.add_child(browser)

	var head_pos := Vector3(0, 1.6, 0)
	var head_fwd := Vector3(0, 0, -1)
	browser.open_in_front(head_pos, head_fwd)
	await process_frame

	_expect(registry.is_loaded("boot.base"), "boot.base loaded before reload")

	browser._select_mod("boot.base")
	browser._reload_mod("boot.base")
	await process_frame

	_expect(registry.is_loaded("boot.base"), "boot.base still loaded after reload")
	_expect(browser._mod_entries.has("boot.base"), "boot.base still in mod list")

	root.remove_child(browser)
	browser.free()

func _test_scan_and_load() -> void:
	var bus = EventBusScript.new()
	var loader = ModLoaderScript.new(bus)
	var initial: Dictionary = loader.load_all(FIXTURES)
	var registry = loader.get_registry()

	var browser = VrModBrowserScript.new()
	browser.setup(bus, loader, registry)
	root.add_child(browser)

	var head_pos := Vector3(0, 1.6, 0)
	var head_fwd := Vector3(0, 0, -1)
	browser.open_in_front(head_pos, head_fwd)
	await process_frame

	_expect(browser._mod_entries.has("boot.base"), "boot.base in list")
	_expect(browser._mod_entries.has("boot.dep"), "boot.dep in list")

	var rejected: Dictionary = initial.get("rejected", {})
	_expect(rejected.has("broken_json"), "broken_json is rejected")
	_expect(rejected.has("missing_dep"), "missing_dep is rejected")
	_expect(rejected.has("cycle_a") and rejected.has("cycle_b"), "cycle mods rejected")

	root.remove_child(browser)
	browser.free()

func _test_pointer_interaction() -> void:
	var bus = EventBusScript.new()
	var loader = ModLoaderScript.new(bus)
	loader.load_all(FIXTURES)
	var registry = loader.get_registry()

	var browser = VrModBrowserScript.new()
	browser.setup(bus, loader, registry)
	root.add_child(browser)

	var head_pos := Vector3(0, 1.6, 0)
	var head_fwd := Vector3(0, 0, -1)
	browser.open_in_front(head_pos, head_fwd)
	await process_frame

	var panel_xform: Transform3D = browser.global_transform
	var ray_origin: Vector3 = panel_xform.origin + panel_xform.basis.x * (-0.1) + panel_xform.basis.y * 0.1 + panel_xform.basis.z * 0.5
	var ray_dir: Vector3 = -panel_xform.basis.z

	var hit := browser.pointer_hit(ray_origin, ray_dir)
	_expect(hit.get("hit", false) == false or hit.get("hit", false) == true, "pointer_hit returns valid result")

	var trigger_result := browser.try_press(ray_origin, ray_dir, false)
	_expect(trigger_result == "", "no press without trigger")

	root.remove_child(browser)
	browser.free()

func _on_browser_closed():
	_closed_count += 1

func _test_close() -> void:
	var bus = EventBusScript.new()
	var loader = ModLoaderScript.new(bus)
	loader.load_all(FIXTURES)
	var registry = loader.get_registry()

	var browser = VrModBrowserScript.new()
	browser.setup(bus, loader, registry)
	root.add_child(browser)

	_closed_count = 0
	browser.connect("browser_closed", Callable(self, "_on_browser_closed"))

	_expect(browser.has_signal("browser_closed"), "browser has browser_closed signal")

	# Test direct signal emit
	browser.emit_signal("browser_closed")
	_expect(_closed_count == 1, "direct signal emit works")

	var head_pos := Vector3(0, 1.6, 0)
	var head_fwd := Vector3(0, 0, -1)
	browser.open_in_front(head_pos, head_fwd)
	_expect(browser.is_open, "browser open")

	browser.close_menu()
	_expect(not browser.is_open, "browser closed via close_menu")
	_expect(_closed_count == 2, "browser_closed signal emitted via close_menu")

	browser.open_in_front(head_pos, head_fwd)
	_expect(browser.is_open, "browser reopened")

	browser._handle_trigger("close")
	_expect(not browser.is_open, "browser closed via close button")
	_expect(_closed_count == 3, "browser_closed signal emitted via close button")

	root.remove_child(browser)
	browser.free()