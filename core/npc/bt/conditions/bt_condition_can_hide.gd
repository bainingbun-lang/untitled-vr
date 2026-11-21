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
# Adapted for Godot 4.7 and UNTITLED project: can hide condition.

class_name BTConditionCanHide
extends BTCondition

@export var min_fear: float = 0.5

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
	var memory = controller.memory if controller.has_method("get") or controller.has("memory") else null
	
	if needs == null:
		return false
	
	if float(needs.fear) < min_fear:
		return false
	
	if memory != null:
		var spots = memory.get_favorite_spots("cover")
		if spots.size() > 0:
			return true
	
	var actor_pos = actor.global_position if actor is Node3D else Vector3.ZERO
	var space = actor.get_world_3d().direct_space_state if actor.get_world_3d() else null
	
	if space == null:
		return false
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.transform = Transform3D.IDENTITY.translated(actor_pos)
	var shape = SphereShape3D.new()
	shape.radius = 15.0
	query.shape = shape
	query.collision_mask = 1
	var results = space.intersect_shape(query)
	
	for result in results:
		var collider = result.get("collider")
		if collider and collider.is_in_group("cover"):
			return true
	
	return true