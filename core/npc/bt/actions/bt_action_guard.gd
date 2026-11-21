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
# Adapted for Godot 4.7 and UNTITLED project: guard action.

class_name BTActionGuard
extends BTAction

@export var guard_radius: float = 5.0
@export var patrol_interval: float = 10.0

var _guard_post: Vector3 = Vector3.ZERO
var _last_patrol_time: float = 0.0
var _patrol_target: Vector3 = Vector3.ZERO

func execute_action(tick: Variant) -> int:
	var context: BTContext = tick if tick is BTContext else null
	if context == null or context.actor == null:
		return FAILED
	
	var blackboard = context.blackboard
	var current_time = blackboard.get_value("current_time", context.tree) or 0.0
	
	var actor = context.actor
	var actor_pos = actor.global_position if actor is Node3D else Vector3.ZERO
	
	var guard_post = blackboard.get_value("guard_post", context.tree)
	if guard_post != null:
		if guard_post is Vector3:
			_guard_post = guard_post
		elif guard_post is Vector2:
			_guard_post = Vector3(guard_post.x, actor_pos.y, guard_post.y)
	
	if _guard_post == Vector3.ZERO:
		_guard_post = actor_pos
	
	var distance_to_post = actor_pos.distance_to(_guard_post)
	if distance_to_post > guard_radius:
		blackboard.set_value("move_target", _guard_post, context.tree)
		blackboard.set_value("movement_type", "walk", context.tree)
		return RUNNING
	
	if current_time - _last_patrol_time >= patrol_interval:
		var angle = randf() * TAU
		var dist = randf_range(1.0, guard_radius)
		_patrol_target = _guard_post + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		_last_patrol_time = current_time
		blackboard.set_value("move_target", _patrol_target, context.tree)
		blackboard.set_value("movement_type", "walk", context.tree)
		return RUNNING
	
	if _patrol_target != Vector3.ZERO:
		var to_patrol = _patrol_target - actor_pos
		to_patrol.y = 0
		if to_patrol.length() < 1.0:
			_patrol_target = Vector3.ZERO
		return RUNNING
	
	blackboard.set_value("movement_type", "idle", context.tree)
	blackboard.set_value("guard_active", true, context.tree)
	
	return RUNNING