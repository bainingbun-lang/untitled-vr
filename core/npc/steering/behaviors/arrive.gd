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
# Calculates acceleration to take an agent to its target's location. The
# calculation attempts to arrive with zero remaining velocity.
# Adapted from godot-steering-ai-framework (GDQuest, MIT License)
# Original: GSAIArrive.gd
# @category - Individual behaviors
class_name Arrive
extends SteeringBehavior


# Target agent to arrive to.
var target: SteeringAgentLocation
# Distance from the target for the agent to be considered successfully
# arrived.
var arrival_tolerance: float
# Distance from the target for the agent to begin slowing down.
var deceleration_radius: float
# Represents the time it takes to change acceleration.
var time_to_reach: float = 0.1


func _init(agent: SteeringAgent, _target: SteeringAgentLocation) -> void:
	super._init(agent)
	self.target = _target


func _arrive(acceleration: TargetAcceleration, target_position: Vector3) -> void:
	var to_target := target_position - agent.position
	var distance := to_target.length()

	if distance <= arrival_tolerance:
		acceleration.set_zero()
	else:
		var desired_speed := agent.linear_speed_max

		if distance <= deceleration_radius:
			desired_speed *= distance / deceleration_radius

		var desired_velocity := to_target * desired_speed / distance

		desired_velocity = ((desired_velocity - agent.linear_velocity) * 1.0 / time_to_reach)

		acceleration.linear = SteeringUtils.clampedv3(desired_velocity, agent.linear_acceleration_max)
		acceleration.angular = 0


func _calculate_steering(acceleration: TargetAcceleration) -> void:
	_arrive(acceleration, target.position)