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
# Steers the agent to avoid obstacles in its path. Approximates obstacles as
# spheres.
# Adapted from godot-steering-ai-framework (GDQuest, MIT License)
# Original: GSAIAvoidCollisions.gd
# @category - Group behaviors
class_name AvoidCollisions
extends GroupBehavior


var _first_neighbor: SteeringAgent
var _shortest_time: float
var _first_minimum_separation: float
var _first_distance: float
var _first_relative_position: Vector3
var _first_relative_velocity: Vector3


func _init(agent: SteeringAgent, proximity: Proximity) -> void:
	super._init(agent, proximity)


func _calculate_steering(acceleration: TargetAcceleration) -> void:
	_shortest_time = INF
	_first_neighbor = null
	_first_minimum_separation = 0
	_first_distance = 0

	var neighbor_count := proximity._find_neighbors(_callback)

	if neighbor_count == 0 or not _first_neighbor:
		acceleration.set_zero()
	else:
		if (
			_first_minimum_separation <= 0
			or _first_distance < agent.bounding_radius + _first_neighbor.bounding_radius
		):
			acceleration.linear = _first_neighbor.position - agent.position
		else:
			acceleration.linear = (
				_first_relative_position
				+ (_first_relative_velocity * _shortest_time)
			)

	acceleration.linear = (acceleration.linear.normalized() * -agent.linear_acceleration_max)
	acceleration.angular = 0


# Callback for the proximity to call when finding neighbors. Keeps track of every `neighbor`
# that was found but only keeps the one the owning agent will most likely collide with.
# @tags - virtual
func _report_neighbor(neighbor: SteeringAgent) -> bool:
	var relative_position := neighbor.position - agent.position
	var relative_velocity := neighbor.linear_velocity - agent.linear_velocity
	var relative_speed_squared := relative_velocity.length_squared()

	if relative_speed_squared == 0:
		return false
	else:
		var time_to_collision = -relative_position.dot(relative_velocity) / relative_speed_squared

		if time_to_collision <= 0 or time_to_collision >= _shortest_time:
			return false
		else:
			var distance = relative_position.length()
			var minimum_separation: float = (
				distance
				- sqrt(relative_speed_squared) * time_to_collision
			)
			if minimum_separation > agent.bounding_radius + neighbor.bounding_radius:
				return false
			else:
				_shortest_time = time_to_collision
				_first_neighbor = neighbor
				_first_minimum_separation = minimum_separation
				_first_distance = distance
				_first_relative_position = relative_position
				_first_relative_velocity = relative_velocity
				return true