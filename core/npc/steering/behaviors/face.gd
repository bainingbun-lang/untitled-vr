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
# Calculates angular acceleration to rotate a target to face its target's
# position. The behavior attempts to arrive with zero remaining angular velocity.
# Adapted from godot-steering-ai-framework (GDQuest, MIT License)
# Original: GSAIFace.gd
# @category - Individual behaviors
class_name Face
extends MatchOrientation


func _init(agent: SteeringAgent, target: SteeringAgentLocation, use_z := false) -> void:
	super._init(agent, target, use_z)


func _face(acceleration: TargetAcceleration, target_position: Vector3) -> void:
	var to_target := target_position - agent.position
	var distance_squared := to_target.length_squared()

	if distance_squared < agent.zero_linear_speed_threshold:
		acceleration.set_zero()
	else:
		var orientation = (
			SteeringUtils.vector3_to_angle(to_target)
			if use_z
			else SteeringUtils.vector2_to_angle(SteeringUtils.to_vector2(to_target))
		)
		_match_orientation(acceleration, orientation)


func _calculate_steering(acceleration: TargetAcceleration) -> void:
	_face(acceleration, target.position)