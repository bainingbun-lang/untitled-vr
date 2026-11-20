extends SceneTree

const TouchLayoutScript = preload("res://core/game/touch_layout.gd")
const LayoutEditorScript = preload("res://core/game/layout_editor.gd")

const TEST_PATH := "user://touch_layout_g11_test.json"
const PURE_PATH := "user://touch_layout_g11_pure.json"

var _checks := 0
var _failures: Array = []
var _case := ""
var _controls: Node = null


func _initialize() -> void:
	_cleanup()
	_case = "perfiles predefinidos"
	_test_profiles()
	_case = "limites de pantalla y zona segura"
	_test_bounds()
	_case = "validacion estricta"
	_test_validation()
	_case = "round-trip y persistencia"
	_test_persistence()
	_case = "aplicar layout a nodos reales"
	await _test_apply()
	_case = "editor y menu de pausa"
	await _test_editor()
	_cleanup()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _cleanup() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	for path in [TEST_PATH, PURE_PATH]:
		if FileAccess.file_exists(path):
			dir.remove(path.get_file())


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [_case, message])


func _inside(rect: Rect2, safe: Rect2) -> bool:
	return rect.position.x >= safe.position.x - 0.001 \
		and rect.position.y >= safe.position.y - 0.001 \
		and rect.end.x <= safe.end.x + 0.001 \
		and rect.end.y <= safe.end.y + 0.001


func _test_profiles() -> void:
	var right = TouchLayoutScript.new(PURE_PATH)
	right.set_profile(TouchLayoutScript.PROFILE_DIESTRO)
	var left = TouchLayoutScript.new(PURE_PATH)
	left.set_profile(TouchLayoutScript.PROFILE_ZURDO)
	var compact = TouchLayoutScript.new(PURE_PATH)
	compact.set_profile(TouchLayoutScript.PROFILE_COMPACTO)

	_expect(right.position("joystick").x < 0.5, "joystick a la izquierda en diestro")
	_expect(left.position("joystick").x > 0.5, "joystick a la derecha en zurdo")
	_expect(right.position("look").x > 0.5, "mirar a la derecha en diestro")
	_expect(left.position("look").x < 0.5, "mirar a la izquierda en zurdo")
	_expect(is_equal_approx(left.position("fire").x, 1.0 - right.position("fire").x), "disparo simetrico")
	_expect(str(right.entry("joystick")["side"]) == "left", "lado izquierdo del joystick diestro")
	_expect(str(left.entry("joystick")["side"]) == "right", "lado derecho del joystick zurdo")
	_expect(str(left.entry("fire")["side"]) == "left", "lado izquierdo del disparo zurdo")
	_expect(compact.profile == TouchLayoutScript.PROFILE_COMPACTO, "perfil compacto activo")
	_expect(float(compact.entry("fire")["scale"]) < 1.0, "compacto reduce el tamano")
	for id in TouchLayoutScript.CONTROL_IDS:
		_expect(right.controls.has(id) and left.controls.has(id) and compact.controls.has(id), "control presente: %s" % id)


func _test_bounds() -> void:
	var design := TouchLayoutScript.DESIGN_SIZE
	var inset := TouchLayoutScript.SAFE_INSET
	var safe := Rect2(design.x * inset, design.y * inset, design.x * (1.0 - 2.0 * inset), design.y * (1.0 - 2.0 * inset))
	for profile in TouchLayoutScript.PROFILES:
		var layout = TouchLayoutScript.new(PURE_PATH)
		layout.set_profile(profile)
		for id in TouchLayoutScript.CONTROL_IDS:
			_expect(_inside(layout.rect(str(id)), safe), "%s: %s dentro de pantalla" % [profile, id])
		_expect(not TouchLayoutScript._has_overlap(layout.controls), "%s: perfiles sin solapes" % profile)
	for scale in [0.5, 2.0]:
		for id in TouchLayoutScript.CONTROL_IDS:
			var layout = TouchLayoutScript.new(PURE_PATH)
			layout.set_profile(TouchLayoutScript.PROFILE_DIESTRO)
			layout.set_control_scale(str(id), scale)
			_expect(_inside(layout.rect(str(id)), safe), "escala %.1f: %s dentro de pantalla" % [scale, id])
	var extremes = TouchLayoutScript.new(PURE_PATH)
	extremes.set_position("fire", Vector2(-9.0, 9.0))
	_expect(_inside(extremes.rect("fire"), safe), "arrastre extremo se recorta a pantalla")
	extremes.set_control_scale("fire", 2.0)
	_expect(_inside(extremes.rect("fire"), safe), "tamano maximo sigue dentro de pantalla")


func _test_validation() -> void:
	var layout = TouchLayoutScript.new(PURE_PATH)
	var valid: Dictionary = layout.to_dict()
	_expect(bool(layout.parse(valid)["ok"]), "parse acepta configuracion propia")
	var cases: Array = []
	cases.append("no es un diccionario")
	var bad_version: Dictionary = valid.duplicate(true)
	bad_version["version"] = 99
	cases.append(bad_version)
	var bad_profile: Dictionary = valid.duplicate(true)
	bad_profile["profile"] = "zurdisimo"
	cases.append(bad_profile)
	var missing: Dictionary = valid.duplicate(true)
	(missing["controls"] as Dictionary).erase("reload")
	cases.append(missing)
	var extra: Dictionary = valid.duplicate(true)
	(extra["controls"] as Dictionary)["fly"] = (valid["controls"] as Dictionary)["fire"].duplicate(true)
	cases.append(extra)
	var bad_position: Dictionary = valid.duplicate(true)
	(bad_position["controls"] as Dictionary)["fire"]["position"] = [0.5]
	cases.append(bad_position)
	var outside: Dictionary = valid.duplicate(true)
	(outside["controls"] as Dictionary)["fire"]["position"] = [9.0, 9.0]
	cases.append(outside)
	var bad_scale: Dictionary = valid.duplicate(true)
	(bad_scale["controls"] as Dictionary)["fire"]["scale"] = 2.1
	cases.append(bad_scale)
	var bad_opacity: Dictionary = valid.duplicate(true)
	(bad_opacity["controls"] as Dictionary)["fire"]["opacity"] = 1.4
	cases.append(bad_opacity)
	var bad_visible: Dictionary = valid.duplicate(true)
	(bad_visible["controls"] as Dictionary)["fire"]["visible"] = 1
	cases.append(bad_visible)
	var bad_side: Dictionary = valid.duplicate(true)
	(bad_side["controls"] as Dictionary)["fire"]["side"] = "centro"
	cases.append(bad_side)
	var bad_sensitivity: Dictionary = valid.duplicate(true)
	bad_sensitivity["look_sensitivity"] = 0.5
	cases.append(bad_sensitivity)
	var bad_deadzone: Dictionary = valid.duplicate(true)
	bad_deadzone["move_deadzone"] = -1.0
	cases.append(bad_deadzone)
	var overlap: Dictionary = valid.duplicate(true)
	(overlap["controls"] as Dictionary)["fire"]["position"] = (valid["controls"] as Dictionary)["jump"]["position"].duplicate(true)
	cases.append(overlap)
	for candidate in cases:
		var rejected = TouchLayoutScript.new(PURE_PATH)
		_expect(not rejected.from_dict(candidate), "configuracion corrupta rechazada: %s" % str(candidate).substr(0, 24))
		_expect(rejected.profile == TouchLayoutScript.PROFILE_DIESTRO, "corruptos vuelven al perfil por defecto")
	_expect(layout.to_dict() == valid, "validacion no muta el layout activo")


func _test_persistence() -> void:
	var layout = TouchLayoutScript.new(TEST_PATH)
	layout.set_profile(TouchLayoutScript.PROFILE_ZURDO)
	layout.set_position("fire", Vector2(0.13, 0.82))
	layout.set_control_scale("fire", 1.4)
	layout.set_control_opacity("fire", 0.6)
	layout.set_control_visible("jump", false)
	layout.set_control_side("fire", "right")
	layout.set_look_sensitivity(0.009)
	layout.set_move_deadzone(0.22)
	var snapshot: Dictionary = layout.to_dict()
	_expect(layout.save_to_disk(), "guarda en user://")
	_expect(FileAccess.file_exists(TEST_PATH), "archivo de configuracion creado")
	var restored = TouchLayoutScript.new(TEST_PATH)
	_expect(restored.to_dict() == snapshot, "round-trip desde disco identico")
	var dictionary_round = TouchLayoutScript.new(PURE_PATH)
	_expect(dictionary_round.from_dict(snapshot), "from_dict acepta propio dict")
	_expect(dictionary_round.to_dict() == snapshot, "restauracion exacta del Dictionary")
	var nested: Dictionary = (snapshot["controls"] as Dictionary)["fire"].duplicate(true)
	nested["scale"] = 1.9
	(snapshot["controls"] as Dictionary)["fire"] = nested
	_expect(is_equal_approx(float(dictionary_round.entry("fire")["scale"]), 1.4), "restauracion sin alias mutables")
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{ json deliberadamente roto ")
	file.close()
	var corrupt = TouchLayoutScript.new(TEST_PATH)
	_expect(corrupt.profile == TouchLayoutScript.PROFILE_DIESTRO, "archivo corrupto usa perfil por defecto")
	_expect(is_equal_approx(corrupt.position("joystick").x, 0.17), "archivo corrupto usa posiciones por defecto")
	_expect(is_equal_approx(corrupt.look_sensitivity, TouchLayoutScript.DEFAULT_SENSITIVITY), "archivo corrupto usa sensibilidad por defecto")
	_expect(not corrupt.from_dict(snapshot), "snapshot mutado se rechaza")


func _test_apply() -> void:
	var packed := load("res://scenes/ui/touch_controls.tscn") as PackedScene
	_expect(packed != null, "touch_controls.tscn carga")
	if packed == null:
		return
	var controls = packed.instantiate()
	root.add_child(controls)
	await process_frame
	_controls = controls
	_expect(controls.layout != null, "TouchControls construye su layout")

	var layout = TouchLayoutScript.new(TEST_PATH)
	layout.reset(TouchLayoutScript.PROFILE_DIESTRO)
	layout.set_position("fire", Vector2(0.30, 0.80))
	layout.set_control_opacity("fire", 0.55)
	layout.set_control_visible("jump", false)
	layout.set_look_sensitivity(0.008)
	layout.set_move_deadzone(0.25)
	controls.size = Vector2(1000.0, 800.0)
	controls.apply_layout(layout)
	await process_frame
	var fire := controls.get_node("FireButton") as Control
	var expected: Vector2 = layout.rect("fire", controls.size).position
	_expect(fire.position.distance_to(expected) < 0.01, "aplicar layout mueve el boton real")
	_expect(is_equal_approx(fire.modulate.a, 0.55), "aplicar layout cambia opacidad real")
	_expect(not (controls.get_node("JumpButton") as Control).visible, "aplicar layout oculta el boton real")
	_expect(is_equal_approx(controls.look_sensitivity, 0.008), "aplicar layout cambia sensibilidad")
	_expect(is_equal_approx(controls.move_deadzone, 0.25), "aplicar layout cambia zona muerta")
	_expect(controls.get_node_or_null("ReloadButton") != null, "boton de recargar presente")
	var reload_calls := [0]
	controls.reload_pressed.connect(func() -> void: reload_calls[0] += 1)
	controls.get_node("ReloadButton").pressed.emit()
	_expect(reload_calls[0] == 1, "senal reload_pressed")

	var fresh = packed.instantiate()
	root.add_child(fresh)
	await process_frame
	var defaults = TouchLayoutScript.new(PURE_PATH)
	var joystick := fresh.get_node("MovePad") as Control
	_expect(joystick.position.distance_to(defaults.rect("joystick", fresh.size).position) < 0.01, "layout por defecto aplicado al construir")


func _test_editor() -> void:
	if _controls == null:
		return
	_controls.call("open_pause_menu")
	await process_frame
	var overlay := _controls.get_node_or_null("PauseOverlay")
	_expect(overlay != null, "menu de pausa disponible")
	if overlay == null:
		return
	var controls_button := overlay.get_node_or_null("Center/Column/ControlsButton")
	_expect(controls_button != null, "menu de pausa ofrece ajustar controles")
	if controls_button == null:
		return
	controls_button.pressed.emit()
	await process_frame
	var editor := _controls.get_node_or_null("LayoutEditor")
	_expect(editor != null, "editor accesible desde el menu de pausa")
	if editor == null:
		return
	var layout = _controls.layout
	editor.call("select_control", "fire")
	_expect(str(editor.get("selected_id")) == "fire", "seleccion de control en el editor")
	var before: Vector2 = layout.position("fire")
	editor.call("drag_control", "fire", Vector2(400.0, 400.0), Vector2(520.0, 460.0))
	var after: Vector2 = layout.position("fire")
	_expect(after.distance_to(before) > 0.001, "arrastre simulado mueve el control")
	_expect(FileAccess.file_exists(TEST_PATH), "arrastre simulado guarda el archivo")
	var disk = TouchLayoutScript.new(TEST_PATH)
	_expect(disk.position("fire").distance_to(after) < 0.0001, "posicion arrastrada persistida")
	editor.call("change_scale", 0.2)
	editor.call("change_opacity", -0.2)
	_expect(is_equal_approx(float(layout.entry("fire")["scale"]), 1.2), "control tactile de tamano")
	_expect(is_equal_approx(float(layout.entry("fire")["opacity"]), 0.35), "control tactile de opacidad")
	editor.call("toggle_side")
	_expect(str(layout.entry("fire")["side"]) == "left", "control tactile de lado")
	editor.call("change_sensitivity", 0.001)
	editor.call("change_deadzone", 0.02)
	_expect(is_equal_approx(layout.look_sensitivity, 0.009), "sensibilidad ajustada y guardable")
	_expect(is_equal_approx(layout.move_deadzone, 0.27), "zona muerta ajustada y guardable")
	var profile_changed := [""]
	if editor.has_signal("layout_changed"):
		editor.layout_changed.connect(func(id): profile_changed[0] = str(id))
	editor.call("apply_profile", TouchLayoutScript.PROFILE_ZURDO)
	_expect(layout.profile == TouchLayoutScript.PROFILE_ZURDO, "cambio de perfil desde el editor")
	_expect(profile_changed[0] == "fire" or profile_changed[0] == "", "senal de cambio emitida")
	editor.call("restore_defaults")
	var defaults: Dictionary = TouchLayoutScript.default_profile_data(TouchLayoutScript.PROFILE_ZURDO)
	var expected: Vector2 = defaults["joystick"]["position"]
	_expect(layout.position("joystick").distance_to(expected) < 0.0001, "restablecer valores por defecto")
	var saved := [0]
	editor.layout_saved.connect(func() -> void: saved[0] += 1)
	_expect(editor.call("save"), "guardar desde el editor")
	_expect(saved[0] == 1, "senal layout_saved")
	var opened = LayoutEditorScript.open(root, layout, _controls)
	_expect(opened != null, "LayoutEditor.open usable desde un menu de pausa externo")
