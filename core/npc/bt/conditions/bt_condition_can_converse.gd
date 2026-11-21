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
# Adapted for Godot 4.7 and UNTITLED project: can converse condition.

class_name BTConditionCanConverse
extends BTCondition

@export var min_sociability: float = 0.4
@export var max_fear: float = 0.3
@export var require_partner: bool = true

func check(tick: Variant) -> bool:
	var context: BTContext = tick if tick is BTContext else null
	if context == null or context.actor == null:
		return false
	
	var blackboard = context.blackboard
	var actor = context.actor
	var controller = actor.get("controller") if actor.has_method("get") else null
	if controller == null:
		return false
	
	var personality = controller.personality if controller.has_method("get") or controller.has("personality") else null
	var needs = controller.needs if controller.has_method("get") or controller.has("needs") else null
	var routine = controller.routine if controller.has_method("get") or controller.has("routine") else null
	var memory = controller.memory if controller.has_method("get") or controller.has("memory") else null
	
	if personality == null or needs == null:
		return false
	
	if float(personality.sociability) < min_sociability:
		return false
	
	if float(needs.fear) > max_fear:
		return false
	
	if float(needs.social) > 0.7:
		return false
	
	if require_partner and memory != null:
		var partners = memory.get_conversation_partners()
		if partners.size() == 0:
			var known_civilians = memory.get_known_entities("civil", 0.0)
			if known_civilians.size() == 0:
				return false
	
	var sim_hour = blackboard.get_value("sim_hour", context.tree) or 12.0
	if sim_hour < 6.0 or sim_hour > 23.0:
		return false
	
	var behavior_mode = blackboard.get_value("behavior_mode", context.tree) or "pacifico"
	if str(behavior_mode) != "pacifico":
		return false
	
	return true