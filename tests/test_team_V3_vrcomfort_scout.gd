extends SceneTree

# SCOUT V3_vrcomfort: prueba de solo lectura que documenta el estado actual
# (lo que ya existe y reutilizable vs. los huecos que el implementador debe cubrir).

const RigScript = preload("res://core/vr/vr_rig.gd")
const ActionMapScript = preload("res://core/vr/vr_action_map.gd")
const BootstrapScript = preload("res://core/vr/vr_bootstrap.gd")

var _checks: int = 0
var _failures: Array = []


func _initialize() -> void:
	await process_frame
	_test_pure_logic_reutilizable()
	_test_huecos_actuales()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _test_pure_logic_reutilizable() -> void:
	# Giro por pasos exacto (vr_rig.gd:507 turn_delta)
	var snap := RigScript.turn_delta(1.0, "snap", 1.6, 45.0, 0.016, 0.2, true)
	_expect(is_equal_approx(snap, -deg_to_rad(45.0)), "snap 45 exacto a la derecha-negativo")
	_expect(is_equal_approx(RigScript.turn_delta(-1.0, "snap", 1.6, 45.0, 0.016, 0.2, true), deg_to_rad(45.0)), "snap 45 exacto al otro lado")
	_expect(RigScript.turn_delta(1.0, "snap", 1.6, 45.0, 0.016, 0.2, false) == 0.0, "snap bloqueado durante cooldown")
	_expect(RigScript.turn_delta(0.5, "snap", 1.6, 45.0, 0.016, 0.2, true) == 0.0, "snap ignorado bajo el umbral 0.7")
	# Giro suave proporcional (vr_rig.gd:517)
	var smooth := RigScript.turn_delta(1.0, "smooth", 2.0, 30.0, 0.5, 0.2, true)
	_expect(is_equal_approx(smooth, -1.0 * 2.0 * 0.5), "smooth proporcional al stick y delta")
	_expect(RigScript.turn_delta(0.1, "smooth", 2.0, 30.0, 0.5, 0.2, true) == 0.0, "smooth respeta deadzone")
	# Locomocion relativa a la cabeza (vr_rig.gd:495 locomotion_velocity)
	var vel := RigScript.locomotion_velocity(Vector2(0.0, -1.0), Vector3(0.0, 0.0, -1.0), 2.2, 0.2)
	_expect(vel.is_equal_approx(Vector3(0.0, 0.0, -2.2)), "stick arriba avanza hacia el forward de la cabeza")
	_expect(RigScript.locomotion_velocity(Vector2(0.1, 0.0), Vector3(0.0, 0.0, -1.0), 2.2, 0.2).is_equal_approx(Vector3.ZERO), "deadzone frena")
	# Viñeta sube con velocidad angular (vr_rig.gd:540 compute_vignette)
	_expect(RigScript.compute_vignette(0.0, 0.0) == 0.0, "viñeta en reposo es 0")
	_expect(RigScript.compute_vignette(0.0, 1.0) < RigScript.compute_vignette(0.0, 2.0), "viñeta monotona con velocidad angular")
	_expect(RigScript.compute_vignette(0.0, 2.0) == 1.0, "viñeta satura en la referencia angular")
	_expect(RigScript.compute_vignette(3.0, 0.0) == 1.0, "viñeta satura en la referencia lineal")
	# Rotacion alrededor del pivot de la cabeza (vr_rig.gd:524)
	var pivot := Vector3(1.0, 1.6, 2.0)
	var xform := Transform3D(Basis.IDENTITY, pivot + Vector3(0.0, 0.0, 1.0))
	var rotated := RigScript.rotate_around_y(xform, pivot, deg_to_rad(90.0))
	_expect(rotated.origin.distance_to(pivot + Vector3(1.0, 0.0, 0.0)) < 0.0001, "rotate_around_y gira alrededor de la cabeza")
	# Teletransporte: solo desplazamiento horizontal (vr_rig.gd:532)
	var tp := RigScript.translation_for_teleport(Transform3D(Basis.IDENTITY, Vector3(0.0, 1.6, 0.0)), Vector3(0.0, 1.6, 0.0), Vector3(3.0, 0.0, 4.0))
	_expect(tp.origin.is_equal_approx(Vector3(3.0, 1.6, 4.0)), "teleport conserva la altura de la cabeza")


func _test_huecos_actuales() -> void:
	# Archivos que el brief permite crear y aun no existen
	_expect(not ResourceLoader.exists("res://core/vr/vr_comfort.gd"), "hueco: falta core/vr/vr_comfort.gd")
	_expect(not ResourceLoader.exists("res://core/vr/vr_settings_panel.gd"), "hueco: falta core/vr/vr_settings_panel.gd")
	_expect(not ResourceLoader.exists("res://core/game/game_settings.gd"), "hueco: no existe core/game/game_settings.gd (persistencia propia en user://)")
	_expect(not ResourceLoader.exists("res://tests/test_vr_comfort.gd"), "hueco: falta tests/test_vr_comfort.gd")
	# VrRig no tiene aun: modo sentado, recentrado, perfil de confort, intensidad de viñeta ajustable
	var rig = RigScript.new()
	_expect(not rig.has_method("recenter"), "hueco: VrRig no tiene recentrado (boton de menu largo)")
	_expect(not rig.has_method("set_seated_mode"), "hueco: VrRig no tiene modo sentado")
	_expect(not rig.has_method("apply_comfort_profile"), "hueco: VrRig no consume un perfil de confort")
	_expect(rig.get("vignette_intensity") == null, "hueco: la intensidad de la viñeta no es ajustable (alpha fijo 0.85 en vr_rig.gd:475)")
	_expect(not rig.has_method("locomotion_velocity_hand"), "hueco: locomocion solo relativa a la cabeza, no a la mano")
	rig.free()
	# Action map: no hay accion de correr y el click del stick derecho ya es teleport
	_expect(not ActionMapScript.ACTIONS.has("run"), "hueco: sin accion 'run' (click de stick) en vr_action_map.gd:5")
	var quest: Dictionary = ActionMapScript.new("quest").profile()["bindings"]
	_expect(str((quest["teleport"] as Dictionary)["id"]) == "thumbstick_press", "conflicto: teleport ocupa el click del stick derecho; 'run' debe ir en el izquierdo")
	# Buses de audio: solo Master en project.godot -> volumen por bus exige crear buses en runtime
	_expect(AudioServer.get_bus_count() == 1, "solo existe el bus Master; volumen por bus (armas/voces/ambiente) requiere buses dinamicos")
	# Hooks ya existentes para recentrado y pausa al quitarse el casco (vr_bootstrap.gd:158,163)
	var boot = BootstrapScript.new()
	_expect(boot.has_method("_on_pose_recentered"), "hook disponible: pose_recentered en VrBootstrap")
	_expect(boot.has_method("_on_user_presence_changed"), "hook disponible: user_presence_changed (casco quitado) pausa/reanuda")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
