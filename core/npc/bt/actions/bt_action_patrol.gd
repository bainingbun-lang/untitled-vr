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
# Adapted for Godot 4.7 and UNTITLED project: routine patrol action.

class_name BTActionPatrol
extends BTAction

func execute_action(tick: Variant) -> int:
	var context: BTContext = tick if tick is BTContext else null
	if context == null or context.actor == null:
		return FAILED
	
	var actor = context.actor
	var controller = actor.get("controller") if actor.has_method("get") else null
	if controller == null:
		return FAILED
	
	var routine = controller.routine if controller.has_method("get") or controller.has("routine") else null
	if routine == null:
		return FAILED
	
	var blackboard = context.blackboard
	var current_time = blackboard.get_value("current_time", context.tree) or 0.0
	var sim_hour = blackboard.get_value("sim_hour", context.tree) or 12.0
	
	var activity_result = routine.update_activity(current_time, sim_hour)
	
	if activity_result.get("changed", false) and str(activity_result.get("activity", "")) != "patrol":
		return RUNNING
	
	var action = str(activity_result.get("action", "wait"))
	var waypoint = activity_result.get("waypoint", {})
	var waypoint_index = int(activity_result.get("waypoint_index", -1))
	
	blackboard.set_value("current_waypoint", waypoint, context.tree)
	blackboard.set_value("waypoint_index", waypoint_index, context.tree)
	blackboard.set_value("patrol_action", action, context.tree)
	
	if waypoint and waypoint.has("position"):
		var pos = waypoint["position"]
		blackboard.set_value("move_target", Vector3(pos.x, 0, pos.y), context.tree)
		blackboard.set_value("movement_type", "walk", context.tree)
	
	if action == "arrived" and bool(waypoint.get("look_around", false)):
		blackboard.set_value("look_around", true, context.tree)
		return RUNNING
	
	return RUNNING