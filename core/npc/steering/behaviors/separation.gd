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
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Calculates an acceleration that repels the agent from its neighbors in the
# given `Proximity`.
#
# The acceleration is an average based on all neighbors, multiplied by a
# strength decreasing by the inverse square law in relation to distance, and it
# accumulates.
# Adapted from godot-steering-ai-framework (GDQuest, MIT License)
# Original: GSAISeparation.gd
# @category - Group behaviors
class_name Separation
extends GroupBehavior


# The coefficient to calculate how fast the separation strength decays with distance.
var decay_coefficient := 1.0


var _acceleration: TargetAcceleration


func _init(agent: SteeringAgent, proximity: Proximity) -> void:
	super._init(agent, proximity)


func _calculate_steering(acceleration: TargetAcceleration) -> void:
	acceleration.set_zero()
	self._acceleration = acceleration
	# warning-ignore:return_value_discarded
	proximity._find_neighbors(_callback)


# Callback for the proximity to call when finding neighbors. Determines the amount of
# acceleration that `neighbor` imposes based on its distance from the owner agent.
# @tags - virtual
func _report_neighbor(neighbor: SteeringAgent) -> bool:
	var to_agent := agent.position - neighbor.position

	var distance_squared := to_agent.length_squared()
	var acceleration_max := agent.linear_acceleration_max

	var strength := decay_coefficient / distance_squared
	if strength > acceleration_max:
		strength = acceleration_max

	_acceleration.linear += to_agent * (strength / sqrt(distance_squared))

	return true