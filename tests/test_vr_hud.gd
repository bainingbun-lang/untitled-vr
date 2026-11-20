extends SceneTree

const VrHudScript = preload("res://core/vr/vr_hud.gd")
const VrMenuScript = preload("res://core/vr/vr_menu.gd")
const VrPerformanceScript = preload("res://core/vr/vr_performance.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""


func _init() -> void:
	await process_frame
	_case = "formato de municion y vida"
	_test_formats()
	_case = "aviso de dano direccional"
	_test_damage_direction()
	_case = "puntero laser golpea boton correcto"
	_test_menu_pointer()
	_case = "presupuesto adaptativo con histeresis"
	_test_adaptive_budget()
	_case = "sin OpenXR no crashea"
	_test_no_openxr()

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _test_formats() -> void:
	_expect(VrHudScript.format_weapon_ammo(12, 30) == "12/30", "formato arma 12/30")
	_expect(VrHudScript.format_weapon_ammo(12, 30, 90) == "12/30 | 90", "formato arma con reserva")
	_expect(VrHudScript.format_magazine_ammo(7) == "7", "formato cargador")
	_expect(VrHudScript.format_magazine_ammo(0, true) == "INF", "formato cargador infinito")
	_expect(VrHudScript.format_health(75.0, 100.0) == "75", "formato vida 75")
	_expect(VrHudScript.format_health(0.0, 100.0) == "0", "formato vida 0")
	_expect(VrHudScript.format_health(33.0, 100.0) == "33", "formato vida 33")
	var ratio := VrHudScript.compute_health_ratio(50.0, 200.0)
	_expect(absf(ratio - 0.25) < 0.0001, "ratio de vida 0.25")
	_expect(VrHudScript.compute_health_ratio(10.0, 0.0) == 0.0, "ratio con maximo 0 seguro")
	var reload := VrHudScript.format_reload(0.5, true)
	_expect(reload.find("50") >= 0, "indicador de recarga muestra progreso")
	_expect(VrHudScript.format_reload(0.5, false) == "", "sin recarga no muestra texto")


func _test_damage_direction() -> void:
	var pos := Vector3.ZERO
	var forward := Vector3(0, 0, -1)
	var right := Vector3(1, 0, 0)

	var front := VrHudScript.compute_damage_angle(forward, right, pos, Vector3(0, 0, -5))
	_expect(absf(front) < 0.001, "impacto frontal angulo ~0")

	var right_hit := VrHudScript.compute_damage_angle(forward, right, pos, Vector3(5, 0, 0))
	_expect(absf(right_hit - PI * 0.5) < 0.001, "impacto derecha angulo ~PI/2")

	var back := VrHudScript.compute_damage_angle(forward, right, pos, Vector3(0, 0, 5))
	_expect(absf(absf(back) - PI) < 0.001, "impacto trasero angulo ~PI")

	var left_hit := VrHudScript.compute_damage_angle(forward, right, pos, Vector3(-5, 0, 0))
	_expect(absf(left_hit + PI * 0.5) < 0.001, "impacto izquierda angulo ~-PI/2")

	var same_point := VrHudScript.compute_damage_angle(forward, right, pos, pos)
	_expect(same_point == 0.0, "impacto en el mismo punto devuelve 0")

	var elevated := VrHudScript.compute_damage_angle(forward, right, pos, Vector3(5, 3, 0))
	_expect(absf(elevated - PI * 0.5) < 0.001, "altura no altera angulo horizontal")


func _test_menu_pointer() -> void:
	var buttons := [
		{"id": "start", "label": "Start", "rect": Rect2(-0.2, 0.02, 0.18, 0.08)},
		{"id": "quit", "label": "Quit", "rect": Rect2(0.02, 0.02, 0.18, 0.08)},
		{"id": "resume", "label": "Resume", "rect": Rect2(-0.09, -0.12, 0.18, 0.08)},
	]
	var panel := VrMenuScript.placement_transform(Vector3(0, 1.6, 0), Vector3(0, 0, -1), 1.5)
	var panel_center: Vector3 = panel.origin
	var origin := Vector3(0, 1.6, 0)

	var start_hit := VrMenuScript.raycast_buttons(origin, Vector3(panel_center.x - 0.11, panel_center.y + 0.06, panel_center.z) - origin, panel, Vector2(0.6, 0.35), buttons)
	_expect(bool(start_hit.get("hit", false)), "rayo golpea un boton")
	_expect(str(start_hit.get("button_id", "")) == "start", "golpea boton start")

	var quit_hit := VrMenuScript.raycast_buttons(origin, Vector3(panel_center.x + 0.11, panel_center.y + 0.06, panel_center.z) - origin, panel, Vector2(0.6, 0.35), buttons)
	_expect(str(quit_hit.get("button_id", "")) == "quit", "golpea boton quit")

	var resume_hit := VrMenuScript.raycast_buttons(origin, Vector3(panel_center.x, panel_center.y - 0.08, panel_center.z) - origin, panel, Vector2(0.6, 0.35), buttons)
	_expect(str(resume_hit.get("button_id", "")) == "resume", "golpea boton resume")

	var miss := VrMenuScript.raycast_buttons(origin, Vector3(panel_center.x + 0.25, panel_center.y + 0.16, panel_center.z) - origin, panel, Vector2(0.6, 0.35), buttons)
	_expect(not bool(miss.get("hit", false)), "rayo fuera no golpea boton")
	_expect(str(miss.get("button_id", "")) == "", "sin boton en miss")

	var back := VrMenuScript.raycast_buttons(Vector3(0, 1.6, -2.0), Vector3(0, 0, -1), panel, Vector2(0.6, 0.35), buttons)
	_expect(not bool(back.get("hit", false)), "rayo que apunta atras no golpea")

	var placed := VrMenuScript.placement_transform(Vector3(1, 1.6, 2), Vector3(1, 0, 0), 1.2, -0.1)
	var to_panel: Vector3 = placed.origin - Vector3(1, 1.6, 2)
	_expect(absf(to_panel.length() - 1.2) < 0.05 or absf(Vector2(to_panel.x, to_panel.z).length() - 1.2) < 0.05, "panel se coloca a distancia confortable")
	_expect(placed.origin.y < 1.6, "panel aplica offset de altura")


func _test_adaptive_budget() -> void:
	var perf = VrPerformanceScript.new(VrPerformanceScript.MODE_72)
	var initial_level: int = int(perf.degrade_level)
	var initial_particles: int = int(perf.profile.get("particles", 0))
	for i in range(12):
		perf.observe_frame(16.5)
	_expect(int(perf.degrade_level) > initial_level, "baja calidad tras frames lentos sostenidos")
	_expect(int(perf.profile.get("particles", 9999)) < initial_particles, "reduce presupuesto de particulas al degradar")

	var mid_level: int = int(perf.degrade_level)
	perf.observe_frame(11.0)
	_expect(int(perf.degrade_level) == mid_level, "no sube calidad inmediatamente (histeresis)")
	for j in range(30):
		perf.observe_frame(10.5)
	_expect(int(perf.degrade_level) < mid_level, "sube calidad tras frames rapidos sostenidos")

	var low_particles: int = int(perf.profile.get("particles", 0))
	perf.observe_frame(14.2)
	_expect(int(perf.profile.get("particles", -1)) == low_particles, "zona media no provoca flapping")
	_expect(VrPerformanceScript.is_below_72fps(14.0), "14ms detectado bajo 72fps")
	_expect(not VrPerformanceScript.is_below_72fps(13.5), "13.5ms dentro de 72fps")

	var p72: Dictionary = VrPerformanceScript.profile_for_mode(VrPerformanceScript.MODE_72)
	var p90: Dictionary = VrPerformanceScript.profile_for_mode(VrPerformanceScript.MODE_90)
	_expect(int(p72.get("refresh_hz", 0)) == 72, "perfil 72Hz")
	_expect(int(p90.get("refresh_hz", 0)) == 90, "perfil 90Hz")
	_expect(p90.has("msaa") and p90.has("foveation") and p90.has("render_scale") and p90.has("shadow_distance"), "perfil contiene ajustes de calidad")
	perf.free()


func _test_no_openxr() -> void:
	var hud = VrHudScript.new()
	_expect(hud.build(), "hud construye sin OpenXR")
	hud.set_ammo(8, 12, 40, false)
	hud.set_health(55.0, 100.0)
	hud.register_damage(Vector3.FORWARD, Vector3.RIGHT, Vector3.ZERO, Vector3(1, 0, 0), 10.0)
	hud.decay_vignette(0.5)
	hud.set_reload(true, 0.25)
	_expect(hud.weapon_ammo_label != null, "hud crea contador de arma")
	_expect(hud.health_label != null, "hud crea etiqueta de vida")
	hud.free()

	var menu = VrMenuScript.new()
	menu.set_buttons([{"id": "start", "label": "Start", "rect": Rect2(-0.1, -0.05, 0.2, 0.1)}])
	_expect(menu.build(), "menu construye sin OpenXR")
	menu.open_in_front(Vector3.ZERO, Vector3.FORWARD)
	var pressed := menu.try_press(Vector3(0, 0, 0.5), Vector3(0, 0, -1), true)
	_expect(pressed == "start" or pressed == "", "menu procesa puntero sin crashear")
	menu.close_menu()
	menu.free()

	var perf = VrPerformanceScript.new(VrPerformanceScript.MODE_90)
	_expect(perf.build() == true, "performance build no crashea sin OpenXR")
	perf.observe_frame(20.0)
	perf.observe_frame(9.0)
	var info: Dictionary = perf.current_profile()
	_expect(info.has("particles") and info.has("npcs") and info.has("decals"), "perfil adaptativo disponible sin OpenXR")
	perf.free()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [_case, message])
