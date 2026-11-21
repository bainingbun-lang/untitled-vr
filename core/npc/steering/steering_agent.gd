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
# Adds velocity, speed, and size data to `SteeringAgentLocation`.
#
# It is the character's responsibility to keep this information up to date for
# the steering toolkit to work correctly.
# Adapted from godot-steering-ai-framework (GDQuest, MIT License)
# Original: GSAISteeringAgent.gd
# @category - Base types
class_name SteeringAgent
extends SteeringAgentLocation


# The amount of velocity to be considered effectively not moving.
var zero_linear_speed_threshold: float = 0.01
# The maximum speed at which the agent can move.
var linear_speed_max: float = 0.0
# The maximum amount of acceleration that any behavior can apply to the agent.
var linear_acceleration_max: float = 0.0
# The maximum amount of angular speed at which the agent can rotate.
var angular_speed_max: float = 0.0
# The maximum amount of angular acceleration that any behavior can apply to an
# agent.
var angular_acceleration_max: float = 0.0
# Current velocity of the agent.
var linear_velocity: Vector3 = Vector3.ZERO
# Current angular velocity of the agent.
var angular_velocity: float = 0.0
# The radius of the sphere that approximates the agent's size in space.
var bounding_radius: float = 0.0
# Used internally by group behaviors and proximities to mark the agent as already
# considered.
var is_tagged: bool = false