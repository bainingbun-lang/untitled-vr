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
# Adapted for Godot 4.7 and UNTITLED project: suspicious activity condition.

class_name BTConditionSuspiciousActivity
extends BTCondition

@export var awareness_threshold: float = 0.4

func check(tick: Variant) -> bool:
	var context: BTContext = tick if tick is BTContext else null
	if context == null:
		return false
	
	var blackboard = context.blackboard
	
	var alert_level = blackboard.get_value("alert_level", context.tree) or 0.0
	if float(alert_level) > awareness_threshold:
		return true
	
	var suspicious = blackboard.get_value("suspicious_activity", context.tree) or false
	if bool(suspicious):
		return true
	
	var player_visible = blackboard.get_value("player_visible", context.tree) or false
	var player_distance = blackboard.get_value("player_distance", context.tree) or 100.0
	if bool(player_visible) and float(player_distance) < 15.0:
		var actor = context.actor
		var controller = actor.get("controller") if actor and actor.has_method("get") else null
		if controller:
			var personality = controller.personality if controller.has_method("get") or controller.has("personality") else null
			if personality and float(personality.bravery) < 0.6:
				return true
	
	return false