class_name DebugInput
extends RefCounted

const VrDebugPanelScript = preload("res://core/vr/vr_debug_panel.gd")

static var debug_panel: VrDebugPanel = null
static var _initialized: bool = false

static func initialize(p_debug_panel: VrDebugPanel) -> void:
	debug_panel = p_debug_panel
	_initialized = true

static func handle_input(event: InputEvent) -> bool:
	if not _initialized or debug_panel == null:
		return false
	return debug_panel.handle_pc_input(event)

static func is_initialized() -> bool:
	return _initialized

static func get_debug_panel() -> VrDebugPanel:
	return debug_panel