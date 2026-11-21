extends SceneTree

const WoundDecalsScript = preload("res://core/game/wound_decals.gd")
const GoreSystemScript = preload("res://core/game/gore_system.gd")
const ContentRegistryScript = preload("res://core/game/content_registry.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""
var _test_parent: Node3D

func _initialize() -> void:
	await process_frame
	_setup_test_scene()
	
	_case = "damage mask creation and pool limit"
	_test_damage_mask_creation()
	
	_case = "damage mask layer selection by depth"
	_test_damage_mask_layers()
	
	_case = "wound creation with damage mask integration"
	_test_wound_creation_with_mask()
	
	_case = "decal pool limit enforcement (max 24 normal)"
	_test_decal_pool_limit()
	
	_case = "gore level limits from profile"
	_test_gore_level_limits()
	
	_case = "npc damage mask release"
	_test_npc_mask_release()
	
	_cleanup_test_scene()
	
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + str(failure))
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)

func _setup_test_scene() -> void:
	_test_parent = Node3D.new()
	_test_parent.name = "TestParent"
	root.add_child(_test_parent)
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.NORMAL)
	await process_frame

func _cleanup_test_scene() -> void:
	WoundDecalsScript.clear()
	GoreSystemScript.clear()
	if is_instance_valid(_test_parent):
		_test_parent.queue_free()
	await process_frame

func _test_damage_mask_creation() -> void:
	var mask1: Image = WoundDecalsScript.get_or_create_damage_mask(1)
	_expect(mask1 != null, "mask creada para npc_id=1")
	_expect(mask1.get_width() == 256, "ancho 256px: %d" % mask1.get_width())
	_expect(mask1.get_height() == 256, "alto 256px: %d" % mask1.get_height())
	_expect(mask1.get_format() == Image.FORMAT_RGBA8, "formato RGBA8")
	
	var mask2: Image = WoundDecalsScript.get_or_create_damage_mask(2)
	_expect(mask2 != mask1, "diferentes NPCs tienen mascaras distintas")
	
	var mask1_again: Image = WoundDecalsScript.get_or_create_damage_mask(1)
	_expect(mask1_again == mask1, "mismo NPC devuelve misma mascara")
	
	_expect(WoundDecalsScript.damage_mask_count() == 2, "contador de mascaras: %d" % WoundDecalsScript.damage_mask_count())

func _test_damage_mask_layers() -> void:
	var mask: Image = WoundDecalsScript.get_or_create_damage_mask(10)
	
	WoundDecalsScript.apply_damage_to_mask(10, Vector2(0.5, 0.5), 0.1, 16)
	var pixel_skin: Color = mask.get_pixel(128, 128)
	_expect(pixel_skin.a > 0.5, "capa SKIN (depth=0.1) pinta alpha: %.2f" % pixel_skin.a)
	_expect(pixel_skin.r > 0.5, "color piel rojizo: %.2f" % pixel_skin.r)
	
	WoundDecalsScript.apply_damage_to_mask(10, Vector2(0.3, 0.3), 0.5, 16)
	var pixel_muscle: Color = mask.get_pixel(77, 77)
	_expect(pixel_muscle.a > 0.5, "capa MUSCLE (depth=0.5) pinta alpha: %.2f" % pixel_muscle.a)
	_expect(pixel_muscle.r < pixel_skin.r, "musculo mas oscuro que piel: %.2f vs %.2f" % [pixel_muscle.r, pixel_skin.r])
	
	WoundDecalsScript.apply_damage_to_mask(10, Vector2(0.7, 0.7), 0.9, 16)
	var pixel_bone: Color = mask.get_pixel(179, 179)
	_expect(pixel_bone.a > 0.5, "capa BONE (depth=0.9) pinta alpha: %.2f" % pixel_bone.a)
	_expect(pixel_bone.r < pixel_muscle.r, "hueso mas oscuro que musculo: %.2f vs %.2f" % [pixel_bone.r, pixel_muscle.r])

func _test_wound_creation_with_mask() -> void:
	var wound: Dictionary = WoundDecalsScript.create_wound(_test_parent, Vector3(0, 1.5, 0), Vector3.UP, 0.1, 3, "torso", 42, Vector2(0.4, 0.6), 0.4)
	_expect(not wound.is_empty(), "herida creada con npc_id y uv")
	_expect(wound.has("npc_id") and wound["npc_id"] == 42, "npc_id guardado: %s" % wound.get("npc_id", "none"))
	_expect(wound.has("depth") and wound["depth"] == 0.4, "depth guardado: %s" % wound.get("depth", "none"))
	_expect(wound.has("layers") and wound["layers"].size() == 3, "tres capas de herida: %d" % wound.get("layers", []).size())
	
	var mask: Image = WoundDecalsScript.get_damage_mask(42)
	_expect(mask != null, "mascara creada para NPC herido")
	var px: Color = mask.get_pixel(int(0.4 * 256), int(0.6 * 256))
	_expect(px.a > 0.3, "mascara tiene daño en UV de impacto: %.2f" % px.a)

func _test_decal_pool_limit() -> void:
	WoundDecalsScript.clear()
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.NORMAL)
	await process_frame
	
	var limit: int = WoundDecalsScript.get_decal_limit()
	_expect(limit == 24, "limite normal decals = 24: %d" % limit)
	
	for i in range(30):
		WoundDecalsScript.create_wound(_test_parent, Vector3(i * 0.1, 1.5, 0), Vector3.UP, 0.08, 2, "test_%d" % i)
	
	await process_frame
	var total: int = WoundDecalsScript.total_decal_count()
	_expect(total <= 24, "pool respeta limite 24: %d" % total)

func _test_gore_level_limits() -> void:
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.OFF)
	await process_frame
	_expect(WoundDecalsScript.get_decal_limit() == 0, "OFF: decal_limit = 0")
	_expect(WoundDecalsScript.get_puddle_limit() == 0, "OFF: puddle_limit = 0")
	
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.NORMAL)
	await process_frame
	_expect(WoundDecalsScript.get_decal_limit() == 24, "NORMAL: decal_limit = 24")
	_expect(WoundDecalsScript.get_puddle_limit() == 16, "NORMAL: puddle_limit = 16")
	_expect(WoundDecalsScript.get_part_limit() == 12, "NORMAL: part_limit = 12")
	_expect(WoundDecalsScript.get_active_particle_limit() == 24, "NORMAL: particle_limit = 24")
	
	GoreSystemScript.apply_gore_level(GoreSystemScript.GoreLevel.EXTREME)
	await process_frame
	_expect(WoundDecalsScript.get_decal_limit() == 48, "EXTREME: decal_limit = 48")
	_expect(WoundDecalsScript.get_puddle_limit() == 32, "EXTREME: puddle_limit = 32")
	_expect(WoundDecalsScript.get_part_limit() == 24, "EXTREME: part_limit = 24")
	_expect(WoundDecalsScript.get_active_particle_limit() == 48, "EXTREME: particle_limit = 48")

func _test_npc_mask_release() -> void:
	WoundDecalsScript.get_or_create_damage_mask(99)
	WoundDecalsScript.apply_damage_to_mask(99, Vector2(0.5, 0.5), 0.5, 16)
	_expect(WoundDecalsScript.damage_mask_count() == 1, "mascara existe antes de release")
	
	WoundDecalsScript.release_npc_damage_mask(99)
	_expect(WoundDecalsScript.damage_mask_count() == 0, "mascara liberada tras release")
	_expect(WoundDecalsScript.get_damage_mask(99) == null, "get_damage_mask devuelve null tras release")

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])