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
# Adapted for Godot 4.7 and UNTITLED project: loot available condition.

class_name BTConditionLootAvailable
extends BTCondition

@export var search_radius: float = 10.0

func check(tick: Variant) -> bool:
	var context: BTContext = tick if tick is BTContext else null
	if context == null or context.actor == null:
		return false
	
	var blackboard = context.blackboard
	var loot_nearby = blackboard.get_value("loot_nearby", context.tree) or []
	
	if loot_nearby is Array and loot_nearby.size() > 0:
		return true
	
	var actor = context.actor
	var actor_pos = actor.global_position if actor is Node3D else Vector3.ZERO
	var space = actor.get_world_3d().direct_space_state if actor.get_world_3d() else null
	
	if space == null:
		return false
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.transform = Transform3D.IDENTITY.translated(actor_pos)
	var shape = SphereShape3D.new()
	shape.radius = search_radius
	query.shape = shape
	query.collision_mask = 1
	var results = space.intersect_shape(query)
	
	for result in results:
		var collider = result.get("collider")
		if collider and collider.has_method("get_loot_value"):
			return true
		if collider and collider.is_in_group("loot"):
			return true
	
	return false