extends SceneTree

const CharacterScript = preload("res://core/game/character_model.gd")
const WeaponVmScript = preload("res://core/game/weapon_viewmodel.gd")
const ArmedNpcScript = preload("res://core/game/armed_npc.gd")
const DamageableScript = preload("res://core/game/damageable.gd")
const GoreFxScript = preload("res://core/game/gore_fx.gd")
const VoiceScript = preload("res://core/game/voice_system.gd")
const RecordedSfxScript = preload("res://core/game/recorded_sfx.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""
var _root: Node3D = null
var _shots: Array = []
var _hits: Array = []


func _initialize() -> void:
	_root = Node3D.new()
	root.add_child(_root)
	await process_frame
	await process_frame
	await physics_frame

	_test_animation_states()
	await _test_animation_reactions()
	await _test_hands()
	await _test_npc_effects()

	GoreFxScript.set_gore_enabled(null)
	GoreFxScript.clear()
	ArmedNpcScript.clear_registry()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _test_animation_states() -> void:
	_case = "maquina de animaciones reales"
	var model = CharacterScript.spawn(_root, "civil")
	model.auto_drive = false
	var anims: Dictionary = model.resolved_animations()
	_expect(anims.has("idle") and anims.has("walk") and anims.has("run"))
	_expect(anims.has("aim") and anims.has("shoot") and anims.has("hit") and anims.has("die"))
	_expect_eq(str(anims["idle"]), "Idle")
	_expect_eq(str(anims["walk"]), "Walk")
	_expect_eq(str(anims["run"]), "Run")
	_expect(model.animation_player != null)
	_expect(model.animation_player.has_animation(StringName(str(anims["shoot"]))))
	print("[CharacterAnimation] clips reales: %s" % str(anims))

	_expect(model.play("idle"))
	_expect_eq(model.current_animation(), "idle")
	_expect(model.play("walk"))
	_expect_eq(model.current_animation(), "walk")

	model.update_animation(0.5, 4.0)
	var fast_blend: float = model.blend_value()
	_expect(fast_blend > 1.0)
	model.update_animation(0.5, 0.0)
	_expect(model.blend_value() < fast_blend)

	model.update_animation(0.016, 0.0)
	_expect_eq(model.state(), "idle")
	model.update_animation(0.016, 1.5)
	_expect_eq(model.state(), "walk")
	model.update_animation(0.016, 4.0)
	_expect_eq(model.state(), "run")
	model.update_animation(0.016, 0.0, true)
	_expect_eq(model.state(), "aim")
	model.update_animation(0.016, 0.0, false, true)
	_expect_eq(model.state(), "crouch")
	model.update_animation(0.016, 0.0, false, false, true)
	_expect_eq(model.state(), "cover")

	model.set_humano(true)
	model.update_animation(0.016, 3.0)
	_expect(String(model.state()).begins_with("humano"))
	_expect_eq(str(model.animation_for("humano_run")), "Run")
	model.set_humano(false)

	model.set_look_target(Vector3(50.0, 0.0, 0.0))
	for i in range(20):
		model.update_animation(0.016, 0.0)
	_expect(absf(model.look_yaw()) > 1.0)
	_expect(absf(model.look_yaw()) <= 70.2)
	model.clear_look_target()


func _test_animation_reactions() -> void:
	_case = "impactos, gore y muerte"
	var model = CharacterScript.spawn(_root, "soldier")
	model.auto_drive = false
	_hits.clear()
	model.connect("hit_reacted", Callable(self, "_on_hit_reacted"))
	model.react_hit("head", Vector3(0.0, 1.6, 0.0), Vector3.FORWARD, 40.0)
	_expect_eq(model.state(), "hit_head")
	_expect(_hits.size() == 1)
	_expect(model.find_children("CharacterWound*", "", true, false).size() > 0)
	for i in range(20):
		model.update_animation(0.05, 0.0)
	model.react_shoot()
	_expect_eq(model.state(), "shoot")
	_expect(model.play_die("head"))
	_expect_eq(model.state(), "die")
	var rag = model.make_ragdoll(Vector3.FORWARD * 3.0, Vector3(0.0, 1.0, 0.0))
	_expect(rag != null)
	_expect(CharacterScript.ragdoll_count() > 0)


func _test_hands() -> void:
	_case = "manos reales ligadas al arma"
	var vm = WeaponVmScript.new()
	_root.add_child(vm)
	await process_frame
	_expect(vm.set_weapon("assault_rifle"))
	for i in range(6):
		vm.advance(0.016)
		await process_frame
	var hands = vm.hands_viewmodel()
	_expect(hands != null)
	_expect(hands.has_hands())
	var arms: Node = hands.model_instance()
	_expect(arms != null)
	_expect(_first_mesh(arms) != null)
	var rifle_grip: Vector3 = hands.grip_for("right")
	_expect(vm.set_weapon("pistol"))
	for i in range(4):
		vm.advance(0.016)
		await process_frame
	_expect(not hands.grip_for("right").is_equal_approx(rifle_grip))
	_expect(vm.set_weapon("assault_rifle"))
	for i in range(4):
		vm.advance(0.016)
		await process_frame
	_expect(hands.wrist_position("right").is_equal_approx(hands.grip_for("right")))
	var before_recoil: Vector3 = hands.position
	vm.on_fired()
	for i in range(8):
		vm.advance(0.016)
		await process_frame
	_expect(hands.position.distance_to(before_recoil) > 0.001)
	var controller := Node3D.new()
	_root.add_child(controller)
	_expect(hands.attach_hand_to_controller("left", controller))
	_expect(hands.is_vr_attached("left"))
	_expect(controller.get_child_count() > 0)


func _test_npc_effects() -> void:
	_case = "disparo NPC con modelo, fogonazo, trazadora y audio"
	GoreFxScript.set_gore_enabled(false)
	var fake := _make_fake_player(Vector3(0.0, 0.0, -8.0), 1000.0, "FakePlayer")
	await process_frame
	await physics_frame
	var npc: Node3D = ArmedNpcScript.new()
	npc.call("apply_options", {
		"id": "anim_gunner", "role": "hostile", "difficulty": "hard", "weapon_id": "pistol",
		"seed": 5, "spread_scale": 0.0, "max_health": 100.0,
	})
	_root.add_child(npc)
	npc.global_position = Vector3(0.0, 0.0, 0.0)
	npc.set("target", fake)
	npc.set("auto_tick", false)
	npc.look_at(fake.global_position)
	_shots.clear()
	npc.connect("fired", Callable(self, "_on_fired"))
	await process_frame
	await physics_frame
	_expect(npc.get("weapon_system") != null, "sistema de armas del NPC")
	var weapon_model: Variant = npc.get("_weapon_model")
	_expect(weapon_model is Node3D, "modelo real de arma en NPC")
	if weapon_model is Node3D:
		_expect(_first_mesh(weapon_model as Node3D) != null, "malla del arma real")
	npc.call("tick", 0.3)
	npc.call("tick", 0.3)
	_expect(_shots.size() >= 1, "disparo emitido")
	_expect(_root.find_children("MuzzleFlash*", "", true, false).size() > 0, "fogonazo visible")
	_expect(_root.find_children("NpcTracer*", "", true, false).size() > 0, "trazadora visible")
	_expect(RecordedSfxScript.has_bank("shot_pistol"), "banco real de disparo de pistola disponible")
	var fire_audio := RecordedSfxScript.play_bank("shot_pistol", _root, Vector3.ZERO)
	_expect(fire_audio != null, "playback 3D de disparo posible")
	if fire_audio != null:
		fire_audio.free()

	_case = "crouch, gritos y voz"
	var model = CharacterScript.spawn(npc, "soldier")
	model.auto_drive = false
	model.update_animation(0.016, 0.0, false, true)
	_expect_eq(model.state(), "crouch")
	var voice = VoiceScript.new()
	_root.add_child(voice)
	_expect(voice.has_method("play_cue"))
	GoreFxScript.set_gore_enabled(null)


func _make_fake_player(position: Vector3, p_health: float, id: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = id
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 2.0, 0.8)
	shape.shape = box
	shape.position = Vector3(0.0, 1.0, 0.0)
	body.add_child(shape)
	var damageable = DamageableScript.new()
	damageable.name = "Damage"
	damageable.set("health", p_health)
	damageable.set("max_health", p_health)
	body.add_child(damageable)
	_root.add_child(body)
	return body


func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _first_mesh(child)
		if found != null:
			return found
	return null


func _count_audio(node: Node) -> int:
	var count: int = node.find_children("*", "AudioStreamPlayer3D", true, false).size()
	return count


func _on_fired(result: Dictionary) -> void:
	_shots.append(result)


func _on_hit_reacted(zone: String, _point: Vector3) -> void:
	_hits.append(zone)


func _expect(condition: bool, message: String = "") -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


func _expect_eq(actual, expected, message: String = "") -> void:
	_expect(actual == expected, "%s (esperado %s, obtenido %s)" % [message, str(expected), str(actual)])
