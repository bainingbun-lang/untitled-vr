# High-level steering API for NPC navigation.
# Computes steering acceleration combining separation, obstacle avoidance, and turn smoothing.
# Integrates with NPCNavigation grid for wall/obstacle avoidance.
# Adapted from godot-steering-ai-framework (GDQuest, MIT License)
# @category - High-level API
class_name NpcSteering
extends RefCounted


# Separation behavior instance
var _separation: Separation = null
# Obstacle avoidance behavior instance
var _obstacle_avoidance: ObstacleAvoidance = null
# Face behavior for turn smoothing
var _face: Face = null
# Blend container for combining behaviors
var _blend: Blend = null
# Priority container for fallback selection
var _priority: Priority = null
# Pooled acceleration for reuse (no frame allocations)
var _accel_pool: TargetAcceleration = null
# Pooled acceleration for individual behaviors
var _temp_accel: TargetAcceleration = null
# Navigation reference for grid-based obstacle avoidance
var _navigation: NPCNavigation = null
# Cell size for navigation grid
var _nav_cell_size: float = 1.0
# Maximum neighbor count to process per frame (performance)
var _max_neighbors: int = 8
# Separation weight
var _separation_weight: float = 2.0
# Obstacle avoidance weight
var _obstacle_weight: float = 3.0
# Face/turn weight
var _face_weight: float = 1.0
# Minimum distance to maintain from other NPCs
var _separation_radius: float = 1.5
# Lookahead distance for obstacle avoidance
var _obstacle_lookahead: float = 3.0
# Whether to use priority (first non-zero) or blend (weighted sum)
var _use_priority: bool = false


func _init() -> void:
	_accel_pool = TargetAcceleration.new()
	_temp_accel = TargetAcceleration.new()


# Configures the steering with an agent, neighbors, and navigation grid.
# Returns self for chaining.
func configure(
	agent: SteeringAgent,
	neighbors: Array[SteeringAgent],
	navigation: NPCNavigation = null,
	cell_size: float = 1.0,
	options: Dictionary = {}
) -> NpcSteering:
	var proximity = RadiusProximity.new(agent, neighbors, _separation_radius)
	
	_separation = Separation.new(agent, proximity)
	_separation.decay_coefficient = 1.0
	
	if navigation != null:
		_navigation = navigation
		_nav_cell_size = cell_size
		var obs_proximity = ObstacleProximity.new(agent, navigation, _nav_cell_size, _obstacle_lookahead)
		_obstacle_avoidance = ObstacleAvoidance.new(agent, obs_proximity)
	else:
		_obstacle_avoidance = null
	
	var dummy_target = SteeringAgentLocation.new()
	_face = Face.new(agent, dummy_target, true)
	_face.alignment_tolerance = 0.05
	_face.deceleration_radius = 0.5
	_face.time_to_reach = 0.1
	
	_blend = Blend.new(agent)
	_priority = Priority.new(agent, 0.001)
	
	_separation_weight = float(options.get("separation_weight", _separation_weight))
	_obstacle_weight = float(options.get("obstacle_weight", _obstacle_weight))
	_face_weight = float(options.get("face_weight", _face_weight))
	_separation_radius = float(options.get("separation_radius", _separation_radius))
	_obstacle_lookahead = float(options.get("obstacle_lookahead", _obstacle_lookahead))
	_use_priority = bool(options.get("use_priority", _use_priority))
	
	if _use_priority:
		_priority.add(_separation)
		if _obstacle_avoidance:
			_priority.add(_obstacle_avoidance)
		_priority.add(_face)
	else:
		_blend.add(_separation, _separation_weight)
		if _obstacle_avoidance:
			_blend.add(_obstacle_avoidance, _obstacle_weight)
		_blend.add(_face, _face_weight)
	
	return self


# Computes the combined steering acceleration for the given goal position.
# Reuses pooled acceleration objects to avoid frame allocations.
# @param goal Target position to steer toward
# @param delta Time step (optional, for time-based calculations)
# @return TargetAcceleration with linear and angular components
func compute(goal: Vector3, delta: float = 0.016) -> TargetAcceleration:
	if _use_priority:
		_priority.calculate_steering(_accel_pool)
	else:
		_blend.calculate_steering(_accel_pool)
	
	if _face != null:
		_face.target.position = goal
		_face.target.orientation = SteeringUtils.vector3_to_angle(goal - _face.agent.position)
	
	return _accel_pool


# Computes steering with explicit neighbor array (for dynamic neighbor updates).
func compute_with_neighbors(goal: Vector3, neighbors: Array[SteeringAgent], delta: float = 0.016) -> TargetAcceleration:
	if _separation != null and _separation.proximity != null:
		_separation.proximity.agents = neighbors
	return compute(goal, delta)


# Updates the face target orientation for turn smoothing.
func update_face_target(goal: Vector3) -> void:
	if _face != null:
		_face.target.position = goal
		var to_goal = goal - _face.agent.position
		if to_goal.length_squared() > 0.0001:
			_face.target.orientation = SteeringUtils.vector3_to_angle(to_goal)


# Checks if the agent is stuck against a wall/obstacle using navigation grid.
func is_stuck(position: Vector3, threshold: float = 0.2) -> bool:
	if _navigation == null:
		return false
	var cell = _navigation.world_to_cell_2d(Vector2(position.x, position.z), _nav_cell_size)
	return _navigation.is_blocked(cell)


# Gets the nearest walkable cell from a position.
func find_nearest_walkable(position: Vector3) -> Vector3:
	if _navigation == null:
		return position
	var cell = _navigation.world_to_cell_2d(Vector2(position.x, position.z), _nav_cell_size)
	if _navigation.is_inside(cell) and not _navigation.is_blocked(cell):
		return position
	var width = int(_navigation.get("width", 0))
	var height = int(_navigation.get("height", 0))
	var best_cell = cell
	var best_dist = INF
	for y in range(max(0, cell.y - 5), min(height, cell.y + 6)):
		for x in range(max(0, cell.x - 5), min(width, cell.x + 6)):
			var c = Vector2i(x, y)
			if _navigation.is_inside(c) and not _navigation.is_blocked(c):
				var dist = c.distance_squared_to(cell)
				if dist < best_dist:
					best_dist = dist
					best_cell = c
	return _navigation.cell_to_world(best_cell, _nav_cell_size, position.y)


# Clears internal state for reuse with different agent/neighbors.
func reset() -> void:
	_separation = null
	_obstacle_avoidance = null
	_face = null
	_blend = null
	_priority = null
	_navigation = null
	_accel_pool.set_zero()
	_temp_accel.set_zero()


# Proximity that finds obstacles from the navigation grid.
class ObstacleProximity extends Proximity:
	var _navigation: NPCNavigation
	var _cell_size: float
	var _lookahead: float
	var _sample_count: int = 8
	var _temp_cells: Array = []
	
	func _init(agent: SteeringAgent, navigation: NPCNavigation, cell_size: float, lookahead: float) -> void:
		super._init(agent, [])
		_navigation = navigation
		_cell_size = cell_size
		_lookahead = lookahead
		_temp_cells.resize(_sample_count)
	
	func _find_neighbors(callback: Callable) -> int:
		if _navigation == null:
			return 0
		
		var count = 0
		var agent_pos = agent.position
		var forward = -Vector3.FORWARD
		if agent.linear_velocity.length_squared() > 0.001:
			forward = -agent.linear_velocity.normalized()
		forward.y = 0.0
		if forward.length_squared() < 0.001:
			forward = -Vector3.FORWARD
		
		var right = Vector3(forward.z, 0.0, -forward.x)
		
		for i in range(_sample_count):
			var t = float(i) / float(max(1, _sample_count - 1))
			var angle = lerpf(-PI * 0.5, PI * 0.5, t)
			var dir = (forward * cos(angle) + right * sin(angle)).normalized()
			var sample_pos = agent_pos + dir * _lookahead
			var cell = _navigation.world_to_cell_2d(Vector2(sample_pos.x, sample_pos.z), _cell_size)
			
			if _navigation.is_inside(cell) and _navigation.is_blocked(cell):
				var obstacle = _make_obstacle_agent(cell, sample_pos)
				if callback.call(obstacle):
					count += 1
		
		return count
	
	func _make_obstacle_agent(cell: Vector2i, sample_pos: Vector3) -> SteeringAgent:
		var obstacle = SteeringAgent.new()
		obstacle.position = _navigation.cell_to_world(cell, _cell_size, sample_pos.y)
		obstacle.bounding_radius = _cell_size * 0.7
		obstacle.linear_velocity = Vector3.ZERO
		obstacle.linear_speed_max = 0.0
		obstacle.linear_acceleration_max = 0.0
		return obstacle


# Obstacle avoidance behavior that treats grid obstacles as neighbors.
class ObstacleAvoidance extends GroupBehavior:
	var _best_obstacle: SteeringAgent = null
	var _shortest_time: float
	var _best_distance: float
	var _best_relative_pos: Vector3
	var _best_relative_vel: Vector3
	
	func _init(agent: SteeringAgent, proximity: Proximity) -> void:
		super._init(agent, proximity)
	
	func _calculate_steering(acceleration: TargetAcceleration) -> void:
		_shortest_time = INF
		_best_obstacle = null
		_best_distance = 0.0
		
		var neighbor_count = proximity._find_neighbors(_callback)
		
		if neighbor_count == 0 or not _best_obstacle:
			acceleration.set_zero()
		else:
			var to_obstacle = _best_obstacle.position - agent.position
			var distance = to_obstacle.length()
			
			if distance <= agent.bounding_radius + _best_obstacle.bounding_radius:
				acceleration.linear = -to_obstacle.normalized() * agent.linear_acceleration_max
			else:
				var time_to_collision = _shortest_time
				if time_to_collision > 0 and time_to_collision < INF:
					acceleration.linear = (_best_relative_pos + _best_relative_vel * time_to_collision).normalized() * -agent.linear_acceleration_max
				else:
					acceleration.linear = -to_obstacle.normalized() * agent.linear_acceleration_max
			
			acceleration.linear = SteeringUtils.clampedv3(acceleration.linear, agent.linear_acceleration_max)
			acceleration.angular = 0.0
	
	func _report_neighbor(neighbor: SteeringAgent) -> bool:
		var relative_position = neighbor.position - agent.position
		var relative_velocity = neighbor.linear_velocity - agent.linear_velocity
		var relative_speed_sq = relative_velocity.length_squared()
		
		if relative_speed_sq < 0.001:
			var distance = relative_position.length()
			if distance < agent.bounding_radius + neighbor.bounding_radius:
				_shortest_time = 0.0
				_best_obstacle = neighbor
				_best_distance = distance
				_best_relative_pos = relative_position
				_best_relative_vel = relative_velocity
				return true
			return false
		
		var time_to_collision = -relative_position.dot(relative_velocity) / relative_speed_sq
		
		if time_to_collision <= 0.0 or time_to_collision >= _shortest_time:
			return false
		
		var distance = relative_position.length()
		var min_separation = distance - sqrt(relative_speed_sq) * time_to_collision
		
		if min_separation > agent.bounding_radius + neighbor.bounding_radius:
			return false
		
		_shortest_time = time_to_collision
		_best_obstacle = neighbor
		_best_distance = distance
		_best_relative_pos = relative_position
		_best_relative_vel = relative_velocity
		return true