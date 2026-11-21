extends BTAction

class_name MockBTAction

var call_count: int = 0
var _result: int = OK

func _init(p_result: int) -> void:
	_result = p_result
	call_count = 0

func execute_action(tick: Variant) -> int:
	call_count += 1
	return _result