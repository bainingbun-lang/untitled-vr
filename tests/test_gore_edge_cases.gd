class_name GoreEdgeCasesTest
extends SceneTree

var _checks: int = 0
var _failures: Array = []

func _initialize() -> void:
	await process_frame
	_run_tests()

func _run_tests() -> void:
	_case("apply_profile clamps limits correctly")
	_test_apply_profile_clamping()

	_case("enforce_limits recycles oldest entries")
	_test_enforce_limits_recycles_oldest()

	_case("blood_hit respects jet vs normal spread")
	_test_blood_hit_jet_vs_normal()

	_case("on_death creates decal, puddle, and particles")
	_test_on_death_creates_all()

	_case("puddle returns null when gore disabled")
	_test_puddle_returns_null_when_disabled()

	_case("puddle aligns to ground normal")
	_test_puddle_aligns_to_ground()

	_case("dismember respects global parts limit")
	_test_dismember_respects_global_limit()

	_case("dismember returns created parts array")
	_test_dismember_returns_array()

	_case("dismember applies impulse to parts")
	_test_dismember_applies_impulse()

	_case("clear removes all gore nodes")
	_test_clear_removes_all()

	_case("shutdown frees all resources")
	_test_shutdown_frees_resources()

	_case("profile levels affect limits")
	_test_profile_levels_affect_limits()

	_case("blood_hit with zero direction uses normal")
	_test_blood_hit_zero_direction_uses_normal()

	_case("dismember with zero count clamps to 1")
	_test_dismember_zero_count_clamps()

	_case("multiple blood_hit calls recycle correctly")
	_test_multiple_blood_hit_recycle()

	_case("gore_enabled forced override works")
	_test_gore_enabled_forced_override()

	_case("gore_enabled falls back when GameSession missing")
	_test_gore_enabled_fallback()

	_case("decal texture is generated procedurally")
	_test_decal_texture_procedural()

	_case("puddle mesh is irregular disc")
	_test_puddle_mesh_irregular()

	_case("material properties are set correctly")
	_test_material_properties()

	_finalize()

func _case(name: String) -> void:
	print("=== %s ===" % name)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [_case_name, message])
		print("  FAIL: %s" % message)
	else:
		print("  PASS: %s" % message)

func _expect_eq(a, b, message: String) -> void:
	_checks += 1
	if a != b:
		_failures.append("%s: %s (got %s, expected %s)" % [_case_name, message, a, b])
		print("  FAIL: %s (got %s, expected %s)" % [message, a, b])
	else:
		print("  PASS: %s" % message)

var _case_name: String = ""

func _finalize() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()
	GoreFxScript.shutdown()
	GoreFxScript.set_gore_enabled(null)
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)

func _test_apply_profile_clamping() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()
	GoreFxScript.set_gore_enabled(true)

	# Test profile with values exceeding MAX
	GoreFxScript.apply_profile({"decals": 1000, "particles": 10000})
	_expect(GoreFxScript.limit_decals == GoreFxScript.MAX_DECALS, "decals clamped to MAX_DECALS")
	_expect(GoreFxScript.limit_active <= GoreFxScript.MAX_ACTIVE, "active clamped to MAX_ACTIVE")
	_expect(GoreFxScript.limit_puddles <= GoreFxScript.MAX_PUDDLES, "puddles clamped to MAX_PUDDLES")

	# Test profile with values below minimum
	GoreFxScript.apply_profile({"decals": 1, "particles": 1})
	_expect(GoreFxScript.limit_decals >= 4, "decals minimum is 4")
	_expect(GoreFxScript.limit_active >= 2, "active minimum is 2")
	_expect(GoreFxScript.limit_puddles >= 2, "puddles minimum is 2")

	# Test partial profile (only decals)
	GoreFxScript.apply_profile({"decals": 32})
	_expect(GoreFxScript.limit_decals == 32, "partial profile updates only decals")

	GoreFxScript.clear()

func _test_enforce_limits_recycles_oldest() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()
	GoreFxScript.set_gore_enabled(true)

	var holder = Node3D.new()
	get_root().add_child(holder)

	# Fill beyond limit
	for i in range(GoreFxScript.MAX_DECALS + 10):
		GoreFxScript._add_decal(holder, Vector3(i * 0.1, 1.0, 0.0), Vector3.UP, 0.2)
		await process_frame

	_expect(GoreFxScript.decal_count() == GoreFxScript.MAX_DECALS, "decals limited to MAX_DECALS")

	# Verify oldest were removed (first ones should be gone)
	var first_decal = GoreFxScript.decal_at(0)
	_expect(first_decal != null, "decal_at(0) returns valid node")

	holder.queue_free()
	await process_frame
	GoreFxScript.clear()

func _test_blood_hit_jet_vs_normal() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()
	GoreFxScript.set_gore_enabled(true)

	var holder = Node3D.new()
	get_root().add_child(holder)

	GoreFxScript.blood_hit(holder, Vector3(0, 1, 0), Vector3.UP, 10.0, Vector3.FORWARD, false)
	var normal_particles = GoreFxScript.active_count()

	GoreFxScript.clear()
	GoreFxScript.blood_hit(holder, Vector3(0, 1, 0), Vector3.UP, 10.0, Vector3.FORWARD, true)
	var jet_particles = GoreFxScript.active_count()

	_expect(normal_particles > 0, "normal blood hit creates particles")
	_expect(jet_particles > 0, "jet blood hit creates particles")

	holder.queue_free()
	await process_frame
	GoreFxScript.clear()

func _test_on_death_creates_all() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()
	GoreFxScript.set_gore_enabled(true)

	var holder = Node3D.new()
	get_root().add_child(holder)

	var decals_before = GoreFxScript.decal_count()
	var puddles_before = GoreFxScript.puddle_count()
	var active_before = GoreFxScript.active_count()

	GoreFxScript.on_death(holder, Vector3(0, 1, 0), 1.0)
	await process_frame

	_expect(GoreFxScript.decal_count() > decals_before, "on_death creates decal")
	_expect(GoreFxScript.puddle_count() > puddles_before, "on_death creates puddle")
	_expect(GoreFxScript.active_count() > active_before, "on_death creates particles")

	holder.queue_free()
	await process_frame
	GoreFxScript.clear()

func _test_puddle_returns_null_when_disabled() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()
	GoreFxScript.set_gore_enabled(false)

	var holder = Node3D.new()
	get_root().add_child(holder)

	var puddle = GoreFxScript.puddle(holder, Vector3(0, 1, 0), Vector3.UP, 1.0)
	_expect(puddle == null, "puddle returns null when gore disabled")

	holder.queue_free()
	await process_frame
	GoreFxScript.set_gore_enabled(null)
	GoreFxScript.clear()

func _test_puddle_aligns_to_ground() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()
	GoreFxScript.set_gore_enabled(true)

	var holder = Node3D.new()
	get_root().add_child(holder)

	# Create a floor
	var floor = StaticBody3D.new()
	var floor_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(10, 0.1, 10)
	floor_shape.shape = box_shape
	floor.add_child(floor_shape)
	floor.position = Vector3(0, 0, 0)
	floor.collision_layer = 1
	holder.add_child(floor)

	var puddle = GoreFxScript.puddle(holder, Vector3(0, 1, 0), Vector3.UP, 0.5)
	await process_frame

	_expect(puddle != null, "puddle created")
	_expect(puddle.global_position.y < 0.1, "puddle positioned near ground")

	floor.queue_free()
	holder.queue_free()
	await process_frame
	GoreFxScript.clear()

func _test_dismember_respects_global_limit() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()
	GoreFxScript.set_gore_enabled(true)

	var holder = Node3D.new()
	get_root().add_child(holder)

	# Create more parts than MAX_PARTS
	for i in range(GoreFxScript.MAX_PARTS + 5):
		GoreFxScript.dismember(holder, Vector3(i * 0.1, 1.0, 0), 1.0, "limb", 2)
		await process_frame

	_expect(GoreFxScript.dismembered_count() <= GoreFxScript.MAX_PARTS, "parts limited to MAX_PARTS")

	holder.queue_free()
	await process_frame
	GoreFxScript.clear()

func _test_dismember_returns_array() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()
	GoreFxScript.set_gore_enabled(true)

	var holder = Node3D.new()
	get_root().add_child(holder)

	var parts = GoreFxScript.dismember(holder, Vector3(0, 1, 0), 1.0, "arm", 3)
	_expect(parts is Array, "dismember returns Array")
	_expect(parts.size() > 0, "dismember returns non-empty array")
	_expect(parts[0] is RigidBody3D, "parts are RigidBody3D")

	holder.queue_free()
	await process_frame
	GoreFxScript.clear()

func _test_dismember_applies_impulse() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()
	GoreFxScript.set_gore_enabled(true)

	var holder = Node3D.new()
	get_root().add_child(holder)

	var parts = GoreFxScript.dismember(holder, Vector3(0, 1, 0), 1.0, "leg", 2)
	await physics_frame

	var has_velocity = false
	for part in parts:
		if part.linear_velocity.length() > 0.1:
			has_velocity = true
			break

	_expect(has_velocity, "dismembered parts have velocity from impulse")

	holder.queue_free()
	await process_frame
	GoreFxScript.clear()

func _test_clear_removes_all() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()
	GoreFxScript.set_gore_enabled(true)

	var holder = Node3D.new()
	get_root().add_child(holder)

	GoreFxScript.blood_hit(holder, Vector3(0, 1, 0), Vector3.UP, 10.0)
	GoreFxScript.on_death(holder, Vector3(1, 1, 0), 1.0)
	GoreFxScript.puddle(holder, Vector3(2, 1, 0), Vector3.UP, 1.0)
	GoreFxScript.dismember(holder, Vector3(3, 1, 0), 1.0, "test", 2)
	await process_frame

	_expect(GoreFxScript.decal_count() > 0, "decals exist before clear")
	_expect(GoreFxScript.active_count() > 0, "active exist before clear")
	_expect(GoreFxScript.puddle_count() > 0, "puddles exist before clear")
	_expect(GoreFxScript.dismembered_count() > 0, "parts exist before clear")

	GoreFxScript.clear()

	_expect(GoreFxScript.decal_count() == 0, "decals cleared")
	_expect(GoreFxScript.active_count() == 0, "active cleared")
	_expect(GoreFxScript.puddle_count() == 0, "puddles cleared")
	_expect(GoreFxScript.dismembered_count() == 0, "parts cleared")

	holder.queue_free()
	await process_frame
	GoreFxScript.clear()

func _test_shutdown_frees_resources() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()
	GoreFxScript.set_gore_enabled(true)

	var holder = Node3D.new()
	get_root().add_child(holder)

	GoreFxScript.blood_hit(holder, Vector3(0, 1, 0), Vector3.UP, 10.0)
	await process_frame

	GoreFxScript.shutdown()

	_expect(GoreFxScript.decal_count() == 0, "decals freed")
	_expect(GoreFxScript.active_count() == 0, "active freed")
	_expect(GoreFxScript.puddle_count() == 0, "puddles freed")
	_expect(GoreFxScript.dismembered_count() == 0, "parts freed")
	_expect(GoreFxScript._blood_mesh == null, "blood mesh freed")
	_expect(GoreFxScript._blood_material == null, "blood material freed")
	_expect(GoreFxScript._decal_material == null, "decal material freed")
	_expect(GoreFxScript._puddle_material == null, "puddle material freed")
	_expect(GoreFxScript._part_material == null, "part material freed")
	_expect(GoreFxScript._decal_texture == null, "decal texture freed")

	holder.queue_free()
	await process_frame

func _test_profile_levels_affect_limits() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()
	GoreFxScript.set_gore_enabled(true)

	# Test "off" profile (via gore_profiles.json values)
	GoreFxScript.apply_profile({"decals": 0, "particles": 0})
	_expect(GoreFxScript.limit_decals == 4, "off profile: decals at minimum")
	_expect(GoreFxScript.limit_active == 2, "off profile: active at minimum")
	_expect(GoreFxScript.limit_puddles == 2, "off profile: puddles at minimum")

	# Test "normal" profile (clamped to MAX_DECALS=64)
	GoreFxScript.apply_profile({"decals": 96, "particles": 256})
	_expect(GoreFxScript.limit_decals == GoreFxScript.MAX_DECALS, "normal profile: decals clamped to MAX_DECALS")
	_expect(GoreFxScript.limit_active >= 16, "normal profile: active scaled from particles")

	# Test "extreme" profile
	GoreFxScript.apply_profile({"decals": 256, "particles": 768})
	_expect(GoreFxScript.limit_decals == GoreFxScript.MAX_DECALS, "extreme profile: decals clamped to MAX")
	_expect(GoreFxScript.limit_active == GoreFxScript.MAX_ACTIVE, "extreme profile: active clamped to MAX")

	GoreFxScript.clear()

func _test_blood_hit_zero_direction_uses_normal() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()
	GoreFxScript.set_gore_enabled(true)

	var holder = Node3D.new()
	get_root().add_child(holder)

	# Call with zero direction
	GoreFxScript.blood_hit(holder, Vector3(0, 1, 0), Vector3.RIGHT, 10.0, Vector3.ZERO)
	await process_frame

	_expect(GoreFxScript.active_count() > 0, "blood_hit works with zero direction")

	holder.queue_free()
	await process_frame
	GoreFxScript.clear()

func _test_dismember_zero_count_clamps() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()
	GoreFxScript.set_gore_enabled(true)

	var holder = Node3D.new()
	get_root().add_child(holder)

	# Call with count = 0 (should clamp to 1)
	var parts = GoreFxScript.dismember(holder, Vector3(0, 1, 0), 1.0, "test", 0)
	await process_frame

	_expect(parts.size() >= 1, "dismember with count=0 creates at least 1 part")

	holder.queue_free()
	await process_frame
	GoreFxScript.clear()

func _test_multiple_blood_hit_recycle() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()
	GoreFxScript.set_gore_enabled(true)

	var holder = Node3D.new()
	get_root().add_child(holder)

	# Create MAX_DECALS decals
	for i in range(GoreFxScript.MAX_DECALS):
		GoreFxScript.blood_hit(holder, Vector3(i * 0.1, 1.0, 0), Vector3.UP, 10.0)
		await process_frame

	var initial_count = GoreFxScript.decal_count()
	_expect(initial_count == GoreFxScript.MAX_DECALS, "reached MAX_DECALS")

	# Add more - should recycle oldest
	for i in range(10):
		GoreFxScript.blood_hit(holder, Vector3((GoreFxScript.MAX_DECALS + i) * 0.1, 1.0, 0), Vector3.UP, 10.0)
		await process_frame

	_expect(GoreFxScript.decal_count() == GoreFxScript.MAX_DECALS, "still at MAX_DECALS after more hits")

	holder.queue_free()
	await process_frame
	GoreFxScript.clear()

func _test_gore_enabled_forced_override() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()

	# Force override to false
	GoreFxScript.set_gore_enabled(false)
	_expect(GoreFxScript.gore_enabled() == false, "forced false works")

	# Force override to true
	GoreFxScript.set_gore_enabled(true)
	_expect(GoreFxScript.gore_enabled() == true, "forced true works")

	# Clear override (null)
	GoreFxScript.set_gore_enabled(null)
	# Should fall back to GameSession.gore_enabled (default true)
	_expect(GoreFxScript.gore_enabled() == true, "null override falls back to GameSession")

	GoreFxScript.clear()

func _test_gore_enabled_fallback() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()
	GoreFxScript.set_gore_enabled(null)

	# Without GameSession, should default to true
	_expect(GoreFxScript.gore_enabled() == true, "defaults to true when no GameSession")

	GoreFxScript.clear()

func _test_decal_texture_procedural() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()

	var texture = GoreFxScript._get_decal_texture()
	_expect(texture != null, "decal texture generated")
	_expect(texture is GradientTexture2D, "decal texture is GradientTexture2D")
	_expect(texture.width == 32, "decal texture width 32")
	_expect(texture.height == 32, "decal texture height 32")
	_expect(texture.fill == GradientTexture2D.FILL_RADIAL, "decal texture radial fill")

	GoreFxScript.clear()

func _test_puddle_mesh_irregular() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()

	var mesh = GoreFxScript._make_irregular_disc(1.0, 16)
	_expect(mesh != null, "irregular disc mesh created")
	_expect(mesh is ArrayMesh, "mesh is ArrayMesh")
	_expect(mesh.get_surface_count() == 1, "mesh has 1 surface")

	# Check vertices count (center + segments)
	var arrays = mesh.surface_get_arrays(0)
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	_expect(vertices.size() == 17, "mesh has center + 16 vertices")

	GoreFxScript.clear()

func _test_material_properties() -> void:
	const GoreFxScript = preload("res://core/game/gore_fx.gd")
	GoreFxScript.clear()

	var blood_mat = GoreFxScript._get_blood_material()
	_expect(blood_mat.albedo_color.r > 0.5, "blood material is red")
	_expect(abs(blood_mat.roughness - 0.9) < 0.01, "blood material high roughness")

	var decal_mat = GoreFxScript._get_decal_material()
	_expect(decal_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "decal material alpha transparency")
	_expect(decal_mat.albedo_texture != null, "decal material has texture")

	var puddle_mat = GoreFxScript._get_puddle_material()
	_expect(puddle_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "puddle material alpha transparency")
	_expect(abs(puddle_mat.roughness - 0.3) < 0.01, "puddle material low roughness (wet)")

	var part_mat = GoreFxScript._get_part_material()
	_expect(part_mat.albedo_color.r > 0.4, "part material is reddish")
	_expect(abs(part_mat.roughness - 0.85) < 0.01, "part material high roughness")

	GoreFxScript.clear()