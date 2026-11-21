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
# Adapted for Godot 4.7 and UNTITLED project: has advantage condition.

class_name BTConditionHasAdvantage
extends BTCondition

@export var health_advantage: float = 0.2

func check(tick: Variant) -> bool:
	var context: BTContext = tick if tick is BTContext else null
	if context == null or context.actor == null:
		return false
	
	var blackboard = context.blackboard
	var actor = context.actor
	
	var own_health_ratio: float = 1.0
	if actor.has_method("health_ratio"):
		own_health_ratio = float(actor.call("health_ratio"))
	elif blackboard.has_value("health_ratio", context.tree):
		own_health_ratio = float(blackboard.get_value("health_ratio", context.tree))
	
	var target = blackboard.get_value("target", context.tree)
	if target == null or not is_instance_valid(target):
		return false
	
	var target_health_ratio: float = 1.0
	if target.has_method("health_ratio"):
		target_health_ratio = float(target.call("health_ratio"))
	elif target.has("health") and target.has("max_health"):
		var h: float = float(target.health)
		var mh: float = float(target.max_health)
		if mh > 0.0:
			target_health_ratio = clampf(h / mh, 0.0, 1.0)
	
	if own_health_ratio > target_health_ratio + health_advantage:
		return true
	
	var allies_nearby = int(blackboard.get_value("allies_nearby", context.tree) or 0)
	var enemies_nearby = int(blackboard.get_value("enemies_nearby", context.tree) or 0)
	
	if allies_nearby > enemies_nearby:
		return true
	
	return false