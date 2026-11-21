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
# Calculates an acceleration to make an agent intercept another based on the
# target agent's movement.
# Adapted from godot-steering-ai-framework (GDQuest, MIT License)
# Original: GSAIPursue.gd
# @category - Individual behaviors
class_name Pursue
extends SteeringBehavior


# The target agent that the behavior is trying to intercept.
var target: SteeringAgent
# The maximum amount of time in the future the behavior predicts the target's
# location.
var predict_time_max: float


func _init(agent: SteeringAgent, _target: SteeringAgent, _predict_time_max := 1.0) -> void:
	super._init(agent)
	self.target = _target
	self.predict_time_max = _predict_time_max


func _calculate_steering(acceleration: TargetAcceleration) -> void:
	var target_position := target.position
	var distance_squared := (target_position - agent.position).length_squared()

	var speed_squared := agent.linear_velocity.length_squared()
	var predict_time := predict_time_max

	if speed_squared > 0:
		var predict_time_squared := distance_squared / speed_squared
		if predict_time_squared < predict_time_max * predict_time_max:
			predict_time = sqrt(predict_time_squared)

	acceleration.linear = ((target_position + (target.linear_velocity * predict_time)) - agent.position).normalized()
	acceleration.linear *= _get_modified_acceleration()

	acceleration.angular = 0


func _get_modified_acceleration() -> float:
	return agent.linear_acceleration_max