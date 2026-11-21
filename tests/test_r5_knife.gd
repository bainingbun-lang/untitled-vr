extends SceneTree

const DbScript = preload("res://core/game/weapon_db.gd")
const GoreScript = preload("res://core/game/gore_system.gd")
const VrKnifeScript = preload("res://core/game/vr_knife.gd")
const VrGrabbableScript = preload("res://core/vr/vr_grabbable.gd")
const MeshSlicerScript = preload("res://core/game/mesh_slicer.gd")
const GoreFxScript = preload("res://core/game/gore_fx.gd")
const WoundDecalsScript = preload("res://core/game/wound_decals.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""
var _root: Node3D = null
var _knife: VrKnifeScript = null

func _initialize() -> void:
	await process_frame
	_root = Node3D.new()
	root.add_child(_root)
	GoreScript.initialize()
	
	_test_weapon_definition()
	_test_slash_detection()
	_test_cooldown_system()
	_test_haptic_feedback()
	_test_gore_level_integration()
	_test_cut_angle_threshold()
	_test_damage_calculation()
	_test_can_slash()
	_test_force_end_slash()
	
	GoreScript.shutdown()
	WoundDecalsScript.shutdown()
	if is_instance_valid(_root):
		_root.queue_free()
	_root = null
	
	paused = false
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + str(failure))
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)

func _test_weapon_definition() -> void:
	_case = "definicion de arma cargada"
	var def: Dictionary = DbScript.get_def("untitled.base:knife")
	_expect(not def.is_empty(), "definicion existe en weapon_db")
	_expect(def["id"] == "untitled.base:knife", "id coincide")
	_expect(def["name"] == "Cuchillo VR", "nombre correcto")
	_expect(def["tags"].has("vr_knife"), "tiene tag vr_knife")
	_expect(def["tags"].has("melee"), "tiene tag melee")
	_expect(def["damage"] == 40.0, "damage base 40")
	_expect(def["range"] == 1.8, "range 1.8")
	_expect(def["fire_rate"] == 3.0, "fire_rate 3.0")
	_expect(def["uses_ammo"] == false, "no usa municion")
	_expect(def["weight"] == 0.5, "peso 0.5")
	
	_case = "configuracion vr_knife en definicion"
	var vr_cfg: Dictionary = def.get("vr_knife", {})
	_expect(not vr_cfg.is_empty(), "tiene configuracion vr_knife")
	_expect(vr_cfg["min_slash_speed"] == 2.0, "min_slash_speed 2.0")
	_expect(vr_cfg["max_slash_speed"] == 12.0, "max_slash_speed 12.0")
	_expect(vr_cfg["slash_cooldown"] == 0.35, "slash_cooldown 0.35")
	_expect(vr_cfg["cut_angle_threshold"] == 0.7, "cut_angle_threshold 0.7")
	_expect(vr_cfg.has("haptic_light"), "tiene haptic_light")
	_expect(vr_cfg.has("haptic_medium"), "tiene haptic_medium")
	_expect(vr_cfg.has("haptic_heavy"), "tiene haptic_heavy")
	_expect(vr_cfg.has("gore_level_mult"), "tiene gore_level_mult")
	var gore_mult: Dictionary = vr_cfg["gore_level_mult"]
	_expect(gore_mult["off"] == 0.0, "gore OFF multiplicador 0.0")
	_expect(gore_mult["normal"] == 1.0, "gore NORMAL multiplicador 1.0")
	_expect(gore_mult["extreme"] == 1.5, "gore EXTREME multiplicador 1.5")

func _test_slash_detection() -> void:
	_case = "deteccion de slash por velocidad"
	_knife = VrKnifeScript.new()
	_knife.weapon_id = "untitled.base:knife"
	_root.add_child(_knife)
	
	var mock_hand = RefCounted.new()
	_knife.set_parent(mock_hand)
	_knife.on_grabbed(mock_hand, "right", Transform3D.IDENTITY)
	
	_knife.global_position = Vector3(0, 1.5, 0)
	await process_frame
	await process_frame
	
	_knife.global_position = Vector3(0.5, 1.5, 0)
	await process_frame
	
	_knife.global_position = Vector3(1.5, 1.5, 0)
	await process_frame
	
	var slash_speed = _knife._slash_speed
	_expect(slash_speed >= 2.0, "velocidad de slash detectada: %s" % slash_speed)
	_expect(_knife._is_slashing == true, "estado slashing activado")
	_knife.on_released(mock_hand, "right", Vector3.ZERO)
	_knife.queue_free()
	await process_frame

func _test_cooldown_system() -> void:
	_case = "sistema de cooldown"
	_knife = VrKnifeScript.new()
	_knife.weapon_id = "untitled.base:knife"
	_root.add_child(_knife)
	
	_expect(_knife.get_cooldown_remaining() == 0.0, "cooldown inicial 0")
	_expect(_knife.can_slash() == true, "puede slashear sin cooldown")
	
	_knife._cooldown_timer = 0.5
	_expect(_knife.get_cooldown_remaining() > 0.0, "cooldown activo")
	_expect(_knife.can_slash() == false, "no puede slashear con cooldown")
	
	_knife._cooldown_timer = 0.0
	_expect(_knife.can_slash() == true, "puede slashear tras cooldown")
	
	_knife.queue_free()

func _test_haptic_feedback() -> void:
	_case = "configuracion de hapticos"
	_knife = VrKnifeScript.new()
	_knife.weapon_id = "untitled.base:knife"
	_root.add_child(_knife)
	await process_frame
	
	_expect(_knife._haptic_light.has("duration"), "haptic_light tiene duration")
	_expect(_knife._haptic_light.has("frequency"), "haptic_light tiene frequency")
	_expect(_knife._haptic_light.has("amplitude"), "haptic_light tiene amplitude")
	_expect(_knife._haptic_medium.has("duration"), "haptic_medium tiene duration")
	_expect(_knife._haptic_heavy.has("amplitude"), "haptic_heavy tiene amplitude")
	
	_knife.queue_free()

func _test_gore_level_integration() -> void:
	_case = "integracion con niveles de gore"
	_knife = VrKnifeScript.new()
	_knife.weapon_id = "untitled.base:knife"
	_root.add_child(_knife)
	await process_frame
	
	GoreScript.apply_gore_level(GoreScript.GoreLevel.OFF)
	var mult_off = _knife._gore_level_mult.get(GoreScript.GoreLevel.OFF, 0.0)
	_expect(mult_off == 0.0, "multiplicador OFF es 0.0")
	
	GoreScript.apply_gore_level(GoreScript.GoreLevel.NORMAL)
	var mult_normal = _knife._gore_level_mult.get(GoreScript.GoreLevel.NORMAL, 0.0)
	_expect(mult_normal == 1.0, "multiplicador NORMAL es 1.0")
	
	GoreScript.apply_gore_level(GoreScript.GoreLevel.EXTREME)
	var mult_extreme = _knife._gore_level_mult.get(GoreScript.GoreLevel.EXTREME, 0.0)
	_expect(mult_extreme == 1.5, "multiplicador EXTREME es 1.5")
	
	_knife.queue_free()

func _test_cut_angle_threshold() -> void:
	_case = "umbral de angulo de corte"
	_knife = VrKnifeScript.new()
	_knife.weapon_id = "untitled.base:knife"
	_root.add_child(_knife)
	await process_frame
	
	var threshold = _knife.cut_angle_threshold
	_expect(threshold == 0.7, "threshold por defecto 0.7")
	
	var angle_cos_parallel = 1.0
	var angle_cos_perpendicular = 0.0
	var angle_cos_45 = 0.7071
	
	_expect(angle_cos_parallel > threshold, "paralelo (cos=1.0) supera threshold")
	_expect(angle_cos_perpendicular < threshold, "perpendicular (cos=0.0) no supera threshold")
	_expect(angle_cos_45 > threshold, "45 grados (cos=0.707) supera threshold")
	
	_knife.queue_free()

func _test_damage_calculation() -> void:
	_case = "calculo de dano por velocidad y gore"
	_knife = VrKnifeScript.new()
	_knife.weapon_id = "untitled.base:knife"
	_root.add_child(_knife)
	await process_frame
	
	GoreScript.apply_gore_level(GoreScript.GoreLevel.NORMAL)
	var dmg_normal_low = _knife._calculate_damage(2.0, 1.0)
	var dmg_normal_high = _knife._calculate_damage(12.0, 1.0)
	_expect(dmg_normal_high > dmg_normal_low, "mas velocidad = mas dano: %s > %s" % [dmg_normal_high, dmg_normal_low])
	
	GoreScript.apply_gore_level(GoreScript.GoreLevel.EXTREME)
	var dmg_extreme = _knife._calculate_damage(6.0, 1.5)
	var dmg_normal = _knife._calculate_damage(6.0, 1.0)
	_expect(dmg_extreme > dmg_normal, "EXTREME hace mas dano que NORMAL: %s > %s" % [dmg_extreme, dmg_normal])
	
	GoreScript.apply_gore_level(GoreScript.GoreLevel.OFF)
	var dmg_off = _knife._calculate_damage(6.0, 0.0)
	_expect(dmg_off == 0.0, "OFF hace dano 0")
	
	_knife.queue_free()

func _test_can_slash() -> void:
	_case = "metodo can_slash"
	_knife = VrKnifeScript.new()
	_knife.weapon_id = "untitled.base:knife"
	_root.add_child(_knife)
	
	var mock_hand = RefCounted.new()
	_knife.set_parent(mock_hand)
	_knife.on_grabbed(mock_hand, "right", Transform3D.IDENTITY)
	_knife._cooldown_timer = 0.0
	_expect(_knife.can_slash() == true, "puede slashear agarrado sin cooldown")
	
	_knife._cooldown_timer = 0.5
	_expect(_knife.can_slash() == false, "no puede slashear con cooldown")
	
	_knife.on_released(mock_hand, "right", Vector3.ZERO)
	_knife._cooldown_timer = 0.0
	_expect(_knife.can_slash() == false, "no puede slashear sin agarrar")
	
	_knife.queue_free()

func _test_force_end_slash() -> void:
	_case = "forzar fin de slash"
	_knife = VrKnifeScript.new()
	_knife.weapon_id = "untitled.base:knife"
	_root.add_child(_knife)
	
	var mock_hand = RefCounted.new()
	_knife.on_grabbed(mock_hand, "right", Transform3D.IDENTITY)
	_knife._start_slash(Vector3(0, 1.5, 0), Vector3(5, 0, 0), 5.0)
	_expect(_knife._is_slashing == true, "slash iniciado")
	
	_knife.force_end_slash()
	_expect(_knife._is_slashing == false, "slash terminado por force_end_slash")
	_expect(_knife._cooldown_timer > 0.0, "cooldown activado")
	
	_knife.queue_free()

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [_case, message])