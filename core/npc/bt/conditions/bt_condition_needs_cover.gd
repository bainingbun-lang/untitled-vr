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
# Adapted for Godot 4.7 and UNTITLED project: needs cover condition.

class_name BTConditionNeedsCover
extends BTCondition

@export var health_threshold: float = 0.5
@export var under_fire_threshold: float = 0.3

func check(tick: Variant) -> bool:
	var context: BTContext = tick if tick is BTContext else null
	if context == null or context.actor == null:
		return false
	
	var blackboard = context.blackboard
	var actor = context.actor
	var controller = actor.get("controller") if actor.has_method("get") else null
	if controller == null:
		return false
	
	var needs = controller.needs if controller.has_method("get") or controller.has("needs") else null
	if needs == null:
		return false
	
	if float(needs.health) < health_threshold:
		return true
	
	var under_fire = blackboard.get_value("under_fire", context.tree) or 0.0
	if float(under_fire) > under_fire_threshold:
		return true
	
	var in_cover = blackboard.get_value("in_cover", context.tree) or false
	if bool(in_cover):
		return false
	
	return true