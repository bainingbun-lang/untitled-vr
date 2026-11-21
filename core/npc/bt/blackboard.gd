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

class_name BTBlackboard
extends RefCounted

var _base_memory: Dictionary = {}
var _tree_memory: Dictionary = {}

func _init() -> void:
	_base_memory = {}
	_tree_memory = {}

func set_value(key: String, value: Variant, behavior_tree: Object = null, node_scope: Object = null) -> void:
	var memory: Dictionary = _get_memory(behavior_tree, node_scope)
	memory[key] = value

func get_value(key: String, behavior_tree: Object = null, node_scope: Object = null) -> Variant:
	var memory: Dictionary = _get_memory(behavior_tree, node_scope)
	
	if memory.has(key):
		return memory[key]
	
	return null

func _get_memory(behavior_tree: Object, node_scope: Object) -> Dictionary:
	var memory: Dictionary = _base_memory
	
	if behavior_tree:
		memory = _get_tree_memory(behavior_tree)
		
		if node_scope:
			memory = _get_node_memory(memory, node_scope)
	
	return memory

func _get_tree_memory(behavior_tree: Object) -> Dictionary:
	if not _tree_memory.has(behavior_tree):
		_tree_memory[behavior_tree] = {
			"node_memory": {},
			"open_nodes": []
		}
	
	return _tree_memory[behavior_tree]

func _get_node_memory(tree_memory: Dictionary, node_scope: Object) -> Dictionary:
	var memory: Dictionary = tree_memory["node_memory"]
	
	if not memory.has(node_scope):
		memory[node_scope] = {}
	
	return memory[node_scope]

func clear() -> void:
	_base_memory.clear()
	_tree_memory.clear()