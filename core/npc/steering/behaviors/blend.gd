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
# Blends multiple steering behaviors into one, and returns a weighted
# acceleration from their calculations.
#
# Stores the behaviors internally as dictionaries of the form
# {
# 	behavior : SteeringBehavior,
# 	weight : float
# }
# Adapted from godot-steering-ai-framework (GDQuest, MIT License)
# Original: GSAIBlend.gd
# @category - Combination behaviors
class_name Blend
extends SteeringBehavior


var _behaviors := []
var _accel := TargetAcceleration.new()


func _init(agent: SteeringAgent) -> void:
	super._init(agent)


# Appends a behavior to the internal array along with its `weight`.
func add(behavior: SteeringBehavior, weight: float) -> void:
	behavior.agent = agent
	_behaviors.append({behavior = behavior, weight = weight})


# Returns the behavior at the specified `index`, or an empty `Dictionary` if
# none was found.
func get_behavior_at(index: int) -> Dictionary:
	if _behaviors.size() > index:
		return _behaviors[index]
	printerr("Tried to get index " + str(index) + " in array of size " + str(_behaviors.size()))
	return {}


func _calculate_steering(blended_accel: TargetAcceleration, delta: float = 0.0) -> void:
	blended_accel.set_zero()

	for i in range(_behaviors.size()):
		var bw: Dictionary = _behaviors[i]
		bw.behavior._calculate_steering(_accel)

		blended_accel.add_scaled_accel(_accel, bw.weight)

	blended_accel.linear = SteeringUtils.clampedv3(blended_accel.linear, agent.linear_acceleration_max)
	blended_accel.angular = clamp(
		blended_accel.angular, -agent.angular_acceleration_max, agent.angular_acceleration_max
	)