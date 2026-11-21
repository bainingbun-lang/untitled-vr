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
# Container for multiple behaviors that returns the result of the first child
# behavior with non-zero acceleration.
# Adapted from godot-steering-ai-framework (GDQuest, MIT License)
# Original: GSAIPriority.gd
# @category - Combination behaviors
class_name Priority
extends SteeringBehavior


var _behaviors := []


# The index of the last behavior the container prioritized.
var last_selected_index: int
# If a behavior's acceleration is lower than this threshold, the container
# considers it has an acceleration of zero.
var zero_threshold: float


func _init(agent: SteeringAgent, _zero_threshold := 0.001) -> void:
	super._init(agent)
	self.zero_threshold = _zero_threshold


# Appends a steering behavior as a child of this container.
func add(behavior: SteeringBehavior) -> void:
	_behaviors.append(behavior)


# Returns the behavior at the position in the pool referred to by `index`, or
# `null` if no behavior was found.
func get_behavior_at(index: int) -> SteeringBehavior:
	if _behaviors.size() > index:
		return _behaviors[index]
	printerr("Tried to get index " + str(index) + " in array of size " + str(_behaviors.size()))
	return null


func _calculate_steering(accel: TargetAcceleration) -> void:
	var threshold_squared := zero_threshold * zero_threshold

	last_selected_index = -1

	var size := _behaviors.size()

	if size > 0:
		for i in range(size):
			last_selected_index = i
			var behavior: SteeringBehavior = _behaviors[i]
			behavior.calculate_steering(accel)

			if accel.get_magnitude_squared() > threshold_squared:
				break
	else:
		accel.set_zero()