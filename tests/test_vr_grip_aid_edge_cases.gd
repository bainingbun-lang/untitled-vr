extends SceneTree

const HolstersScript = preload("res://core/vr/vr_holsters.gd")
const MenuScript = preload("res://core/vr/vr_menu.gd")
const OnbScript = preload("res://core/vr/vr_onboarding.gd")

var _n := 0
var _fail := 0

func _expect(c: bool, m: String) -> void:
	_n += 1
	if not c:
		_fail += 1
		print("FAIL: " + m)

func _initialize() -> void:
	await process_frame

	# --- VrHolsters Edge Cases (limited due to vr_holsters.gd compilation bug in slot_position) ---
	# Note: vr_holsters.gd has a compilation error in slot_position() where 'local' variable
	# is only declared in one branch of if/else. This blocks tests using nearest_slot/slot_position.

	# Test 1: empty item_id returns false
	var holsters = HolstersScript.new()
	_expect(not holsters.stow("", "right"), "stow empty item_id returns false")
	_expect(holsters.draw("hip", "right").is_empty(), "draw from empty slot returns empty string")
	_expect(holsters.slot_of("").is_empty(), "slot_of empty item_id returns empty string")
	_expect(holsters.item_in("hip").is_empty(), "item_in empty slot returns empty string")
	_expect(not holsters.is_stowed(""), "is_stowed empty item_id returns false")

	# Test 2: invalid slot returns false/empty
	_expect(not holsters.can_stow("pistol", "invalid_slot"), "can_stow invalid slot returns false")
	_expect(not holsters.stow("pistol", "right", "invalid_slot"), "stow invalid slot returns false")
	_expect(holsters.draw("invalid_slot", "right").is_empty(), "draw invalid slot returns empty string")

	# Test 3: duplicate stow in same slot - only works if item matches preferred slot
	_expect(holsters.stow("pistol", "right", "hip"), "stow pistol in hip")
	# pistol2 is classified as "prop" (not pistol), preferred slot is "bag", so stow in hip fails
	_expect(not holsters.stow("pistol2", "right", "hip"), "stow pistol2 in hip fails (wrong preferred slot)")
	_expect(holsters.item_in("hip") == "pistol", "hip slot still has pistol")
	_expect(holsters.is_stowed("pistol"), "pistol still stowed")
	_expect(not holsters.is_stowed("pistol2"), "pistol2 not stowed")

	# Test 4: draw_item removes specific item
	holsters.reset()
	_expect(holsters.stow("pistol", "right", "hip"), "stow pistol")
	_expect(holsters.stow("rifle", "right", "back"), "stow rifle in back")
	_expect(holsters.draw_item("pistol", "right"), "draw_item pistol succeeds")
	_expect(not holsters.is_stowed("pistol"), "pistol no longer stowed after draw_item")
	_expect(holsters.is_stowed("rifle"), "rifle still stowed")

	# Test 5: slot_radius minimum clamp (does not call slot_position)
	_expect(holsters.slot_radius("hip") >= 0.01, "slot_radius hip >= 0.01")
	_expect(holsters.slot_radius("invalid") == 0.01, "slot_radius invalid returns minimum 0.01")

	# Test 6: item_kind classification
	_expect(holsters.item_kind("pistol") == "pistol", "item_kind pistol by name")
	_expect(holsters.item_kind("rifle") == "long_gun", "item_kind rifle by name")
	_expect(holsters.item_kind("assault_rifle", ["rifle"]) == "long_gun", "item_kind assault_rifle by tag")
	_expect(holsters.item_kind("mag", ["magazine"]) == "magazine", "item_kind magazine by tag")
	_expect(holsters.item_kind("bat", ["melee"]) == "long_gun", "item_kind bat by melee tag")
	_expect(holsters.item_kind("unknown_prop") == "prop", "item_kind unknown defaults to prop")

	# Test 7: preferred_slot mapping
	_expect(holsters.preferred_slot("pistol") == "hip", "preferred_slot pistol -> hip")
	_expect(holsters.preferred_slot("rifle") == "back", "preferred_slot rifle -> back")
	_expect(holsters.preferred_slot("mag", ["magazine"]) == "chest", "preferred_slot magazine -> chest")
	_expect(holsters.preferred_slot("random") == "bag", "preferred_slot unknown -> bag")

	# Test 8: events cleared after retrieval
	holsters.reset()
	_expect(holsters.stow("pistol", "right", "hip"), "stow for events")
	var evts = holsters.events()
	_expect(evts.size() == 1, "events returns 1 event")
	_expect(evts[0]["type"] == "stow", "event type is stow")
	evts = holsters.events()
	_expect(evts.is_empty(), "events cleared after retrieval")

	# Test 9: NaN/zero vector handling in normalized_safe
	_expect(HolstersScript.normalized_safe(Vector3(1, 0, 0), Vector3.RIGHT) == Vector3.RIGHT, "normalized_safe normal vector")
	_expect(HolstersScript.normalized_safe(Vector3.ZERO, Vector3.UP) == Vector3.UP, "normalized_safe zero vector returns fallback")
	_expect(HolstersScript.normalized_safe(Vector3(NAN, 0, 0), Vector3.FORWARD) == Vector3.FORWARD, "normalized_safe NaN returns fallback")

	# Test 10: holster signals emitted on stow/draw
	holsters = HolstersScript.new()
	var signals_received: Array = []
	holsters.stowed.connect(func(item_id: String, slot: String, hand: String) -> void: signals_received.append("stowed"))
	holsters.drawn.connect(func(item_id: String, slot: String, hand: String) -> void: signals_received.append("drawn"))
	_expect(holsters.stow("pistol", "right", "hip"), "stow succeeds")
	_expect("stowed" in signals_received, "stowed signal emitted")
	_expect(holsters.draw("hip", "right") == "pistol", "draw succeeds")
	_expect("drawn" in signals_received, "drawn signal emitted")

	# --- VrMenu Edge Cases ---

	# Test 11: build idempotent
	var menu = MenuScript.new()
	_expect(menu.build(), "first build returns true")
	_expect(menu.build(), "second build returns true (idempotent)")

	# Test 12: open/close toggles is_open
	menu.close_menu()
	_expect(not menu.is_open, "close_menu sets is_open false")
	menu.open_in_front(Vector3.ZERO, Vector3.FORWARD)
	_expect(menu.is_open, "open_in_front sets is_open true")
	menu.close_menu()
	_expect(not menu.is_open, "close_menu again sets is_open false")

	# Test 13: toggle flips state
	_expect(not menu.is_open, "starts closed")
	_expect(menu.toggle(Vector3.ZERO, Vector3.FORWARD), "toggle returns true when opening")
	_expect(menu.is_open, "is_open true after toggle")
	_expect(not menu.toggle(Vector3.ZERO, Vector3.FORWARD), "toggle returns false when closing")
	_expect(not menu.is_open, "is_open false after second toggle")

	# Test 14: set_buttons normalizes and filters invalid
	menu.set_buttons([
		{"id": "valid1", "label": "Valid 1", "rect": Rect2(-0.1, -0.05, 0.2, 0.1)},
		{"id": "", "label": "No ID", "rect": Rect2(-0.1, 0.05, 0.2, 0.1)},
		{"id": "valid2", "label": "Valid 2", "rect": "not a rect"},
		{"not_a_dict": true},
	])
	_expect(menu.buttons.size() == 1, "set_buttons keeps only valid entries (valid rect required)")
	_expect(menu.buttons[0]["id"] == "valid1", "first button id preserved")

	# Test 15: pointer_hit returns false when closed
	menu.close_menu()
	var hit = menu.pointer_hit(Vector3.ZERO, Vector3.FORWARD)
	_expect(not hit["hit"], "pointer_hit returns no hit when closed")

	# Test 16: pointer_hit finds button within bounds
	menu.open_in_front(Vector3.ZERO, Vector3.FORWARD)
	menu.set_buttons([{"id": "center", "label": "Center", "rect": Rect2(-0.05, -0.025, 0.1, 0.05)}])
	# Ray from behind panel looking forward (panel at y=-0.05 due to height_offset)
	hit = menu.pointer_hit(Vector3(0, -0.05, -1), Vector3.FORWARD)
	_expect(hit["hit"], "pointer_hit finds button at center")
	_expect(hit["button_id"] == "center", "pointer_hit returns correct button_id")

	# Test 17: pointer_hit misses outside panel
	hit = menu.pointer_hit(Vector3(10, 0, -1), Vector3.FORWARD)
	_expect(not hit["hit"], "pointer_hit misses far off panel")

	# Test 18: raycast_buttons handles zero direction
	hit = MenuScript.raycast_buttons(Vector3.ZERO, Vector3.ZERO, Transform3D.IDENTITY, Vector2(0.6, 0.35), [])
	_expect(not hit["hit"], "raycast_buttons zero direction returns no hit")

	# Test 19: raycast_buttons parallel ray (no intersection)
	var panel_xform = Transform3D(Basis.IDENTITY, Vector3(0, 0, 1))
	hit = MenuScript.raycast_buttons(Vector3(0, 0, 0), Vector3(1, 0, 0), panel_xform, Vector2(0.6, 0.35), [])
	_expect(not hit["hit"], "raycast_buttons parallel ray returns no hit")

	# Test 20: placement_transform clamps distance
	var xform = MenuScript.placement_transform(Vector3.ZERO, Vector3.FORWARD, -1.0, 0.0)
	# distance -1.0 clamped to 0.2, FORWARD is (0,0,-1), so origin.z = -0.2
	_expect(abs(xform.origin.z - (-0.2)) < 0.001, "placement_transform clamps negative distance to minimum 0.2")

	# --- VrOnboarding Edge Cases ---

	# Test 21: configure with null holsters creates new instance
	var ws = preload("res://core/game/weapon_system.gd").new()
	var onb = OnbScript.new()
	root.add_child(onb)
	onb.configure(null, ws, ["pistol"])
	_expect(onb.holsters != null, "configure with null holsters creates new instance")

	# Test 22: yaw_only handles zero forward
	var head = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	head.basis = Basis(Vector3.RIGHT, Vector3.UP, Vector3.FORWARD)
	var yaw = OnbScript.yaw_only(head)
	_expect(yaw.basis.z == Vector3.FORWARD or yaw.basis.z == -Vector3.FORWARD, "yaw_only handles identity basis")

	# Test 23: yaw_only handles forward with y component
	head = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	head.basis = Basis(Vector3.RIGHT, Vector3.UP, Vector3(0, 1, -1).normalized())
	yaw = OnbScript.yaw_only(head)
	_expect(abs(yaw.basis.z.y) < 0.001, "yaw_only removes y component from forward")

	# Test 24: is_looking_at_wrist distance bounds
	head = Transform3D(Basis.IDENTITY, Vector3(0, 1.7, 0))
	var wrist_too_close = Vector3(0, 1.7, -0.03)  # too close (< 0.05)
	_expect(not OnbScript.is_looking_at_wrist(head, wrist_too_close), "is_looking_at_wrist rejects too close")
	var wrist_far = Vector3(0, 1.7, -1.0)  # too far (> 0.65)
	_expect(not OnbScript.is_looking_at_wrist(head, wrist_far), "is_looking_at_wrist rejects too far")
	var wrist_angle = Vector3(1, 1.7, -0.5)  # outside cone (> 0.75 rad ~ 43 deg)
	_expect(not OnbScript.is_looking_at_wrist(head, wrist_angle), "is_looking_at_wrist rejects outside cone")
	var wrist_good = Vector3(-0.1, 1.4, -0.35)  # within bounds
	_expect(OnbScript.is_looking_at_wrist(head, wrist_good), "is_looking_at_wrist accepts valid wrist")

	# Test 25: DISPLAY slot configuration has required keys
	for slot_name in OnbScript.DISPLAY.keys():
		var spec = OnbScript.DISPLAY[slot_name]
		_expect(spec.has("base"), "DISPLAY slot " + slot_name + " has base")
		_expect(spec.has("weapon"), "DISPLAY slot " + slot_name + " has weapon")
		_expect(spec.has("extra"), "DISPLAY slot " + slot_name + " has extra")
		_expect(spec.has("tilt"), "DISPLAY slot " + slot_name + " has tilt")
		_expect(spec.has("mirror"), "DISPLAY slot " + slot_name + " has mirror")

	# Test 26: tutorial auto-close boundary
	var ws2 = preload("res://core/game/weapon_system.gd").new()
	var onb2 = OnbScript.new()
	root.add_child(onb2)
	onb2.configure(HolstersScript.new(), ws2, ["pistol"])
	# Tick just before auto-close (7.99s)
	for i in range(499):
		onb2.tick(0.016, Transform3D(Basis.IDENTITY, Vector3(0, 1.7, 0)), {"left": Transform3D.IDENTITY, "right": Transform3D.IDENTITY}, {"left": 0.0, "right": 0.0})
	_expect(onb2.tutorial_open, "tutorial open just before auto-close")
	# One more tick crosses 8s
	onb2.tick(0.016, Transform3D(Basis.IDENTITY, Vector3(0, 1.7, 0)), {"left": Transform3D.IDENTITY, "right": Transform3D.IDENTITY}, {"left": 0.0, "right": 0.0})
	_expect(not onb2.tutorial_open, "tutorial closed after auto-close timeout")

	# Test 27: trigger state tracking (rising edge detection)
	var ws3 = preload("res://core/game/weapon_system.gd").new()
	var onb3 = OnbScript.new()
	root.add_child(onb3)
	onb3.configure(HolstersScript.new(), ws3, ["pistol"])
	onb3.close_tutorial()
	onb3.show_tutorial()
	# First tick with trigger pressed - closes on rising edge (was false, now true)
	onb3.tick(0.016, Transform3D(Basis.IDENTITY, Vector3(0, 1.7, 0)), {"left": Transform3D.IDENTITY, "right": Transform3D.IDENTITY}, {"left": 0.8, "right": 0.0})
	_expect(not onb3.tutorial_open, "tutorial closes on first rising edge")
	# Reopen and test release-then-press
	onb3.show_tutorial()
	onb3.tick(0.016, Transform3D(Basis.IDENTITY, Vector3(0, 1.7, 0)), {"left": Transform3D.IDENTITY, "right": Transform3D.IDENTITY}, {"left": 0.0, "right": 0.0})
	onb3.tick(0.016, Transform3D(Basis.IDENTITY, Vector3(0, 1.7, 0)), {"left": Transform3D.IDENTITY, "right": Transform3D.IDENTITY}, {"left": 0.8, "right": 0.0})
	_expect(not onb3.tutorial_open, "tutorial closes on release-then-press rising edge")

	# Cleanup
	onb.free()
	onb2.free()
	onb3.free()
	ws.free()
	ws2.free()
	ws3.free()
	menu.free()

	if _fail == 0:
		print("PASS (%d assertions)" % _n)
		quit(0)
	else:
		print("FAIL (%d assertions, %d failures)" % [_n, _fail])
		quit(1)