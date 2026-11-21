extends BTCondition

class_name MockBTCondition

var _result: bool = true

func _init(p_result: bool) -> void:
	_result = p_result

func check(tick: Variant) -> bool:
	return _result