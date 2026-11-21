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
# 3D CharacterBody3D-based steering agent.
# Adapted from godot-steering-ai-framework (GDQuest, MIT License)
# Original: GSAICharacterBody3DAgent.gd
# @category - Agents
class_name CharacterBody3DSteeringAgent
extends CharacterBody3D
implements SteeringAgent


# SteeringAgent interface properties
var zero_linear_speed_threshold: float = 0.01
var linear_speed_max: float = 10.0
var linear_acceleration_max: float = 20.0
var angular_speed_max: float = 10.0
var angular_acceleration_max: float = 20.0
var linear_velocity: Vector3 = Vector3.ZERO
var angular_velocity: float = 0.0
var bounding_radius: float = 0.5
var is_tagged: bool = false


# SteeringAgentLocation interface properties
var position: Vector3 = Vector3.ZERO
var orientation: float = 0.0


func _physics_process(delta: float) -> void:
	position = global_position
	orientation = global_rotation.y
	linear_velocity = velocity
	angular_velocity = 0.0 # CharacterBody3D doesn't expose angular velocity directly