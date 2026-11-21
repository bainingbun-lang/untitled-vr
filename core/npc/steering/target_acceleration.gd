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
# A desired linear and angular amount of acceleration requested by the steering
# system.
# Adapted from godot-steering-ai-framework (GDQuest, MIT License)
# Original: GSAITargetAcceleration.gd
# @category - Base types
class_name TargetAcceleration


# Linear acceleration
var linear := Vector3.ZERO
# Angular acceleration
var angular := 0.0


# Sets the linear and angular components to 0.
func set_zero() -> void:
	linear.x = 0.0
	linear.y = 0.0
	linear.z = 0.0
	angular = 0.0


# Adds `accel`'s components, multiplied by `scalar`, to this one.
func add_scaled_accel(accel: TargetAcceleration, scalar: float) -> void:
	linear += accel.linear * scalar
	angular += accel.angular * scalar


# Returns the squared magnitude of the linear and angular components.
func get_magnitude_squared() -> float:
	return linear.length_squared() + angular * angular


# Returns the magnitude of the linear and angular components.
func get_magnitude() -> float:
	return sqrt(get_magnitude_squared())