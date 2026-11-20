extends SceneTree

const MenuScene = preload("res://scenes/menu/main_menu.tscn")
const SessionScript = preload("res://core/game/game_session.gd")
const ValidatorScript = preload("res://core/maps/map_validator.gd")

var _checks := 0
var _failures: Array = []
var _case := ""


func _initialize() -> void:
	var menu: Control = MenuScene.instantiate()
	root.add_child(menu)
	await process_frame

	_case = "menu principal"
	var title: Label = menu.get_node_or_null("Margin/Column/Title") as Label
	_expect(title != null and title.text == "UNTITLED", "titulo UNTITLED presente")
	var play: Button = menu.get_node_or_null("Margin/Column/PlayButton") as Button
	_expect(play != null, "boton PLAY construido")
	_expect(play != null and play.custom_minimum_size.y >= 200.0, "PLAY apto para tactil (>=200px)")
	_expect(play != null and play.get_theme_font_size("font_size") >= 56, "PLAY con tipografia 56+")
	var gore: CheckButton = menu.get_node_or_null("Margin/Column/GoreCheck") as CheckButton
	_expect(gore != null and gore.custom_minimum_size.y >= 200.0, "interruptor Gore apto para tactil")

	_case = "gore on/off"
	gore.set_pressed(false)
	_expect(not SessionScript.gore_enabled, "Gore OFF desactiva gore_enabled")
	gore.set_pressed(true)
	_expect(SessionScript.gore_enabled, "Gore ON activa gore_enabled")

	_case = "PLAY muestra mapas"
	play.pressed.emit()
	await process_frame
	var screen: Control = menu.get_node_or_null("MapSelectScreen") as Control
	_expect(screen != null, "pantalla de mapas construida")
	_expect(screen != null and screen.visible, "PLAY hace visible la pantalla de mapas")
	_expect(not (menu.get_node("Margin") as Control).visible, "PLAY oculta el menu principal")

	_case = "mapas por defecto"
	var defaults: Array = screen.call("default_maps")
	_expect(defaults.size() == 3, "hay tres mapas generados por defecto")
	var validator := ValidatorScript.new()
	for meta in defaults:
		var validation: Dictionary = validator.validate(meta)
		_expect(
			int(validation.get("status", 99)) <= ValidatorScript.Status.COMPATIBLE_WITH_WARNINGS,
			"mapa por defecto valido: %s (%s)"
			% [str((meta as Dictionary).get("id", "")), str(validation.get("errors", []))]
		)

	_case = "JUGAR sin configurar"
	var seen_default: Array = []
	SessionScript.start_override = func(meta: Dictionary) -> void: seen_default.append(meta.duplicate(true))
	var play_default: Button = screen.get_node_or_null("Margin/Column/PlayButton") as Button
	_expect(play_default != null, "boton JUGAR presente")
	play_default.pressed.emit()
	_expect(seen_default.size() == 1, "JUGAR sin configurar llama a start una vez")
	if seen_default.size() == 1:
		var started_default: Dictionary = seen_default[0]
		var default_validation: Dictionary = validator.validate(started_default)
		_expect(
			int(default_validation.get("status", 99)) <= ValidatorScript.Status.COMPATIBLE_WITH_WARNINGS,
			"JUGAR sin configurar pasa una meta valida"
		)
	SessionScript.start_override = Callable()

	_case = "generar mapa"
	var random_check: CheckButton = screen.get_node_or_null("Margin/Column/GeneratePanel/RandomSeedCheck") as CheckButton
	var seed_spin: SpinBox = screen.get_node_or_null("Margin/Column/GeneratePanel/SeedSpin") as SpinBox
	var generate_button: Button = screen.get_node_or_null("Margin/Column/GeneratePanel/GenerateButton") as Button
	_expect(random_check != null and random_check.button_pressed, "la semilla es aleatoria por defecto")
	_expect(generate_button != null and generate_button.custom_minimum_size.y >= 200.0, "GENERAR apto para tactil")
	random_check.set_pressed(false)
	seed_spin.value = 4242.0
	generate_button.pressed.emit()
	var first: Dictionary = screen.get("generated_meta")
	_expect(bool(first.get("ok", false)), "Generar produce una meta valida")
	_expect(int(first.get("seed", -1)) == 4242, "Generar conserva la semilla elegida")
	var first_validation: Dictionary = validator.validate(first)
	_expect(
		int(first_validation.get("status", 99)) <= ValidatorScript.Status.COMPATIBLE_WITH_WARNINGS,
		"la meta generada pasa MapValidator"
	)
	generate_button.pressed.emit()
	var second: Dictionary = screen.get("generated_meta")
	_expect(str(first) == str(second), "la misma semilla produce el mismo mapa")
	seed_spin.value = 9999.0
	generate_button.pressed.emit()
	_expect(str(screen.get("generated_meta")) != str(first), "semillas distintas producen mapas distintos")
	seed_spin.value = 4242.0
	generate_button.pressed.emit()

	_case = "JUGAR con configuracion"
	var seen_generated: Array = []
	SessionScript.start_override = func(meta: Dictionary) -> void: seen_generated.append(meta.duplicate(true))
	play_default.pressed.emit()
	_expect(seen_generated.size() == 1, "JUGAR con configuracion llama a start una vez")
	if seen_generated.size() == 1:
		var started: Dictionary = seen_generated[0]
		var started_validation: Dictionary = validator.validate(started)
		_expect(
			int(started_validation.get("status", 99)) <= ValidatorScript.Status.COMPATIBLE_WITH_WARNINGS,
			"JUGAR con configuracion pasa una meta valida"
		)
		_expect(int(started.get("seed", -1)) == 4242, "JUGAR usa la semilla generada")
	SessionScript.start_override = Callable()

	_case = "deteccion de plataforma"
	var platform: String = SessionScript.detect_platform()
	_expect(platform in ["android", "pc", "vr"], "detect_platform devuelve android/pc/vr: %s" % platform)

	SessionScript.gore_enabled = true
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])
