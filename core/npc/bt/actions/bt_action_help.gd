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
# Adapted for Godot 4.7 and UNTITLED project: help action.

class_name BTActionHelp
extends BTAction

@export var help_range: float = 10.0
@export var help_duration: float = 5.0

var _help_target: Object = null
var _help_end_time: float = 0.0

func execute_action(tick: Variant) -> int:
	var context: BTContext = tick if tick is BTContext else null
	if context == null or context.actor == null:
		return FAILED
	
	var blackboard = context.blackboard
	var current_time = blackboard.get_value("current_time", context.tree) or 0.0
	
	var actor = context.actor
	var actor_pos = actor.global_position if actor is Node3D else Vector3.ZERO
	
	if _help_target == null or not is_instance_valid(_help_target):
		var allies = blackboard.get_value("injured_allies", context.tree)
		if allies is Array and allies.size() > 0:
			_help_target = allies[0]
			_help_end_time = current_time + help_duration
		else:
			return FAILED
	
	if _help_target == null or not is_instance_valid(_help_target):
		return FAILED
	
	var target_pos = _help_target.global_position if _help_target is Node3D else Vector3.ZERO
	var distance = actor_pos.distance_to(target_pos)
	
	if distance > help_range:
		blackboard.set_value("move_target", target_pos, context.tree)
		blackboard.set_value("movement_type", "run", context.tree)
		return RUNNING
	
	blackboard.set_value("move_target", actor_pos, context.tree)
	blackboard.set_value("movement_type", "idle", context.tree)
	blackboard.set_value("helping_target", _help_target, context.tree)
	blackboard.set_value("heal_action", true, context.tree)
	
	if current_time >= _help_end_time:
		_help_target = null
		_help_end_time = 0.0
		return OK
	
	return RUNNING