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

class_name BTNode
extends RefCounted

const OK = 1
const SUCCESS = 1
const FAILED = 2
const RUNNING = 3
const ERR_BUSY = 3
const ERR_ERROR = 4

var _children: Array[BTNode] = []

func _init() -> void:
	_children = []

func get_children() -> Array[BTNode]:
	return _children

func add_child(node: BTNode) -> void:
	if node == null:
		return
	if node in _children:
		return
	_children.append(node)

func remove_child(node: BTNode) -> void:
	_children.erase(node)

func clear_children() -> void:
	_children.clear()

func get_child_count() -> int:
	return _children.size()

func execute(tick: Variant) -> int:
	_enter(tick)
	
	if not tick.blackboard.get_value("is_open", tick.tree, self):
		_open(tick)
	
	var status: int = _tick(tick)
	
	if status != ERR_BUSY:
		_close(tick)
	
	_exit(tick)
	
	return status

func _enter(tick: Variant) -> void:
	enter(tick)

func _open(tick: Variant) -> void:
	tick.blackboard.set_value("is_open", true, tick.tree, self)
	open(tick)

func _tick(tick: Variant) -> int:
	return tick(tick)

func _close(tick: Variant) -> void:
	tick.blackboard.set_value("is_open", false, tick.tree, self)
	close(tick)

func _exit(tick: Variant) -> void:
	exit(tick)

func enter(tick: Variant) -> void:
	pass

func open(tick: Variant) -> void:
	pass

func tick(tick: Variant) -> int:
	return OK

func close(tick: Variant) -> void:
	pass

func exit(tick: Variant) -> void:
	pass