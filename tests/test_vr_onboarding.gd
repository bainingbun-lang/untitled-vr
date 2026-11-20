extends SceneTree

const OnbScript = preload("res://core/vr/vr_onboarding.gd")
const WsScript = preload("res://core/game/weapon_system.gd")
const HolstersScript = preload("res://core/vr/vr_holsters.gd")
const DbScript = preload("res://core/game/weapon_db.gd")

var _n := 0
var _fail := 0


func _expect(c: bool, m: String) -> void:
	_n += 1
	if not c:
		_fail += 1
		print("FAIL: " + m)


func _initialize() -> void:
	await process_frame
	var head := Transform3D(Basis.IDENTITY, Vector3(0, 1.7, 0))
	_expect(OnbScript.is_looking_at_wrist(head, Vector3(0.0, 1.5, -0.4)), "mirar la muñeca delante y abajo")
	_expect(not OnbScript.is_looking_at_wrist(head, Vector3(0.0, 1.5, 0.4)), "muñeca a la espalda no cuenta")
	_expect(not OnbScript.is_looking_at_wrist(head, Vector3(0.0, 1.5, -2.0)), "muñeca lejos no cuenta")
	_expect(not OnbScript.is_looking_at_wrist(head, Vector3(0.6, 1.6, -0.1)), "muñeca fuera del cono de vision")
	var ws = WsScript.new()
	var onb = OnbScript.new()
	root.add_child(onb)
	onb.configure(HolstersScript.new(), ws, ["pistol", "submachine_gun", "assault_rifle", "shotgun"])
	_expect(onb.slot_nodes.size() == 5, "5 zonas de cuerpo con arma visible")
	var models := 0
	for slot in ["hip", "hip_off", "back", "back2"]:
		var model = onb.slot_nodes[slot].get_child(0)
		if model.has_method("has_model") and bool(model.call("has_model")):
			models += 1
	_expect(models == 4, "pistola, subfusil, rifle y escopeta con su modelo descargado: %d" % models)
	var mags := 0
	for c in onb.slot_nodes["chest"].get_children():
		if c is MeshInstance3D and c.mesh is BoxMesh:
			mags += 1
	_expect(mags == 3, "cargadores en el pecho")
	var poses := {"left": Transform3D(Basis.IDENTITY, Vector3(0.5, 1.2, -0.3)), "right": Transform3D(Basis.IDENTITY, Vector3(0.5, 1.2, -0.3))}
	onb.tick(0.016, head, poses, {})
	var hip: Vector3 = onb.slot_world("hip", head)
	var off: Vector3 = onb.slot_world("hip_off", head)
	_expect(hip.x > 0.0 and off.x < 0.0 and absf(hip.x + off.x) < 0.001, "pistola en la cadera dominante y subfusil en la otra")
	_expect(onb.slot_world("back", head).z > 0.1 and onb.slot_world("chest", head).z < 0.0, "armas largas a la espalda, cargadores delante")
	_expect(onb.glow["right"] == "", "sin mano cerca no hay resplandor")
	poses["right"] = Transform3D(Basis.IDENTITY, hip + Vector3(0.03, 0.02, 0))
	onb.tick(0.016, head, poses, {})
	_expect(onb.glow["right"] == "hip" and onb.glow_nodes["hip"].visible and not onb.glow_nodes["back"].visible, "resplandor en la funda cercana")
	_expect(onb.slot_nodes["hip"].global_position.is_equal_approx(hip), "el arma sigue al cuerpo")
	var moved := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(2, 1.7, 0))
	onb.tick(0.016, moved, poses, {})
	_expect(onb.slot_nodes["hip"].global_position.distance_to(Vector3(2, 1.7, 0)) < 1.0, "las fundas giran y se mueven con el jugador")
	# menu de muñeca
	var wrist_pose := Transform3D(Basis.IDENTITY, Vector3(-0.1, 1.4, -0.35))
	poses = {"left": wrist_pose, "right": Transform3D(Basis.IDENTITY, Vector3(0.4, 1.4, -0.3))}
	onb.tick(0.016, head, poses, {})
	_expect(onb.wrist_visible and onb.wrist_menu.is_open, "el menu de muñeca aparece al mirarla")
	var labels: Array = []
	for b in onb.wrist_menu.buttons:
		labels.append(str(b["label"]))
	_expect(labels.size() == 5 and str(labels[0]).begins_with("Pistola ") and str(labels[0]).contains("/") and labels.has("TUTORIAL"), "inventario con municion y reserva: %s" % str(labels))
	var equipped: Array = []
	onb.equip_requested.connect(func(id): equipped.append(id))
	onb.wrist_menu.button_pressed.emit("equip:assault_rifle")
	_expect(equipped == ["assault_rifle"], "boton equipar")
	poses["left"] = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.5, 0.5))
	onb.tick(0.016, head, poses, {})
	_expect(not onb.wrist_visible and not onb.wrist_menu.panel_root.visible, "se oculta al dejar de mirar")
	# tutorial
	_expect(onb.tutorial_open and onb.tutorial_panel.visible, "el tutorial se muestra al empezar")
	var lines := 0
	for child in onb.tutorial_panel.get_children():
		if child is Label3D and str(child.text).begins_with(str(lines + 1) + "."):
			lines += 1
	_expect(lines == 5 and OnbScript.TUTORIAL_LINES.size() == 5, "tutorial de 5 lineas")
	var closed := [0]
	onb.tutorial_closed.connect(func(): closed[0] += 1)
	onb.tick(0.016, head, poses, {"right": 1.0})
	_expect(not onb.tutorial_open and closed[0] == 1, "el gatillo cierra el tutorial")
	onb.tick(0.016, head, poses, {"right": 1.0})
	_expect(closed[0] == 1, "no se cierra dos veces")
	onb.wrist_menu.button_pressed.emit("tutorial")
	_expect(onb.tutorial_open, "el boton Tutorial lo vuelve a abrir")
	onb.free()
	ws.free()
	if _fail == 0:
		print("PASS (%d assertions)" % _n)
		quit(0)
	else:
		print("FAIL (%d assertions, %d failures)" % [_n, _fail])
		quit(1)
