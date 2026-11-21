# Copyright (c) 2020 GDQuest
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
# Calculates an acceleration that attempts to move the agent towards the center
# of mass of the agents in the area defined by the `Proximity`.
# Adapted from godot-steering-ai-framework (GDQuest, MIT License)
# Original: GSAICohesion.gd
# @category - Group behaviors
class_name Cohesion
extends GroupBehavior


var _center_of_mass: Vector3


func _init(agent: SteeringAgent, proximity: Proximity) -> void:
	super._init(agent, proximity)


func _calculate_steering(acceleration: TargetAcceleration) -> void:
	acceleration.set_zero()
	_center_of_mass = Vector3.ZERO
	var neighbor_count = proximity._find_neighbors(_callback)
	if neighbor_count > 0:
		_center_of_mass *= 1.0 / neighbor_count
		acceleration.linear = (
			(_center_of_mass - agent.position).normalized()
			* agent.linear_acceleration_max
		)


# Callback for the proximity to call when finding neighbors. Adds `neighbor`'s position
# to the center of mass of the group.
# @tags - virtual
func _report_neighbor(neighbor: SteeringAgent) -> bool:
	_center_of_mass += neighbor.position
	return true