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
# Adapted for Godot 4.7 and UNTITLED project: wander action.

class_name BTActionWander
extends BTAction

@export var wander_radius: float = 15.0
@export var change_target_interval: float = 5.0

var _next_target_time: float = 0.0
var _current_target: Vector3 = Vector3.ZERO

func execute_action(tick: Variant) -> int:
	var context: BTContext = tick if tick is BTContext else null
	if context == null or context.actor == null:
		return FAILED
	
	var blackboard = context.blackboard
	var current_time = blackboard.get_value("current_time", context.tree) or 0.0
	
	var actor = context.actor
	var global_pos = actor.global_position if actor is Node3D else Vector3.ZERO
	
	if current_time >= _next_target_time or _current_target == Vector3.ZERO:
		var angle = randf() * TAU
		var distance = randf_range(2.0, wander_radius)
		_current_target = global_pos + Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		_next_target_time = current_time + change_target_interval
		blackboard.set_value("move_target", _current_target, context.tree)
		blackboard.set_value("movement_type", "walk", context.tree)
	
	var to_target = _current_target - global_pos
	to_target.y = 0
	
	if to_target.length() < 1.0:
		return OK
	
	return RUNNING