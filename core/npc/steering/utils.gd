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
# Math and vector utility functions.
# Adapted from godot-steering-ai-framework (GDQuest, MIT License)
# Original: GSAIUtils.gd
# @Category - Utilities
class_name SteeringUtils


# Returns the `vector` with its length capped to `limit`.
static func clampedv3(vector: Vector3, limit: float) -> Vector3:
	var length_squared := vector.length_squared()
	var limit_squared := limit * limit
	if length_squared > limit_squared:
		vector *= sqrt(limit_squared / length_squared)
	return vector


# Returns an angle in radians between the positive X axis and the `vector`.
#
# This assumes orientation for 3D agents that are upright and rotate
# around the Y axis.
static func vector3_to_angle(vector: Vector3) -> float:
	return atan2(vector.x, vector.z)


# Returns an angle in radians between the positive X axis and the `vector`.
static func vector2_to_angle(vector: Vector2) -> float:
	return atan2(vector.x, -vector.y)


# Returns a directional vector from the given orientation angle.
# 
# This assumes orientation for 2D agents or 3D agents that are upright and
# rotate around the Y axis.
static func angle_to_vector2(angle: float) -> Vector2:
	return Vector2(sin(-angle), cos(angle))


# Returns a vector2 with `vector`'s x and y components.
static func to_vector2(vector: Vector3) -> Vector2:
	return Vector2(vector.x, vector.y)


# Returns a vector3 with `vector`'s x and y components and 0 in z.
static func to_vector3(vector: Vector2) -> Vector3:
	return Vector3(vector.x, vector.y, 0)