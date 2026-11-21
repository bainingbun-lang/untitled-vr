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

class_name BTContext
extends RefCounted

var tree: BTNode = null
var actor: Object = null
var blackboard: BTBlackboard = null
var debug: bool = false
var open_nodes: Array[BTNode] = []

func _init(p_tree: BTNode = null, p_actor: Object = null, p_blackboard: BTBlackboard = null, p_debug: bool = false) -> void:
	tree = p_tree
	actor = p_actor
	blackboard = p_blackboard if p_blackboard else BTBlackboard.new()
	debug = p_debug
	open_nodes = []

func enter_node(node: BTNode) -> void:
	open_nodes.append(node)
	
	if debug:
		print("BT: Entering node '%s'" % node.get_class())

func tick_node(node: BTNode) -> void:
	if debug:
		print("BT: Ticking node '%s'" % node.get_class())

func close_node(node: BTNode) -> void:
	if open_nodes.has(node):
		open_nodes.erase(node)
		
		if debug:
			print("BT: Closing node '%s'" % node.get_class())

func exit_node(node: BTNode) -> void:
	if debug:
		print("BT: Exiting node '%s'" % node.get_class())

func open_node(node: BTNode) -> void:
	if debug:
		print("BT: Opening node '%s'" % node.get_class())