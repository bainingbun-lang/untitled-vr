extends BTAction

class_name MockBTConditionalAction

var call_count: int = 0
var _switch_at: int = 1
var _reverse: bool = false

func _init(p_switch_at: int, p_reverse: bool) -> void:
	_switch_at = p_switch_at
	_reverse = p_reverse
	call_count = 0

func execute_action(tick: Variant) -> int:
	call_count += 1
	if _reverse:
		return FAILED if call_count >= _switch_at else OK
	else:
		return OK if call_count >= _switch_at else FAILED