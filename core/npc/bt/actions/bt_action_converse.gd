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
# Adapted for Godot 4.7 and UNTITLED project: conversation action.

class_name BTActionConverse
extends BTAction

@export var conversation_duration_min: float = 10.0
@export var conversation_duration_max: float = 30.0
@export var requires_partner: bool = true

var _conversation_end_time: float = 0.0
var _partner_id: String = ""

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
	var memory = controller.memory if controller.has_method("get") or controller.has("memory") else null
	var needs = controller.needs if controller.has_method("get") or controller.has("needs") else null
	
	if routine == null:
		return FAILED
	
	var activity_result = routine.update_activity(current_time, sim_hour)
	
	if activity_result.get("changed", false):
		var new_activity = str(activity_result.get("activity", ""))
		if new_activity != "converse":
			_conversation_end_time = 0.0
			_partner_id = ""
			return RUNNING
		
		_conversation_end_time = current_time + randf_range(conversation_duration_min, conversation_duration_max)
		
		var partner = activity_result.get("partner", "")
		if partner != "":
			_partner_id = str(partner)
			routine.set_conversation_partner(_partner_id)
		elif requires_partner:
			_partner_id = _find_conversation_partner(actor, memory)
			if _partner_id != "":
				routine.set_conversation_partner(_partner_id)
			else:
				return FAILED
	
	if _conversation_end_time == 0.0:
		_conversation_end_time = current_time + randf_range(conversation_duration_min, conversation_duration_max)
		if _partner_id == "" and requires_partner:
			_partner_id = _find_conversation_partner(actor, memory)
			if _partner_id != "":
				routine.set_conversation_partner(_partner_id)
			else:
				return FAILED
	
	if needs != null:
		needs.set_socializing(true)
	
	blackboard.set_value("conversation_partner", _partner_id, context.tree)
	blackboard.set_value("conversation_progress", (current_time - (_conversation_end_time - randf_range(conversation_duration_min, conversation_duration_max))) / randf_range(conversation_duration_min, conversation_duration_max), context.tree)
	
	if current_time >= _conversation_end_time:
		if needs != null:
			needs.set_socializing(false)
		if memory != null and _partner_id != "":
			memory.record_conversation(_partner_id, "daily_life", _conversation_end_time - (_conversation_end_time - randf_range(conversation_duration_min, conversation_duration_max)), "positive", current_time)
		_conversation_end_time = 0.0
		_partner_id = ""
		routine.set_conversation_partner("")
		return OK
	
	return RUNNING

func _find_conversation_partner(actor: Object, memory: NPCMemory) -> String:
	if memory == null:
		return ""
	
	var known = memory.get_known_entities("civil", 0.0)
	for entity in known:
		var eid = str(entity.get("id", ""))
		if eid != "" and eid != str(actor.get_instance_id()):
			return eid
	
	return ""