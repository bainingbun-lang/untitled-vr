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
# Adapted for Godot 4.7 and UNTITLED project: hide action.

class_name BTActionHide
extends BTAction

@export var hide_duration_min: float = 30.0
@export var hide_duration_max: float = 120.0
@export var hide_spot_search_radius: float = 20.0

var _hide_end_time: float = 0.0
var _hide_spot: Vector3 = Vector3.ZERO

func execute_action(tick: Variant) -> int:
	var context: BTContext = tick if tick is BTContext else null
	if context == null or context.actor == null:
		return FAILED
	
	var blackboard = context.blackboard
	var current_time = blackboard.get_value("current_time", context.tree) or 0.0
	
	var actor = context.actor
	var global_pos = actor.global_position if actor is Node3D else Vector3.ZERO
	var controller = actor.get("controller") if actor.has_method("get") else null
	var memory = controller.memory if controller and controller.has_method("get") or (controller and controller.has("memory")) else null
	
	if _hide_end_time == 0.0 or _hide_spot == Vector3.ZERO:
		_hide_spot = _find_hide_spot(global_pos, memory)
		if _hide_spot == Vector3.ZERO:
			return FAILED
		
		_hide_end_time = current_time + randf_range(hide_duration_min, hide_duration_max)
		blackboard.set_value("move_target", _hide_spot, context.tree)
		blackboard.set_value("movement_type", "run", context.tree)
	
	var to_spot = _hide_spot - global_pos
	to_spot.y = 0
	
	if to_spot.length() < 1.5:
		if current_time >= _hide_end_time:
			_hide_end_time = 0.0
			_hide_spot = Vector3.ZERO
			return OK
		return RUNNING
	
	return RUNNING

func _find_hide_spot(position: Vector3, memory: NPCMemory) -> Vector3:
	# Try to find a known favorite spot of type "cover"
	if memory != null:
		var spots = memory.get_favorite_spots("cover")
		for spot in spots:
			var spot_pos = Vector3(spot["position"].x, position.y, spot["position"].y)
			if (spot_pos - position).length() < hide_spot_search_radius:
				return spot_pos
	
	# Fallback: random position behind obstacles would need navigation
	# For now, return a position away from current
	var angle = randf() * TAU
	return position + Vector3(cos(angle) * hide_spot_search_radius, 0, sin(angle) * hide_spot_search_radius)