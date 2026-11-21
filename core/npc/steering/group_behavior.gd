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
# Base type for group-based steering behaviors.
# Adapted from godot-steering-ai-framework (GDQuest, MIT License)
# Original: GSAIGroupBehavior.gd
# @category - Base types
class_name GroupBehavior
extends SteeringBehavior


# Container to find neighbors of the agent and calculate group behavior.
var proximity: Proximity


var _callback := Callable(self, "_report_neighbor")


func _init(agent: SteeringAgent, _proximity: Proximity) -> void:
	super._init(agent)
	self.proximity = _proximity


# Internal callback for the behavior to define whether or not a member is
# relevant
# @tags - virtual
func _report_neighbor(_neighbor: SteeringAgent) -> bool:
	return false