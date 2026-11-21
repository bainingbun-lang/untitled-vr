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
# Adapted for Godot 4.7 and UNTITLED project: flee action.

class_name BTActionFlee
extends BTAction

@export var flee_distance: float = 20.0
@export var safe_distance: float = 30.0

var _flee_target: Vector3 = Vector3.ZERO

func execute_action(tick: Variant) -> int:
	var context: BTContext = tick if tick is BTContext else null
	if context == null or context.actor == null:
		return FAILED
	
	var blackboard = context.blackboard
	var current_time = blackboard.get_value("current_time", context.tree) or 0.0
	
	var actor = context.actor
	var actor_pos = actor.global_position if actor is Node3D else Vector3.ZERO
	
	var threat = blackboard.get_value("threat_position", context.tree) or Vector3.ZERO
	var threat_pos = threat if threat is Vector3 else Vector3.ZERO
	
	if _flee_target == Vector3.ZERO or actor_pos.distance_to(_flee_target) < 3.0:
		if threat_pos != Vector3.ZERO:
			var away_dir = (actor_pos - threat_pos).normalized()
			if away_dir == Vector3.ZERO:
				away_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
			_flee_target = actor_pos + away_dir * flee_distance
		else:
			var angle = randf() * TAU
			_flee_target = actor_pos + Vector3(cos(angle) * flee_distance, 0, sin(angle) * flee_distance)
		
		blackboard.set_value("move_target", _flee_target, context.tree)
		blackboard.set_value("movement_type", "run", context.tree)
	
	var to_target = _flee_target - actor_pos
	to_target.y = 0
	
	if threat_pos != Vector3.ZERO:
		var dist_to_threat = actor_pos.distance_to(threat_pos)
		if dist_to_threat > safe_distance:
			_flee_target = Vector3.ZERO
			return OK
	
	if to_target.length() < 2.0:
		_flee_target = Vector3.ZERO
		return OK
	
	return RUNNING