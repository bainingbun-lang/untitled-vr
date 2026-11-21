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
# Calculates an acceleration to take an agent to a target agent's position
# directly.
# Adapted from godot-steering-ai-framework (GDQuest, MIT License)
# Original: GSAISeek.gd
# @category - Individual behaviors
class_name Seek
extends SteeringBehavior


# The target that the behavior aims to move the agent to.
var target: SteeringAgentLocation


func _init(agent: SteeringAgent, _target: SteeringAgentLocation) -> void:
	super._init(agent)
	self.target = _target


func _calculate_steering(acceleration: TargetAcceleration) -> void:
	acceleration.linear = (
		(target.position - agent.position).normalized()
		* agent.linear_acceleration_max
	)
	acceleration.angular = 0