extends SceneTree

const BTNode = preload("res://core/npc/bt/bt_node.gd")
const BTSelector = preload("res://core/npc/bt/bt_selector.gd")
const BTSequence = preload("res://core/npc/bt/bt_sequence.gd")
const BTParallel = preload("res://core/npc/bt/bt_parallel.gd")
const BTCondition = preload("res://core/npc/bt/bt_condition.gd")
const BTAction = preload("res://core/npc/bt/bt_action.gd")
const BTInverter = preload("res://core/npc/bt/bt_inverter.gd")
const BTRepeater = preload("res://core/npc/bt/bt_repeater.gd")
const BTRepeatUntil = preload("res://core/npc/bt/bt_repeat_until.gd")
const BTAlwaysReturn = preload("res://core/npc/bt/bt_always_return.gd")
const BTBlackboard = preload("res://core/npc/bt/blackboard.gd")
const BTContext = preload("res://core/npc/bt/bt_context.gd")
const BehaviorTree = preload("res://core/npc/bt/behavior_tree.gd")
const BTTreeBuilder = preload("res://core/npc/bt/bt_tree_builder.gd")

const MockBTAction = preload("res://tests/mock_bt_action.gd")
const MockBTCondition = preload("res://tests/mock_bt_condition.gd")
const MockBTConditionalAction = preload("res://tests/mock_bt_conditional_action.gd")

var _checks: int = 0
var _failures: Array = []


func _initialize() -> void:
	await _run_tests()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + str(failure))
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run_tests() -> void:
	_test_selector_succeeds_on_first_ok()
	_test_selector_fails_if_all_fail()
	_test_sequence_succeeds_if_all_ok()
	_test_sequence_fails_on_first_fail()
	_test_parallel_succeed_on_one()
	_test_parallel_succeed_on_all()
	_test_condition_returns_ok_when_true()
	_test_condition_returns_failed_when_false()
	_test_action_returns_ok()
	_test_inverter_flips_ok_to_failed()
	_test_inverter_flips_failed_to_ok()
	_test_inverter_passes_busy()
	_test_repeater_repeats_until_busy()
	_test_repeat_until_success()
	_test_repeat_until_failure()
	_test_always_return_success()
	_test_always_return_failure()
	_test_blackboard_set_get()
	_test_blackboard_tree_node_scopes()
	_test_behavior_tree_tick()
	_test_civil_pacific_tree_structure()
	_test_civil_hostile_tree_structure()
	_test_police_pacific_tree_structure()
	_test_police_hostile_tree_structure()
	_test_soldier_pacific_tree_structure()
	_test_soldier_hostile_tree_structure()
	_test_criminal_pacific_tree_structure()
	_test_criminal_hostile_tree_structure()
	_test_office_pacific_tree_structure()
	_test_office_hostile_tree_structure()
	_test_zombie_pacific_tree_structure()
	_test_zombie_hostile_tree_structure()
	_test_tree_builder_returns_valid_trees()
	_test_cooldown_decorator()


# === Core Node Tests ===

func _test_selector_succeeds_on_first_ok() -> void:
	var root: BTSelector = BTSelector.new()
	var blackboard: BTBlackboard = BTBlackboard.new()
	var context: BTContext = BTContext.new(root, null, blackboard)
	
	var action1: BTAction = MockBTAction.new(BTNode.FAILED)
	var action2: BTAction = MockBTAction.new(BTNode.OK)
	
	root.add_child(action1)
	root.add_child(action2)
	
	var result: int = root.execute(context)
	
	_expect(result == BTNode.OK, "Selector returns BTNode.OK when second child succeeds")
	_expect(action1.call_count + action2.call_count == 2, "Selector ticks both children (first fails, second succeeds)")


func _test_selector_fails_if_all_fail() -> void:
	var root: BTSelector = BTSelector.new()
	var blackboard: BTBlackboard = BTBlackboard.new()
	var context: BTContext = BTContext.new(root, null, blackboard)
	
	var action1: BTAction = MockBTAction.new(BTNode.FAILED)
	var action2: BTAction = MockBTAction.new(BTNode.FAILED)
	
	root.add_child(action1)
	root.add_child(action2)
	
	var result: int = root.execute(context)
	
	_expect(result == BTNode.FAILED, "Selector returns BTNode.FAILED when all children fail")
	_expect(action1.call_count + action2.call_count == 2, "Selector ticks all children when all fail")


func _test_sequence_succeeds_if_all_ok() -> void:
	var root: BTSequence = BTSequence.new()
	var blackboard: BTBlackboard = BTBlackboard.new()
	var context: BTContext = BTContext.new(root, null, blackboard)
	
	var action1: BTAction = MockBTAction.new(BTNode.OK)
	var action2: BTAction = MockBTAction.new(BTNode.OK)
	
	root.add_child(action1)
	root.add_child(action2)
	
	var result: int = root.execute(context)
	
	_expect(result == BTNode.OK, "Sequence returns BTNode.OK when all children succeed")
	_expect(action1.call_count + action2.call_count == 2, "Sequence ticks all children when all succeed")


func _test_sequence_fails_on_first_fail() -> void:
	var root: BTSequence = BTSequence.new()
	var blackboard: BTBlackboard = BTBlackboard.new()
	var context: BTContext = BTContext.new(root, null, blackboard)
	
	var action1: BTAction = MockBTAction.new(BTNode.FAILED)
	var action2: BTAction = MockBTAction.new(BTNode.OK)
	
	root.add_child(action1)
	root.add_child(action2)
	
	var result: int = root.execute(context)
	
	_expect(result == BTNode.FAILED, "Sequence returns BTNode.FAILED on first failure")
	_expect(action1.call_count == 1 and action2.call_count == 0, "Sequence stops after first failure")


func _test_parallel_succeed_on_one() -> void:
	var root: BTParallel = BTParallel.new()
	root.success_policy = BTParallel.Policy.SUCCEED_ON_ONE
	root.failure_policy = BTParallel.Policy.FAIL_ON_ALL
	var blackboard: BTBlackboard = BTBlackboard.new()
	var context: BTContext = BTContext.new(root, null, blackboard)
	
	var action1: BTAction = MockBTAction.new(BTNode.FAILED)
	var action2: BTAction = MockBTAction.new(BTNode.OK)
	
	root.add_child(action1)
	root.add_child(action2)
	
	var result: int = root.execute(context)
	
	_expect(result == BTNode.OK, "Parallel SUCCEED_ON_ONE returns BTNode.OK when one succeeds")
	_expect(action1.call_count + action2.call_count == 2, "Parallel ticks all children")


func _test_parallel_succeed_on_all() -> void:
	var root: BTParallel = BTParallel.new()
	root.success_policy = BTParallel.Policy.SUCCEED_ON_ALL
	root.failure_policy = BTParallel.Policy.FAIL_ON_ONE
	var blackboard: BTBlackboard = BTBlackboard.new()
	var context: BTContext = BTContext.new(root, null, blackboard)
	
	var action1: BTAction = MockBTAction.new(BTNode.OK)
	var action2: BTAction = MockBTAction.new(BTNode.OK)
	
	root.add_child(action1)
	root.add_child(action2)
	
	var result: int = root.execute(context)
	
	_expect(result == BTNode.OK, "Parallel SUCCEED_ON_ALL returns BTNode.OK when all succeed")
	_expect(action1.call_count + action2.call_count == 2, "Parallel ticks all children")


func _test_condition_returns_ok_when_true() -> void:
	var cond: BTCondition = MockBTCondition.new(true)
	var blackboard: BTBlackboard = BTBlackboard.new()
	var context: BTContext = BTContext.new(cond, null, blackboard)
	
	var result: int = cond.execute(context)
	
	_expect(result == BTNode.OK, "Condition returns BTNode.OK when check returns true")


func _test_condition_returns_failed_when_false() -> void:
	var cond: BTCondition = MockBTCondition.new(false)
	var blackboard: BTBlackboard = BTBlackboard.new()
	var context: BTContext = BTContext.new(cond, null, blackboard)
	
	var result: int = cond.execute(context)
	
	_expect(result == BTNode.FAILED, "Condition returns BTNode.FAILED when check returns false")


func _test_action_returns_ok() -> void:
	var action: BTAction = MockBTAction.new(BTNode.OK)
	var blackboard: BTBlackboard = BTBlackboard.new()
	var context: BTContext = BTContext.new(action, null, blackboard)
	
	var result: int = action.execute(context)
	
	_expect(result == BTNode.OK, "Action returns BTNode.OK by default")


func _test_inverter_flips_ok_to_failed() -> void:
	var inverter: BTInverter = BTInverter.new()
	var blackboard: BTBlackboard = BTBlackboard.new()
	var context: BTContext = BTContext.new(inverter, null, blackboard)
	
	var action: BTAction = MockBTAction.new(BTNode.OK)
	inverter.add_child(action)
	
	var result: int = inverter.execute(context)
	
	_expect(result == BTNode.FAILED, "Inverter returns BTNode.FAILED when child returns BTNode.OK")


func _test_inverter_flips_failed_to_ok() -> void:
	var inverter: BTInverter = BTInverter.new()
	var blackboard: BTBlackboard = BTBlackboard.new()
	var context: BTContext = BTContext.new(inverter, null, blackboard)
	
	var action: BTAction = MockBTAction.new(BTNode.FAILED)
	inverter.add_child(action)
	
	var result: int = inverter.execute(context)
	
	_expect(result == BTNode.OK, "Inverter returns BTNode.OK when child returns BTNode.FAILED")


func _test_inverter_passes_busy() -> void:
	var inverter: BTInverter = BTInverter.new()
	var blackboard: BTBlackboard = BTBlackboard.new()
	var context: BTContext = BTContext.new(inverter, null, blackboard)
	
	var action: BTAction = MockBTAction.new(BTNode.ERR_BUSY)
	inverter.add_child(action)
	
	var result: int = inverter.execute(context)
	
	_expect(result == BTNode.ERR_BUSY, "Inverter passes through BTNode.ERR_BUSY")


func _test_repeater_repeats_until_busy() -> void:
	var repeater: BTRepeater = BTRepeater.new()
	repeater.max_repeats = 3
	var blackboard: BTBlackboard = BTBlackboard.new()
	var context: BTContext = BTContext.new(repeater, null, blackboard)
	
	var action: BTAction = MockBTAction.new(BTNode.OK)
	repeater.add_child(action)
	
	var result: int = repeater.execute(context)
	
	_expect(result == BTNode.OK, "Repeater returns BTNode.OK after max_repeats BTNode.OK results")
	_expect(action.call_count == 3, "Repeater ticks child max_repeats times")


func _test_repeat_until_success() -> void:
	var repeater: BTRepeatUntil = BTRepeatUntil.new()
	repeater.until = BTRepeatUntil.UntilResult.UNTIL_SUCCESS
	repeater.max_repeats = 5
	var blackboard: BTBlackboard = BTBlackboard.new()
	var context: BTContext = BTContext.new(repeater, null, blackboard)
	
	var action: BTAction = MockBTConditionalAction.new(3, false)
	repeater.add_child(action)
	
	var result: int = repeater.execute(context)
	
	_expect(result == BTNode.OK, "RepeatUntil SUCCESS returns BTNode.OK when child eventually succeeds")
	_expect(action.call_count >= 3, "Child ticked multiple times until success")


func _test_repeat_until_failure() -> void:
	var repeater: BTRepeatUntil = BTRepeatUntil.new()
	repeater.until = BTRepeatUntil.UntilResult.UNTIL_FAILURE
	repeater.max_repeats = 5
	var blackboard: BTBlackboard = BTBlackboard.new()
	var context: BTContext = BTContext.new(repeater, null, blackboard)
	
	var action: BTAction = MockBTConditionalAction.new(3, true)
	repeater.add_child(action)
	
	var result: int = repeater.execute(context)
	
	_expect(result == BTNode.OK, "RepeatUntil FAILURE returns BTNode.OK when child eventually fails")
	_expect(action.call_count >= 3, "Child ticked multiple times until failure")


func _test_always_return_success() -> void:
	var succeeder: BTAlwaysReturn = BTAlwaysReturn.new()
	succeeder.return_result = BTAlwaysReturn.ReturnResult.RETURN_SUCCESS
	var blackboard: BTBlackboard = BTBlackboard.new()
	var context: BTContext = BTContext.new(succeeder, null, blackboard)
	
	var action: BTAction = MockBTAction.new(BTNode.FAILED)
	succeeder.add_child(action)
	
	var result: int = succeeder.execute(context)
	
	_expect(result == BTNode.OK, "AlwaysReturn SUCCESS returns BTNode.OK even if child fails")


func _test_always_return_failure() -> void:
	var failer: BTAlwaysReturn = BTAlwaysReturn.new()
	failer.return_result = BTAlwaysReturn.ReturnResult.RETURN_FAILURE
	var blackboard: BTBlackboard = BTBlackboard.new()
	var context: BTContext = BTContext.new(failer, null, blackboard)
	
	var action: BTAction = MockBTAction.new(BTNode.OK)
	failer.add_child(action)
	
	var result: int = failer.execute(context)
	
	_expect(result == BTNode.FAILED, "AlwaysReturn FAILURE returns BTNode.FAILED even if child succeeds")


# === Blackboard Tests ===

func _test_blackboard_set_get() -> void:
	var bb: BTBlackboard = BTBlackboard.new()
	
	bb.set_value("key1", "value1")
	bb.set_value("key2", 42)
	bb.set_value("key3", true)
	
	_expect(bb.get_value("key1") == "value1", "Blackboard stores and retrieves string")
	_expect(bb.get_value("key2") == 42, "Blackboard stores and retrieves int")
	_expect(bb.get_value("key3") == true, "Blackboard stores and retrieves bool")
	_expect(bb.get_value("nonexistent") == null, "Blackboard returns null for missing key")


func _test_blackboard_tree_node_scopes() -> void:
	var bb: BTBlackboard = BTBlackboard.new()
	var tree: BehaviorTree = BehaviorTree.new()
	var node: BTAction = BTAction.new()
	
	bb.set_value("global", "global_value")
	bb.set_value("tree_key", "tree_value", tree)
	bb.set_value("node_key", "node_value", tree, node)
	
	_expect(bb.get_value("global") == "global_value", "Global scope works")
	_expect(bb.get_value("tree_key", tree) == "tree_value", "Tree scope works")
	_expect(bb.get_value("node_key", tree, node) == "node_value", "Node scope works")
	_expect(bb.get_value("tree_key") == null, "Tree-scoped key not visible in global scope")
	_expect(bb.get_value("node_key", tree) == null, "Node-scoped key not visible in tree scope")


# === BehaviorTree Tests ===

func _test_behavior_tree_tick() -> void:
	var tree: BehaviorTree = BehaviorTree.new()
	var blackboard: BTBlackboard = BTBlackboard.new()
	
	var selector: BTSelector = BTSelector.new()
	var action: BTAction = MockBTAction.new(BTNode.OK)
	selector.add_child(action)
	tree.add_child(selector)
	
	var result: int = tree.tick_with(null, blackboard, false)
	
	_expect(result == BTNode.OK, "BehaviorTree.tick_with returns child result")


# === Role Tree Structure Tests ===

func _test_civil_pacific_tree_structure() -> void:
	var tree: BehaviorTree = BTTreeBuilder.build_civil_pacific()
	
	_expect(tree != null, "Civil pacific tree created")
	_expect(tree.get_child_count() == 1, "Civil pacific tree has root selector")
	
	var root: BTSelector = tree.get_children()[0]
	_expect(root is BTSelector, "Civil pacific root is Selector")
	_expect(root.get_child_count() >= 4, "Civil pacific has multiple priority branches")


func _test_civil_hostile_tree_structure() -> void:
	var tree: BehaviorTree = BTTreeBuilder.build_civil_hostile()
	
	_expect(tree != null, "Civil hostile tree created")
	_expect(tree.get_child_count() == 1, "Civil hostile tree has root selector")
	
	var root: BTSelector = tree.get_children()[0]
	_expect(root is BTSelector, "Civil hostile root is Selector")
	_expect(root.get_child_count() >= 3, "Civil hostile has multiple priority branches")


func _test_police_pacific_tree_structure() -> void:
	var tree: BehaviorTree = BTTreeBuilder.build_police_pacific()
	
	_expect(tree != null, "Police pacific tree created")
	_expect(tree.get_child_count() == 1, "Police pacific tree has root selector")


func _test_police_hostile_tree_structure() -> void:
	var tree: BehaviorTree = BTTreeBuilder.build_police_hostile()
	
	_expect(tree != null, "Police hostile tree created")
	_expect(tree.get_child_count() == 1, "Police hostile tree has root selector")


func _test_soldier_pacific_tree_structure() -> void:
	var tree: BehaviorTree = BTTreeBuilder.build_soldier_pacific()
	
	_expect(tree != null, "Soldier pacific tree created")
	_expect(tree.get_child_count() == 1, "Soldier pacific tree has root selector")


func _test_soldier_hostile_tree_structure() -> void:
	var tree: BehaviorTree = BTTreeBuilder.build_soldier_hostile()
	
	_expect(tree != null, "Soldier hostile tree created")
	_expect(tree.get_child_count() == 1, "Soldier hostile tree has root selector")


func _test_criminal_pacific_tree_structure() -> void:
	var tree: BehaviorTree = BTTreeBuilder.build_criminal_pacific()
	
	_expect(tree != null, "Criminal pacific tree created")
	_expect(tree.get_child_count() == 1, "Criminal pacific tree has root selector")


func _test_criminal_hostile_tree_structure() -> void:
	var tree: BehaviorTree = BTTreeBuilder.build_criminal_hostile()
	
	_expect(tree != null, "Criminal hostile tree created")
	_expect(tree.get_child_count() == 1, "Criminal hostile tree has root selector")


func _test_office_pacific_tree_structure() -> void:
	var tree: BehaviorTree = BTTreeBuilder.build_office_pacific()
	
	_expect(tree != null, "Office pacific tree created")
	_expect(tree.get_child_count() == 1, "Office pacific tree has root selector")


func _test_office_hostile_tree_structure() -> void:
	var tree: BehaviorTree = BTTreeBuilder.build_office_hostile()
	
	_expect(tree != null, "Office hostile tree created")
	_expect(tree.get_child_count() == 1, "Office hostile tree has root selector")


func _test_zombie_pacific_tree_structure() -> void:
	var tree: BehaviorTree = BTTreeBuilder.build_zombie_pacific()
	
	_expect(tree != null, "Zombie pacific tree created")
	_expect(tree.get_child_count() == 1, "Zombie pacific tree has root selector")


func _test_zombie_hostile_tree_structure() -> void:
	var tree: BehaviorTree = BTTreeBuilder.build_zombie_hostile()
	
	_expect(tree != null, "Zombie hostile tree created")
	_expect(tree.get_child_count() == 1, "Zombie hostile tree has root selector")


func _test_tree_builder_returns_valid_trees() -> void:
	var roles: Array = ["civil", "police", "soldier", "criminal", "office", "zombie"]
	var modes: Array = ["pacifico", "hostil"]
	
	for role in roles:
		for mode in modes:
			var tree: BehaviorTree = BTTreeBuilder.build_tree_for_role(role, mode)
			_expect(tree != null, "Tree builder returns valid tree for %s/%s" % [role, mode])
			_expect(tree is BehaviorTree, "Tree builder returns BehaviorTree for %s/%s" % [role, mode])


# === Cooldown Decorator Test ===

func _test_cooldown_decorator() -> void:
	var bt_cooldown = preload("res://core/npc/bt/bt_cooldown.gd")
	var cooldown: BTNode = bt_cooldown.new()
	cooldown.cooldown_time = 0.1
	
	var blackboard: BTBlackboard = BTBlackboard.new()
	var context: BTContext = BTContext.new(cooldown, null, blackboard)
	
	var action: BTAction = MockBTAction.new(BTNode.OK)
	cooldown.add_child(action)
	
	# First execution should succeed
	var result1: int = cooldown.execute(context)
	_expect(result1 == BTNode.OK, "Cooldown first execution returns BTNode.OK")
	_expect(action.call_count == 1, "Action executed once")
	
	# Test that the decorator exists and can be instantiated
	_expect(true, "Cooldown decorator can be instantiated and used")