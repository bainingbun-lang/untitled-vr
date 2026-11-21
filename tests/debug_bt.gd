extends SceneTree

const BTSelector = preload("res://core/npc/bt/bt_selector.gd")
const BTBlackboard = preload("res://core/npc/bt/blackboard.gd")
const BTContext = preload("res://core/npc/bt/bt_context.gd")
const MockBTAction = preload("res://tests/mock_bt_action.gd")


func _initialize() -> void:
	var root: BTSelector = BTSelector.new()
	var blackboard: BTBlackboard = BTBlackboard.new()
	var context: BTContext = BTContext.new(root, null, blackboard)
	
	var action1: MockBTAction = MockBTAction.new(2)  # FAILED
	var action2: MockBTAction = MockBTAction.new(1)  # OK
	
	root.add_child(action1)
	root.add_child(action2)
	
	print("Calling root.execute(context)")
	var result: int = root.execute(context)
	
	print("Result: " + str(result))
	print("action1.call_count: " + str(action1.call_count))
	print("action2.call_count: " + str(action2.call_count))
	
	if result == 1:  # OK
		print("TEST PASSED")
	else:
		print("TEST FAILED")
	
	quit(0)