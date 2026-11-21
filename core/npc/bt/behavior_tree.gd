# Copyright (c) 2016 Jeffery Olson
# Copyright (c) 2016 Brandon Lamb
# Copyright (c) 2017 Sebastian Ebert
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Adapted for Godot 4.7 and UNTITLED project: removed editor dependencies,
# converted to pure GDScript RefCounted, simplified API.

class_name BehaviorTree
extends BTNode

var _blackboard: BTBlackboard = null
var _debug: bool = false

func _init(p_blackboard: BTBlackboard = null, p_debug: bool = false) -> void:
	_blackboard = p_blackboard if p_blackboard else BTBlackboard.new()
	_debug = p_debug

func _tick(tick: Variant) -> int:
	var context: BTContext = tick if tick is BTContext else BTContext.new(self, tick.get("actor") if tick else null, tick.get("blackboard") if tick else _blackboard, tick.get("debug", false) if tick else _debug)
	
	var result: int = FAILED
	
	for child in get_children():
		result = child.execute(context)
	
	# Close nodes from last tick, if needed
	var last_open_nodes: Array = context.blackboard.get_value("open_nodes", self)
	var current_open_nodes: Array = context.open_nodes
	
	# If node isn't currently open, but was open during last tick, close it
	for node in last_open_nodes:
		if not current_open_nodes.has(node) and context.blackboard.get_value("is_open", self, node):
			node._close(context)
	
	# Populate the blackboard
	context.blackboard.set_value("open_nodes", current_open_nodes, self)
	
	return result

func tick_with(actor: Object, blackboard: BTBlackboard = null, debug: bool = false) -> int:
	var context: BTContext = BTContext.new(self, actor, blackboard if blackboard else _blackboard, debug)
	return execute(context)

func get_blackboard() -> BTBlackboard:
	return _blackboard

func set_debug(enabled: bool) -> void:
	_debug = enabled

func is_debug() -> bool:
	return _debug

func clear_blackboard() -> void:
	_blackboard.clear()