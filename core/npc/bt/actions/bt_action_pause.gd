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
# Adapted for Godot 4.7 and UNTITLED project: pause/look around action.

class_name BTActionPause
extends BTAction

@export var pause_duration_min: float = 2.0
@export var pause_duration_max: float = 5.0
@export var look_around_chance: float = 0.3

var _pause_end_time: float = 0.0
var _is_looking: bool = false

func execute_action(tick: Variant) -> int:
	var context: BTContext = tick if tick is BTContext else null
	if context == null or context.actor == null:
		return FAILED
	
	var blackboard = context.blackboard
	var current_time = blackboard.get_value("current_time", context.tree) or 0.0
	var sim_hour = blackboard.get_value("sim_hour", context.tree) or 12.0
	
	var actor = context.actor
	var controller = actor.get("controller") if actor.has_method("get") else null
	if controller == null:
		return FAILED
	
	var routine = controller.routine if controller.has_method("get") or controller.has("routine") else null
	if routine == null:
		return FAILED
	
	var activity_result = routine.update_activity(current_time, sim_hour)
	
	if activity_result.get("changed", false):
		var new_activity = str(activity_result.get("activity", ""))
		if new_activity != "pause" and new_activity != "look_around":
			return RUNNING
		_pause_end_time = current_time + randf_range(pause_duration_min, pause_duration_max)
		_is_looking = (new_activity == "look_around") or (randf() < look_around_chance)
	
	if _pause_end_time == 0.0:
		_pause_end_time = current_time + randf_range(pause_duration_min, pause_duration_max)
		_is_looking = randf() < look_around_chance
	
	if current_time >= _pause_end_time:
		_pause_end_time = 0.0
		_is_looking = false
		return OK
	
	if _is_looking:
		blackboard.set_value("look_around", true, context.tree)
		blackboard.set_value("pause_type", "look_around", context.tree)
	else:
		blackboard.set_value("pause_type", "idle", context.tree)
	
	return RUNNING