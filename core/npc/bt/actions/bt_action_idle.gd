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
# Adapted for Godot 4.7 and UNTITLED project: idle action.

class_name BTActionIdle
extends BTAction

@export var idle_duration_min: float = 2.0
@export var idle_duration_max: float = 5.0

var _idle_end_time: float = 0.0

func execute_action(tick: Variant) -> int:
	var context: BTContext = tick if tick is BTContext else null
	if context == null:
		return FAILED
	
	var blackboard = context.blackboard
	var current_time_val = blackboard.get_value("current_time", context.tree)
	var current_time: float = 0.0
	if current_time_val is float:
		current_time = current_time_val
	elif current_time_val is int:
		current_time = float(current_time_val)
	
	var actor = context.actor
	var actor_pos = actor.global_position if actor is Node3D else Vector3.ZERO
	
	if _idle_end_time == 0.0:
		_idle_end_time = current_time + randf_range(idle_duration_min, idle_duration_max)
		var angle = randf() * TAU
		var distance = randf_range(2.0, 8.0)
		var idle_target = actor_pos + Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		blackboard.set_value("move_target", idle_target, context.tree)
	
	blackboard.set_value("movement_type", "idle", context.tree)
	
	if current_time >= _idle_end_time:
		_idle_end_time = 0.0
		return OK
	
	return RUNNING