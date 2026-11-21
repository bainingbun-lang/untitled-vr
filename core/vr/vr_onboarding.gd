class_name VrOnboarding
extends Node3D

# Onboarding diegetico en VR: armas en el cuerpo (fundas con resplandor), menu de muñeca
# con inventario y panel de tutorial. Sin HUD plano; la logica de zonas/mirada es estatica.

signal tutorial_closed
signal equip_requested(weapon_id: String)
signal tutorial_requested

const DbScript = preload("res://core/game/weapon_db.gd")
const ViewmodelScript = preload("res://core/game/weapon_viewmodel.gd")
const HolstersScript = preload("res://core/vr/vr_holsters.gd")
const MenuScript = preload("res://core/vr/vr_menu.gd")

const TUTORIAL_LINES: Array = [
	"1. AGARRAR: lleva la mano a la funda (cadera, espalda) y aprieta AGARRE",
	"2. DISPARAR: gatillo con la mano del arma; la otra mano ayuda a apuntar",
	"3. RECARGAR: suelta el cargador, coge otro del pecho, inserta y monta",
	"4. MOVERTE: stick izquierdo camina, stick derecho gira",
	"5. MUÑECA IZQUIERDA: mírala para ver el inventario o recalibrar",
]
const TUTORIAL_AUTO_CLOSE := 8.0
const WRIST_MAX_DISTANCE := 0.65
const WRIST_MAX_ANGLE := 0.75
const TRIGGER_ON := 0.6
# slot -> [arma, desplazamiento extra respecto a la funda base, inclinacion X en grados]
const DISPLAY: Dictionary = {
	"hip": {"base": "hip", "weapon": "pistol", "extra": Vector3.ZERO, "tilt": -90.0, "mirror": false},
	"hip_off": {"base": "hip", "weapon": "submachine_gun", "extra": Vector3.ZERO, "tilt": -90.0, "mirror": true},
	"back": {"base": "back", "weapon": "assault_rifle", "extra": Vector3(-0.1, 0.0, 0.0), "tilt": 62.0, "mirror": false},
	"back2": {"base": "back", "weapon": "shotgun", "extra": Vector3(0.1, 0.0, 0.0), "tilt": 62.0, "mirror": false},
	"chest": {"base": "chest", "weapon": "", "extra": Vector3.ZERO, "tilt": 0.0, "mirror": false},
}

var holsters = null
var dominant: String = "right"
var weapon_system: Node = null
var slot_nodes: Dictionary = {}
var glow_nodes: Dictionary = {}
var glow: Dictionary = {"left": "", "right": ""}
var wrist_menu = null
var wrist_visible: bool = false
var tutorial_panel: Node3D = null
var tutorial_open: bool = false
var weapon_rows: Array = []
var _trigger_was: Dictionary = {"left": false, "right": false}
var _tutorial_placed: bool = false
var _tutorial_age: float = 0.0


func configure(p_holsters, p_weapon_system: Node, weapon_ids: Array, p_dominant: String = "right") -> void:
	holsters = p_holsters if p_holsters != null else HolstersScript.new()
	weapon_system = p_weapon_system
	dominant = p_dominant
	weapon_rows = weapon_ids.duplicate()
	if holsters.has_method("set_eye_height"):
		var cal := preload("res://core/vr/vr_calibration.gd").new()
		cal.load_profile()
		if cal.profile.has("eye_height"):
			holsters.set_eye_height(float(cal.profile["eye_height"]))
	_build_slots()
	_build_wrist_menu()
	_build_tutorial()


# --- logica pura ---

static func yaw_only(head: Transform3D) -> Transform3D:
	var forward := -head.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.000001:
		forward = Vector3.FORWARD
	return Transform3D(Basis.looking_at(forward.normalized(), Vector3.UP), head.origin)


# Mirar la muñeca: cerca de la cabeza y dentro de un cono de vision.
static func is_looking_at_wrist(head: Transform3D, wrist: Vector3) -> bool:
	var to_wrist: Vector3 = wrist - head.origin
	var distance: float = to_wrist.length()
	if distance > WRIST_MAX_DISTANCE or distance < 0.05:
		return false
	return (-head.basis.z).angle_to(to_wrist / distance) <= WRIST_MAX_ANGLE


func slot_world(slot: String, head: Transform3D) -> Vector3:
	var spec: Dictionary = DISPLAY[slot]
	holsters.set_head_pose(yaw_only(head))
	var base: Vector3 = holsters.slot_position(str(spec["base"]))
	var local: Vector3 = base - head.origin
	if bool(spec["mirror"]):
		local.x = -local.x
	var yaw := yaw_only(head)
	return head.origin + local + yaw.basis * (spec["extra"] as Vector3)


func nearest_display_slot(hand_position: Vector3, head: Transform3D, radius: float = 0.16) -> String:
	var best := ""
	var best_distance := 1.0e9
	for slot in DISPLAY.keys():
		var distance: float = hand_position.distance_to(slot_world(str(slot), head))
		if distance < best_distance:
			best_distance = distance
			best = str(slot)
	return best if best_distance <= radius else ""


# --- construccion ---

func _build_slots() -> void:
	for slot in DISPLAY.keys():
		var spec: Dictionary = DISPLAY[slot]
		var anchor := Node3D.new()
		anchor.name = "Slot_" + str(slot)
		add_child(anchor)
		var weapon: String = str(spec["weapon"])
		if weapon.is_empty():
			for i in 3:
				var mag := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(0.025, 0.1, 0.05)
				mag.mesh = box
				mag.position.x = (i - 1) * 0.045
				mag.material_override = _flat(Color(0.12, 0.12, 0.13))
				anchor.add_child(mag)
		else:
			var model = ViewmodelScript.new()
			anchor.add_child(model)
			model.call("set_weapon", weapon)
			model.call("attach_to", anchor)
			model.set_process(false)
			if model.is_instance_valid(model.get_node_or_null("Motion/Rig")):
				model.get_node("Motion/Rig").rotation_degrees = Vector3(float(spec["tilt"]), 0.0, 0.0)
		slot_nodes[slot] = anchor
		var halo := MeshInstance3D.new()
		halo.name = "Glow_" + str(slot)
		var sphere := SphereMesh.new()
		sphere.radius = 0.1
		sphere.height = 0.2
		halo.mesh = sphere
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.4, 0.85, 1.0, 0.22)
		halo.material_override = material
		halo.visible = false
		anchor.add_child(halo)
		glow_nodes[slot] = halo


func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


func _build_wrist_menu() -> void:
	wrist_menu = MenuScript.new()
	wrist_menu.name = "WristMenu"
	wrist_menu.panel_size = Vector2(0.3, 0.26)
	add_child(wrist_menu)
	wrist_menu.set_buttons(wrist_buttons())
	wrist_menu.build()
	wrist_menu.is_open = false
	wrist_menu.panel_root.visible = false
	wrist_menu.button_pressed.connect(_on_wrist_button)


func wrist_buttons() -> Array:
	var buttons: Array = []
	var row := 0
	for id in weapon_rows:
		buttons.append({"id": "equip:" + str(id), "label": _row_label(str(id)), "rect": Rect2(-0.14, 0.1 - row * 0.045, 0.28, 0.04)})
		row += 1
	buttons.append({"id": "tutorial", "label": "TUTORIAL", "rect": Rect2(-0.14, 0.1 - row * 0.045, 0.28, 0.04)})
	return buttons


func _row_label(id: String) -> String:
	var def: Dictionary = DbScript.get_def(id)
	var label: String = str(def.get("name", id))
	if weapon_system != null and weapon_system.has_method("ammo_info") and bool(def.get("uses_ammo", true)):
		var info: Dictionary = weapon_system.call("ammo_info", id)
		label += " %d/%d" % [int(info.get("mag", 0)), int(info.get("reserve", 0))]
	return label


func refresh_wrist_labels() -> void:
	for raw in wrist_menu.buttons:
		var id := str(raw["id"])
		if id.begins_with("equip:"):
			raw["label"] = _row_label(id.substr(6))
			var label = wrist_menu._button_labels.get(id)
			if label != null:
				label.text = str(raw["label"])


func _on_wrist_button(button_id: String) -> void:
	if button_id.begins_with("equip:"):
		equip_requested.emit(button_id.substr(6))
	elif button_id == "tutorial":
		show_tutorial()
		tutorial_requested.emit()


func _build_tutorial() -> void:
	tutorial_panel = Node3D.new()
	tutorial_panel.name = "Tutorial"
	add_child(tutorial_panel)
	var back := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.7, 0.8)
	back.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.02, 0.04, 0.08, 0.92)
	back.material_override = material
	back.position.z = -0.01
	tutorial_panel.add_child(back)
	var title := Label3D.new()
	title.text = "COMO JUGAR"
	title.pixel_size = 0.0035
	title.font_size = 64
	title.position = Vector3(0.0, 0.33, 0.0)
	tutorial_panel.add_child(title)
	for i in TUTORIAL_LINES.size():
		var line := Label3D.new()
		line.text = str(TUTORIAL_LINES[i])
		line.pixel_size = 0.0022
		line.font_size = 48
		line.position = Vector3(0.0, 0.2 - i * 0.1, 0.0)
		tutorial_panel.add_child(line)
	var close := Label3D.new()
	close.text = "GATILLO para cerrar"
	close.pixel_size = 0.0025
	close.font_size = 48
	close.modulate = Color(0.5, 0.9, 1.0)
	close.position = Vector3(0.0, -0.34, 0.0)
	tutorial_panel.add_child(close)
	show_tutorial()


func show_tutorial() -> void:
	tutorial_open = true
	_tutorial_age = 0.0
	_tutorial_placed = false
	tutorial_panel.visible = true


func close_tutorial() -> void:
	if not tutorial_open:
		return
	tutorial_open = false
	tutorial_panel.visible = false
	tutorial_closed.emit()


# poses: hand -> Transform3D; triggers: hand -> float. Llamar cada fotograma.
func tick(_delta: float, head: Transform3D, poses: Dictionary, triggers: Dictionary) -> void:
	if holsters == null:
		return
	for slot in slot_nodes.keys():
		var anchor: Node3D = slot_nodes[slot]
		anchor.global_position = slot_world(str(slot), head)
		anchor.global_transform.basis = yaw_only(head).basis
	for hand in ["left", "right"]:
		var pose: Transform3D = poses.get(hand, Transform3D.IDENTITY)
		glow[hand] = nearest_display_slot(pose.origin, head)
	for slot in glow_nodes.keys():
		(glow_nodes[slot] as MeshInstance3D).visible = glow["left"] == slot or glow["right"] == slot
	var wrist: Transform3D = poses.get("left", Transform3D.IDENTITY)
	var wrist_pos: Vector3 = wrist.origin + Vector3.UP * 0.1
	var looking: bool = is_looking_at_wrist(head, wrist_pos)
	if looking != wrist_visible:
		wrist_visible = looking
		wrist_menu.is_open = looking
		wrist_menu.panel_root.visible = looking
		if looking:
			refresh_wrist_labels()
	if wrist_visible:
		var to_head: Vector3 = head.origin - wrist_pos
		to_head.y = 0.0
		wrist_menu.global_transform = Transform3D(Basis.looking_at(-to_head.normalized(), Vector3.UP), wrist_pos)
		var right_pose: Transform3D = poses.get("right", Transform3D.IDENTITY)
		var pressed: bool = float(triggers.get("right", 0.0)) > TRIGGER_ON and not bool(_trigger_was["right"])
		wrist_menu.try_press(right_pose.origin, -right_pose.basis.z, pressed)
	if tutorial_open:
		_tutorial_age += maxf(_delta, 0.0)
		if _tutorial_age >= TUTORIAL_AUTO_CLOSE:
			close_tutorial()
		if not _tutorial_placed:
			var forward := -head.basis.z
			forward.y = 0.0
			forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
			tutorial_panel.global_position = head.origin + forward * 1.3
			tutorial_panel.look_at(head.origin, Vector3.UP)
			tutorial_panel.rotate_y(PI)
			_tutorial_placed = true
		for hand in ["left", "right"]:
			if float(triggers.get(hand, 0.0)) > TRIGGER_ON and not bool(_trigger_was[hand]):
				close_tutorial()
	for hand in ["left", "right"]:
		_trigger_was[hand] = float(triggers.get(hand, 0.0)) > TRIGGER_ON
