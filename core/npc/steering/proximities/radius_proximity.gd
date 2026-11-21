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
# Determines any agent that is in the specified list as being neighbors with the owner agent if
# they lie within the specified radius.
# Adapted from godot-steering-ai-framework (GDQuest, MIT License)
# Original: GSAIRadiusProximity.gd
# @category - Proximities
class_name RadiusProximity
extends Proximity


# The radius around the owning agent to find neighbors in
var radius := 0.0


var _last_frame := 0
var _scene_tree: SceneTree


func _init(agent: SteeringAgent, agents: Array, _radius: float) -> void:
	super._init(agent, agents)
	self.radius = _radius
	_scene_tree = Engine.get_main_loop()


# Returns a number of neighbors based on a `callback` function.
#
# `_find_neighbors` calls `callback` for each agent in the `agents` array that lie within
# the radius around the owning agent and adds one to the count if its `callback` returns true.
# @tags - virtual
func _find_neighbors(callback: Callable) -> int:
	var agent_count := agents.size()
	var neighbor_count := 0

	var current_frame := _scene_tree.get_frame() if _scene_tree else -_last_frame
	if current_frame != _last_frame:
		_last_frame = current_frame

		var owner_position := agent.position

		for i in range(agent_count):
			var current_agent := agents[i] as SteeringAgent

			if current_agent != agent:
				var distance_squared := owner_position.distance_squared_to(current_agent.position)

				var range_to := radius + current_agent.bounding_radius

				if distance_squared < range_to * range_to:
					if callback.call(current_agent):
						current_agent.is_tagged = true
						neighbor_count += 1
						continue

			current_agent.is_tagged = false
	else:
		for i in range(agent_count):
			var current_agent = agents[i] as SteeringAgent

			if current_agent != agent and current_agent.is_tagged:
				if callback.call(current_agent):
					neighbor_count += 1

	return neighbor_count