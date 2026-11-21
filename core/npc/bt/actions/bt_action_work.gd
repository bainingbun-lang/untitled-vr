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
# Adapted for Godot 4.7 and UNTITLED project: office work action.

class_name BTActionWork
extends BTAction

@export var work_duration_min: float = 1800.0
@export var work_duration_max: float = 3600.0

var _work_end_time: float = 0.0
var _desk_id: String = ""
var _phase: String = "sit_down"

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
	var needs = controller.needs if controller.has_method("get") or controller.has("needs") else null
	
	if routine == null:
		return FAILED
	
	var activity_result = routine.update_activity(current_time, sim_hour)
	
	if activity_result.get("changed", false):
		var new_activity = str(activity_result.get("activity", ""))
		if new_activity != "office_work":
			_work_end_time = 0.0
			_phase = "sit_down"
			return RUNNING
		
		_work_end_time = current_time + randf_range(work_duration_min, work_duration_max)
		_desk_id = str(activity_result.get("desk_id", ""))
		_phase = "sit_down"
	
	if _work_end_time == 0.0:
		_work_end_time = current_time + randf_range(work_duration_min, work_duration_max)
		_phase = "sit_down"
	
	var elapsed = current_time - (_work_end_time - randf_range(work_duration_min, work_duration_max))
	var total_duration = _work_end_time - (_work_end_time - randf_range(work_duration_min, work_duration_max))
	var progress = elapsed / total_duration if total_duration > 0 else 0.0
	
	if progress < 0.1:
		_phase = "sit_down"
		blackboard.set_value("work_phase", "sit_down", context.tree)
		if _desk_id != "":
			blackboard.set_value("interact_target", _desk_id, context.tree)
			blackboard.set_value("interaction_type", "sit", context.tree)
	elif progress < 0.9:
		_phase = "working"
		blackboard.set_value("work_phase", "working", context.tree)
		if needs != null:
			needs.change_boredom(-0.001)
	else:
		_phase = "stand_up"
		blackboard.set_value("work_phase", "stand_up", context.tree)
	
	blackboard.set_value("work_progress", progress, context.tree)
	
	if current_time >= _work_end_time:
		_work_end_time = 0.0
		_phase = "sit_down"
		return OK
	
	return RUNNING