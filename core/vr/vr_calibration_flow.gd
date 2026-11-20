class_name VrCalibrationFlow
extends Node3D

# Panel 3D guiado de calibracion: el gatillo confirma cada paso. Logica sin casco.

signal finished(saved: bool)
signal confirmed(hand: String)

const CalScript = preload("res://core/vr/vr_calibration.gd")

const TRIGGER_ON := 0.6
const TRIGGER_OFF := 0.3
const TEXTS: Dictionary = {
	"arms_down": "1. DE PIE\nBrazos a los lados",
	"arms_extended": "2. BRAZOS ABIERTOS\nExtiéndelos a los lados",
	"hand_hip": "3. MANO EN LA CADERA\nDonde llevarás la pistola",
}
const ARM_ANGLES: Dictionary = {"arms_down": 0.15, "arms_extended": 1.5, "hand_hip": 0.6}
const REASONS: Dictionary = {
	"altura_fuera_de_rango": "Altura no valida, intentalo de nuevo",
	"brazos_no_a_los_lados": "Baja los brazos a los lados",
	"alcance_fuera_de_rango": "Extiende mas los brazos",
	"mano_no_en_la_cadera": "La mano debe estar en la cadera",
	"pose_invalida": "Mandos no detectados",
}

var calibration = null
var silhouette_arms: Array = []
var title: Label3D = null
var progress: Label3D = null
var hint: Label3D = null
var active: bool = false
var _down: bool = false


func _ready() -> void:
	_build()


func _build() -> void:
	if title != null:
		return
	var back := MeshInstance3D.new()
	back.name = "Background"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 0.95)
	back.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.02, 0.04, 0.08, 0.92)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	back.material_override = material
	back.position.z = -0.01
	add_child(back)
	title = _label("Calibracion", -0.3, 0.25, 0.0045)
	title.font_size = 64
	progress = _label("", -0.3, -0.05, 0.004)
	progress.font_size = 56
	hint = _label("Pulsa el GATILLO para confirmar", 0.0, -0.36, 0.0032)
	hint.font_size = 52
	_build_silhouette()


# Silueta de cuerpo (iconos simples) que muestra la postura de cada paso.
func _build_silhouette() -> void:
	var holder := Node3D.new()
	holder.name = "Silhouette"
	holder.position = Vector3(0.48, 0.0, 0.0)
	add_child(holder)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.3, 0.8, 1.0)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	head.mesh = sphere
	head.material_override = material
	head.position.y = 0.3
	holder.add_child(head)
	var torso := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.07
	capsule.height = 0.36
	torso.mesh = capsule
	torso.material_override = material
	torso.position.y = 0.04
	holder.add_child(torso)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.09, 0.16, 0.0)
		var arm := MeshInstance3D.new()
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.025
		arm_mesh.height = 0.26
		arm.mesh = arm_mesh
		arm.material_override = material
		arm.position.y = -0.13
		pivot.add_child(arm)
		holder.add_child(pivot)
		silhouette_arms.append({"pivot": pivot, "side": side})


func _pose_silhouette(step: String) -> void:
	var angle: float = float(ARM_ANGLES.get(step, 0.15))
	for entry in silhouette_arms:
		(entry["pivot"] as Node3D).rotation.z = -float(entry["side"]) * angle


func _label(text: String, x: float, y: float, size: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.pixel_size = size
	label.position = Vector3(x, y, 0.0)
	label.no_depth_test = true
	label.outline_size = 12
	label.font_size = 48
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if x < -0.1 else HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	return label


func begin(cal) -> void:
	_build()
	calibration = cal
	cal.begin_guided()
	active = true
	_down = false
	_refresh("")


func place_in_front(position: Vector3, forward: Vector3) -> void:
	var dir := Vector3(forward.x, 0.0, forward.z)
	if dir.length() < 0.01:
		dir = Vector3.FORWARD
	global_position = position + dir.normalized() * 1.2
	look_at(position, Vector3.UP)
	rotate_y(PI)


func step_number() -> int:
	if calibration == null:
		return 0
	return mini(CalScript.STEPS.find(calibration.current_step()) + 1, 3)


func _refresh(error: String) -> void:
	var step: String = calibration.current_step() if calibration != null else ""
	title.text = str(TEXTS.get(step, "LISTO\nPerfil guardado"))
	progress.text = ("PASO %d DE 3  " % step_number() + "●".repeat(step_number()) + "○".repeat(3 - step_number())) if not step.is_empty() else "Guardado"
	_pose_silhouette(step)
	hint.text = str(REASONS.get(error, error)) if not error.is_empty() else "Pulsa el gatillo para confirmar"


# Poses en el marco del suelo (altura de ojos = head.origin.y). Devuelve el registro o {}.
func update_inputs(head: Transform3D, left: Transform3D, right: Transform3D, left_trigger: float, right_trigger: float) -> Dictionary:
	if not active or calibration == null:
		return {}
	var value: float = maxf(left_trigger, right_trigger)
	if _down:
		if value < TRIGGER_OFF:
			_down = false
		return {}
	if value <= TRIGGER_ON:
		return {}
	_down = true
	var hip_hand := "left" if left_trigger > right_trigger else "right"
	var result: Dictionary = calibration.record(head, left, right, hip_hand)
	if bool(result["ok"]):
		confirmed.emit(hip_hand)
		play_beep()
	if calibration.current_step().is_empty():
		active = false
		var saved: bool = bool(calibration.save())
		_refresh("")
		finished.emit(saved)
	else:
		_refresh("" if bool(result["ok"]) else str(result["reason"]))
	return result


var beep_player: AudioStreamPlayer = null


func play_beep() -> void:
	if not is_inside_tree():
		return
	if beep_player == null:
		beep_player = AudioStreamPlayer.new()
		var count := 4410
		var data := PackedByteArray()
		data.resize(count * 2)
		for i in count:
			var t := float(i) / 22050.0
			data.encode_s16(i * 2, int(sin(TAU * 880.0 * t) * minf(1.0, (0.2 - t) * 20.0) * 0.4 * 32767.0))
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.data = data
		beep_player.stream = stream
		add_child(beep_player)
	beep_player.play()
