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
# Adapted for Godot 4.7 and UNTITLED project: chase action.

class_name BTActionChase
extends BTAction

@export var chase_speed: float = 5.0
@export var attack_range: float = 2.0

func execute_action(tick: Variant) -> int:
	var context: BTContext = tick if tick is BTContext else null
	if context == null or context.actor == null:
		return FAILED
	
	var blackboard = context.blackboard
	var actor = context.actor
	
	var target = blackboard.get_value("target", context.tree)
	if target == null or not is_instance_valid(target):
		return FAILED
	
	var actor_pos = actor.global_position if actor is Node3D else Vector3.ZERO
	var target_pos = target.global_position if target is Node3D else Vector3.ZERO
	
	var to_target = target_pos - actor_pos
	var distance = to_target.length()
	
	if distance <= attack_range:
		blackboard.set_value("move_target", actor_pos, context.tree)
		blackboard.set_value("movement_type", "idle", context.tree)
		return OK
	
	blackboard.set_value("move_target", target_pos, context.tree)
	blackboard.set_value("movement_type", "run", context.tree)
	blackboard.set_value("chase_speed", chase_speed, context.tree)
	
	return RUNNING