class_name VrCalibrationFlow
extends Node3D

# Panel 3D guiado de calibracion: el gatillo confirma cada paso. Logica sin casco.

signal finished(saved: bool)

const CalScript = preload("res://core/vr/vr_calibration.gd")

const TRIGGER_ON := 0.6
const TRIGGER_OFF := 0.3
const TEXTS: Dictionary = {
	"arms_down": "De pie, brazos a los lados",
	"arms_extended": "Extiende los brazos",
	"hand_hip": "Lleva la mano a la cadera",
}
const REASONS: Dictionary = {
	"altura_fuera_de_rango": "Altura no valida, intentalo de nuevo",
	"brazos_no_a_los_lados": "Baja los brazos a los lados",
	"alcance_fuera_de_rango": "Extiende mas los brazos",
	"mano_no_en_la_cadera": "La mano debe estar en la cadera",
	"pose_invalida": "Mandos no detectados",
}

var calibration = null
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
	title = _label("Calibracion", 0.0, 0.12, 0.012)
	progress = _label("", 0.0, 0.0, 0.01)
	hint = _label("Pulsa el gatillo para confirmar", 0.0, -0.12, 0.007)


func _label(text: String, x: float, y: float, size: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.pixel_size = size
	label.position = Vector3(x, y, 0.0)
	label.no_depth_test = true
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
	title.text = str(TEXTS.get(step, "Calibracion lista"))
	progress.text = "Paso %d/3" % step_number() if not step.is_empty() else "Guardado"
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
	if calibration.current_step().is_empty():
		active = false
		var saved: bool = bool(calibration.save())
		_refresh("")
		finished.emit(saved)
	else:
		_refresh("" if bool(result["ok"]) else str(result["reason"]))
	return result
