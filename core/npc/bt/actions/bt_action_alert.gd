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
# Adapted for Godot 4.7 and UNTITLED project: alert action.

class_name BTActionAlert
extends BTAction

@export var alert_duration: float = 10.0

var _alert_end_time: float = 0.0

func execute_action(tick: Variant) -> int:
	var context: BTContext = tick if tick is BTContext else null
	if context == null or context.actor == null:
		return FAILED
	
	var blackboard = context.blackboard
	var current_time = blackboard.get_value("current_time", context.tree) or 0.0
	
	var actor = context.actor
	var threat_pos = blackboard.get_value("threat_position", context.tree) or Vector3.ZERO
	
	if _alert_end_time == 0.0:
		_alert_end_time = current_time + alert_duration
	
	if actor is Node3D and threat_pos != Vector3.ZERO:
		actor.look_at(threat_pos + Vector3.UP, Vector3.UP)
	
	blackboard.set_value("alert_level", 1.0, context.tree)
	blackboard.set_value("movement_type", "idle", context.tree)
	blackboard.set_value("alert_active", true, context.tree)
	
	if current_time >= _alert_end_time:
		_alert_end_time = 0.0
		blackboard.set_value("alert_active", false, context.tree)
		return OK
	
	return RUNNING