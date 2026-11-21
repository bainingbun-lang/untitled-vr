extends SceneTree

const BTTreeBuilder = preload("res://core/npc/bt/bt_tree_builder.gd")
const BehaviorTree = preload("res://core/npc/bt/behavior_tree.gd")
const BTSelector = preload("res://core/npc/bt/bt_selector.gd")
const BTSequence = preload("res://core/npc/bt/bt_sequence.gd")
const BTParallel = preload("res://core/npc/bt/bt_parallel.gd")
const BTRepeater = preload("res://core/npc/bt/bt_repeater.gd")
const BTRepeatUntil = preload("res://core/npc/bt/bt_repeat_until.gd")
const BTInverter = preload("res://core/npc/bt/bt_inverter.gd")
const BTAction = preload("res://core/npc/bt/bt_action.gd")
const BTAlwaysReturn = preload("res://core/npc/bt/bt_always_return.gd")
const BTCondition = preload("res://core/npc/bt/bt_condition.gd")

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

func _load_npc_types() -> Dictionary:
	var file = FileAccess.open("res://data/base/npc_types.json", FileAccess.READ)
	if file == null:
		return {}
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _run_tests() -> void:
	_test_npc_types_loads()
	_test_npc_types_has_required_roles()
	_test_npc_types_role_data_structure()
	_test_tree_builder_returns_trees_for_all_roles()
	_test_tree_builder_role_mode_combinations()
	_test_behavior_tree_structure_validity()

func _test_npc_types_loads() -> void:
	var npc_types = _load_npc_types()
	_expect(npc_types != {}, "npc_types.json loads and parses correctly")
	_expect(npc_types.has("content"), "npc_types has content array")

func _test_npc_types_has_required_roles() -> void:
	var npc_types = _load_npc_types()
	var roles_found: Array = []
	for entry in npc_types.content:
		if entry.type == "npc_type":
			roles_found.append(entry.role)
	
	var required_roles: Array = ["civil", "police", "criminal", "soldier", "office"]
	for role in required_roles:
		_expect(role in roles_found, "Role '%s' exists in npc_types.json" % role)

func _test_npc_types_role_data_structure() -> void:
	var npc_types = _load_npc_types()
	for entry in npc_types.content:
		if entry.type != "npc_type":
			continue
		
		_expect(entry.has("id"), "Entry %s has id" % entry.name)
		_expect(entry.has("name"), "Entry %s has name" % entry.name)
		_expect(entry.has("role"), "Entry %s has role" % entry.name)
		_expect(entry.has("models"), "Entry %s has models array" % entry.name)
		_expect(entry.has("health"), "Entry %s has health" % entry.name)
		_expect(entry.has("speed"), "Entry %s has speed" % entry.name)
		_expect(entry.has("behavior_tree"), "Entry %s has behavior_tree" % entry.name)
		
		var bt = entry.behavior_tree
		_expect(bt.has("pacific_mode"), "Entry %s behavior_tree has pacific_mode" % entry.name)
		_expect(bt.has("hostile_mode"), "Entry %s behavior_tree has hostile_mode" % entry.name)
		_expect(bt.has("default_mode"), "Entry %s behavior_tree has default_mode" % entry.name)
		
		_expect(bt.pacific_mode.begins_with("res://core/npc/bt/trees/"), "pacific_mode path format correct for %s" % entry.name)
		_expect(bt.hostile_mode.begins_with("res://core/npc/bt/trees/"), "hostile_mode path format correct for %s" % entry.name)
		_expect(bt.default_mode in ["pacifico", "hostil"], "default_mode valid for %s" % entry.name)

func _test_tree_builder_returns_trees_for_all_roles() -> void:
	var roles: Array = ["civil", "police", "soldier", "criminal", "office", "zombie"]
	for role in roles:
		var tree_pacific: BehaviorTree = BTTreeBuilder.build_tree_for_role(role, "pacifico")
		var tree_hostile: BehaviorTree = BTTreeBuilder.build_tree_for_role(role, "hostil")
		
		_expect(tree_pacific != null, "Tree builder returns tree for %s/pacifico" % role)
		_expect(tree_pacific is BehaviorTree, "Tree for %s/pacifico is BehaviorTree" % role)
		_expect(tree_hostile != null, "Tree builder returns tree for %s/hostil" % role)
		_expect(tree_hostile is BehaviorTree, "Tree for %s/hostil is BehaviorTree" % role)

func _test_tree_builder_role_mode_combinations() -> void:
	var role_mode_pairs: Array = [
		["civil", "pacifico"], ["civil", "hostil"],
		["police", "pacifico"], ["police", "hostil"],
		["soldier", "pacifico"], ["soldier", "hostil"],
		["criminal", "pacifico"], ["criminal", "hostil"],
		["office", "pacifico"], ["office", "hostil"],
		["zombie", "pacifico"], ["zombie", "hostil"],
	]
	
	for pair in role_mode_pairs:
		var role = pair[0]
		var mode = pair[1]
		var tree: BehaviorTree = BTTreeBuilder.build_tree_for_role(role, mode)
		_expect(tree != null, "build_tree_for_role('%s', '%s') returns tree" % [role, mode])
		_expect(tree.get_child_count() == 1, "Tree for %s/%s has root node" % [role, mode])
		var root = tree.get_children()[0]
		_expect(root is BTSelector or root.get_class() == "BTSelector", "Root is Selector for %s/%s" % [role, mode])

func _test_behavior_tree_structure_validity() -> void:
	var roles: Array = ["civil", "police", "soldier", "criminal", "office", "zombie"]
	var modes: Array = ["pacifico", "hostil"]
	
	for role in roles:
		for mode in modes:
			var tree: BehaviorTree = BTTreeBuilder.build_tree_for_role(role, mode)
			_validate_tree_structure(tree, "%s/%s" % [role, mode])

func _validate_tree_structure(tree: BehaviorTree, label: String) -> void:
	var root = tree.get_children()[0] if tree.get_child_count() > 0 else null
	_expect(root != null, "%s has root node" % label)
	
	if root:
		_validate_node(root, label, 0)

func _validate_node(node: Object, label: String, depth: int) -> void:
	if depth > 20:
		_expect(false, "%s tree depth exceeds limit (possible cycle)" % label)
		return
	
	var children = node.get_children()
	if children.size() == 0:
		_expect(node is BTAction or node.get_class() == "BTAction" or 
			   node is BTAlwaysReturn or node.get_class() == "BTAlwaysReturn" or
			   node is BTCondition or node.get_class() == "BTCondition",
			   "%s leaf node is Action, AlwaysReturn, or Condition at depth %d" % [label, depth])
	else:
		_expect(node is BTSelector or node.get_class() == "BTSelector" or
			   node is BTSequence or node.get_class() == "BTSequence" or
			   node is BTParallel or node.get_class() == "BTParallel" or
			   node is BTRepeater or node.get_class() == "BTRepeater" or
			   node is BTRepeatUntil or node.get_class() == "BTRepeatUntil" or
			   node is BTInverter or node.get_class() == "BTInverter" or
			   node is BTAlwaysReturn or node.get_class() == "BTAlwaysReturn",
			   "%s composite node at depth %d is valid type" % [label, depth])
		
		for child in children:
			_validate_node(child, label, depth + 1)