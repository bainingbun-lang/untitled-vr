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
# Base class for all steering behaviors.
#
# Steering behaviors calculate the linear and the angular acceleration to be
# to the agent that owns them.
#
# The `calculate_steering` function is the entry point for all behaviors.
# Individual steering behaviors encapsulate the steering logic.
# Adapted from godot-steering-ai-framework (GDQuest, MIT License)
# Original: GSAISteeringBehavior.gd
# @category - Base types
class_name SteeringBehavior


# If `false`, all calculations return zero amounts of acceleration.
var is_enabled := true
# The AI agent on which the steering behavior bases its calculations.
var agent: SteeringAgent


func _init(_agent: SteeringAgent) -> void:
	self.agent = _agent


# Sets the `acceleration` with the behavior's desired amount of acceleration.
func calculate_steering(acceleration: TargetAcceleration) -> void:
	if is_enabled:
		_calculate_steering(acceleration)
	else:
		acceleration.set_zero()


func _calculate_steering(acceleration: TargetAcceleration) -> void:
	acceleration.set_zero()