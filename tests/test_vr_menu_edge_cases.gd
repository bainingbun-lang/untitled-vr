extends SceneTree

const MenuScript = preload("res://core/vr/vr_menu.gd")

var _n := 0
var _fail := 0

func _expect(c: bool, m: String) -> void:
	_n += 1
	if not c:
		_fail += 1
		print("FAIL: " + m)

func _initialize() -> void:
	await process_frame

	# --- VrMenu Edge Cases ---

	# Test 1: build idempotent
	var menu = MenuScript.new()
	root.add_child(menu)
	_expect(menu.build(), "first build returns true")
	_expect(menu.build(), "second build returns true (idempotent)")

	# Test 2: open/close toggles is_open
	menu.close_menu()
	_expect(not menu.is_open, "close_menu sets is_open false")
	menu.open_in_front(Vector3.ZERO, Vector3.FORWARD)
	_expect(menu.is_open, "open_in_front sets is_open true")
	menu.close_menu()
	_expect(not menu.is_open, "close_menu again sets is_open false")

	# Test 3: toggle flips state
	_expect(not menu.is_open, "starts closed")
	_expect(menu.toggle(Vector3.ZERO, Vector3.FORWARD), "toggle returns true when opening")
	_expect(menu.is_open, "is_open true after toggle")
	_expect(not menu.toggle(Vector3.ZERO, Vector3.FORWARD), "toggle returns false when closing")
	_expect(not menu.is_open, "is_open false after second toggle")

	# Test 4: set_buttons normalizes and filters invalid
	menu.set_buttons([
		{"id": "valid1", "label": "Valid 1", "rect": Rect2(-0.1, -0.05, 0.2, 0.1)},
		{"id": "", "label": "No ID", "rect": Rect2(-0.1, 0.05, 0.2, 0.1)},
		{"id": "valid2", "label": "Valid 2", "rect": "not a rect"},
		{"not_a_dict": true},
	])
	_expect(menu.buttons.size() == 1, "set_buttons keeps only valid entries (valid rect required)")
	_expect(menu.buttons[0]["id"] == "valid1", "first button id preserved")

	# Test 5: pointer_hit returns false when closed
	menu.close_menu()
	var hit = menu.pointer_hit(Vector3.ZERO, Vector3.FORWARD)
	_expect(not hit["hit"], "pointer_hit returns no hit when closed")

	# Test 6: pointer_hit finds button within bounds
	# Panel placed at z=-1.4 (forward is -Z), facing +Z (toward player)
	# Ray from behind panel (z=-2) going toward panel (direction +Z)
	menu.open_in_front(Vector3.ZERO, Vector3.FORWARD)
	# Button rect centered at (0,0) in panel local coords: x[-0.05,0.05], y[-0.025,0.025]
	# Panel origin y = -0.05, so ray at y=0 hits local y = 0.05 (outside button)
	# Use ray at y=-0.05 to hit local y = 0
	menu.set_buttons([{"id": "center", "label": "Center", "rect": Rect2(-0.05, -0.025, 0.1, 0.05)}])
	hit = menu.pointer_hit(Vector3(0, -0.05, -2), Vector3(0, 0, 1))  # from behind, toward panel
	_expect(hit["hit"], "pointer_hit finds button at center")
	_expect(hit["button_id"] == "center", "pointer_hit returns correct button_id")

	# Test 7: pointer_hit misses outside panel
	hit = menu.pointer_hit(Vector3(10, 0, -2), Vector3(0, 0, 1))
	_expect(not hit["hit"], "pointer_hit misses far off panel")

	# Test 8: raycast_buttons handles zero direction
	hit = MenuScript.raycast_buttons(Vector3.ZERO, Vector3.ZERO, Transform3D.IDENTITY, Vector2(0.6, 0.35), [])
	_expect(not hit["hit"], "raycast_buttons zero direction returns no hit")

	# Test 9: raycast_buttons parallel ray (no intersection)
	var panel_xform = Transform3D(Basis.IDENTITY, Vector3(0, 0, 1))
	hit = MenuScript.raycast_buttons(Vector3(0, 0, 0), Vector3(1, 0, 0), panel_xform, Vector2(0.6, 0.35), [])
	_expect(not hit["hit"], "raycast_buttons parallel ray returns no hit")

	# Test 10: raycast_buttons hits panel center with valid button
	# Panel at z=1, facing +Z (basis.z = 0,0,1). Ray from origin toward +Z.
	# Button rect centered at (0,0): x[-0.05,0.05], y[-0.025,0.025]
	panel_xform = Transform3D(Basis.IDENTITY, Vector3(0, 0, 1))
	hit = MenuScript.raycast_buttons(Vector3(0, 0, 0), Vector3(0, 0, 1), panel_xform, Vector2(0.6, 0.35), [
		{"id": "center", "label": "Center", "rect": Rect2(-0.05, -0.025, 0.1, 0.05)}
	])
	_expect(hit["hit"], "raycast_buttons hits panel center with valid button")
	_expect(hit["button_id"] == "center", "raycast_buttons returns correct button_id")

	# Test 11: placement_transform clamps negative distance to minimum 0.2
	# forward = FORWARD (0,0,-1), distance = -1.0 -> clamped to 0.2
	# origin = ZERO + (0,0,-1)*0.2 + UP*(-0.05) = (0, -0.05, -0.2)
	var xform = MenuScript.placement_transform(Vector3.ZERO, Vector3.FORWARD, -1.0, -0.05)
	_expect(abs(xform.origin.z - (-0.2)) < 0.01, "placement_transform clamps negative distance to 0.2 (z = -0.2)")
	_expect(abs(xform.origin.y - (-0.05)) < 0.01, "placement_transform applies height offset")

	# Test 12: placement_transform applies distance in forward direction
	# forward = FORWARD (0,0,-1), distance = 1.4
	# origin = ZERO + (0,0,-1)*1.4 + UP*(-0.05) = (0, -0.05, -1.4)
	xform = MenuScript.placement_transform(Vector3.ZERO, Vector3.FORWARD, 1.4, -0.05)
	_expect(abs(xform.origin.z - (-1.4)) < 0.01, "placement_transform applies distance (z = -1.4)")
	_expect(abs(xform.origin.y - (-0.05)) < 0.01, "placement_transform applies height offset")

	# Test 13: normalize_buttons static method
	var normalized = MenuScript.normalize_buttons([
		{"id": "a", "label": "A", "rect": Rect2(0, 0, 0.1, 0.1)},
		{"id": "b", "label": "B", "rect": "invalid"},
		{"label": "No ID", "rect": Rect2(0, 0, 0.1, 0.1)},
		"not a dict",
	])
	_expect(normalized.size() == 1, "normalize_buttons filters invalid entries")
	_expect(normalized[0]["id"] == "a", "normalize_buttons preserves valid entry")

	# Test 14: _rebuild_button_labels called after set_buttons
	menu.set_buttons([{"id": "test", "label": "Test", "rect": Rect2(-0.1, -0.05, 0.2, 0.1)}])
	_expect(menu._button_labels.has("test"), "_rebuild_button_labels creates label for button")

	# Test 15: open_in_front sets panel_root.visible
	menu.close_menu()
	_expect(not menu.panel_root.visible, "panel_root not visible when closed")
	menu.open_in_front(Vector3.ZERO, Vector3.FORWARD)
	_expect(menu.panel_root.visible, "panel_root visible when opened")

	# Test 16: close_menu emits closed signal (only when was open)
	# Note: menu is OPEN from test 15 (open_in_front without close)
	var state = {"closed_fired": false}
	menu.closed.connect(func() -> void: state["closed_fired"] = true)
	menu.close_menu()  # was open, SHOULD emit
	_expect(state["closed_fired"], "closed signal emitted when was open")
	# Now closed, second close should NOT emit
	state["closed_fired"] = false
	menu.close_menu()
	_expect(not state["closed_fired"], "closed signal NOT emitted when already closed")
	# Open and close again
	menu.open_in_front(Vector3.ZERO, Vector3.FORWARD)
	state["closed_fired"] = false
	menu.close_menu()
	_expect(state["closed_fired"], "closed signal emitted on close_menu when was open (2nd time)")

	# Test 16b: manual signal emit works
	var manual_state = {"fired": false}
	menu.closed.connect(func() -> void: manual_state["fired"] = true)
	menu.closed.emit()
	_expect(manual_state["fired"], "manual closed.emit() works")

	# Test 17: placement_transform with custom up vector
	xform = MenuScript.placement_transform(Vector3.ZERO, Vector3.FORWARD, 1.4, 0.0, Vector3.RIGHT)
	_expect(abs(xform.basis.y - Vector3.RIGHT).length() < 0.01, "placement_transform uses custom up vector")

	# Test 18: try_press requires trigger_pressed
	menu.open_in_front(Vector3.ZERO, Vector3.FORWARD)
	menu.set_buttons([{"id": "press_me", "label": "Press", "rect": Rect2(-0.1, -0.05, 0.2, 0.1)}])
	var pressed_id = menu.try_press(Vector3(0, -0.05, -2), Vector3(0, 0, 1), false)
	_expect(pressed_id.is_empty(), "try_press returns empty without trigger")
	pressed_id = menu.try_press(Vector3(0, -0.05, -2), Vector3(0, 0, 1), true)
	_expect(pressed_id == "press_me", "try_press returns button_id with trigger")

	# Test 19: button_pressed signal emitted on try_press
	var btn_state = {"id": ""}
	menu.button_pressed.connect(func(id: String) -> void: btn_state["id"] = id)
	menu.try_press(Vector3(0, -0.05, -2), Vector3(0, 0, 1), true)
	_expect(btn_state["id"] == "press_me", "button_pressed signal emitted with correct id")

	# Cleanup
	menu.free()

	if _fail == 0:
		print("PASS (%d assertions)" % _n)
		quit(0)
	else:
		print("FAIL (%d assertions, %d failures)" % [_n, _fail])
		quit(1)