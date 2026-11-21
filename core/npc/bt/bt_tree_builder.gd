# Copyright (c) 2016 Jeffery Olson
# Copyright (c) 2016 Brandon Lamb
# Copyright (c) 2017 Sebastian Ebert
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
# Adapted for Godot 4.7 and UNTITLED project: removed editor dependencies,
# converted to pure GDScript RefCounted, simplified API.
# Updated to use specific action/condition classes for daily life routines.

class_name BTTreeBuilder
extends RefCounted

# Preload action classes
const BTActionPatrol = preload("res://core/npc/bt/actions/bt_action_patrol.gd")
const BTActionPause = preload("res://core/npc/bt/actions/bt_action_pause.gd")
const BTActionConverse = preload("res://core/npc/bt/actions/bt_action_converse.gd")
const BTActionWork = preload("res://core/npc/bt/actions/bt_action_work.gd")
const BTActionEat = preload("res://core/npc/bt/actions/bt_action_eat.gd")
const BTActionRest = preload("res://core/npc/bt/actions/bt_action_rest.gd")
const BTActionWander = preload("res://core/npc/bt/actions/bt_action_wander.gd")
const BTActionHide = preload("res://core/npc/bt/actions/bt_action_hide.gd")
const BTActionChase = preload("res://core/npc/bt/actions/bt_action_chase.gd")
const BTActionIdle = preload("res://core/npc/bt/actions/bt_action_idle.gd")
const BTActionAttack = preload("res://core/npc/bt/actions/bt_action_attack.gd")
const BTActionFlee = preload("res://core/npc/bt/actions/bt_action_flee.gd")
const BTActionAlert = preload("res://core/npc/bt/actions/bt_action_alert.gd")
const BTActionHelp = preload("res://core/npc/bt/actions/bt_action_help.gd")
const BTActionTakeCover = preload("res://core/npc/bt/actions/bt_action_take_cover.gd")
const BTActionSuppress = preload("res://core/npc/bt/actions/bt_action_suppress.gd")
const BTActionGuard = preload("res://core/npc/bt/actions/bt_action_guard.gd")
const BTActionLoot = preload("res://core/npc/bt/actions/bt_action_loot.gd")

# Preload condition classes
const BTConditionRoutineActive = preload("res://core/npc/bt/conditions/bt_condition_routine_active.gd")
const BTConditionWorkHours = preload("res://core/npc/bt/conditions/bt_condition_work_hours.gd")
const BTConditionCanConverse = preload("res://core/npc/bt/conditions/bt_condition_can_converse.gd")
const BTConditionCanExplore = preload("res://core/npc/bt/conditions/bt_condition_can_explore.gd")
const BTConditionShouldFlee = preload("res://core/npc/bt/conditions/bt_condition_should_flee.gd")
const BTConditionNeedsHelp = preload("res://core/npc/bt/conditions/bt_condition_needs_help.gd")
const BTConditionSuspiciousActivity = preload("res://core/npc/bt/conditions/bt_condition_suspicious_activity.gd")
const BTConditionHasEnemy = preload("res://core/npc/bt/conditions/bt_condition_has_enemy.gd")
const BTConditionNeedsCover = preload("res://core/npc/bt/conditions/bt_condition_needs_cover.gd")
const BTConditionCanSuppress = preload("res://core/npc/bt/conditions/bt_condition_can_suppress.gd")
const BTConditionGuardPostActive = preload("res://core/npc/bt/conditions/bt_condition_guard_post_active.gd")
const BTConditionHasAdvantage = preload("res://core/npc/bt/conditions/bt_condition_has_advantage.gd")
const BTConditionOutmatched = preload("res://core/npc/bt/conditions/bt_condition_outmatched.gd")
const BTConditionLootAvailable = preload("res://core/npc/bt/conditions/bt_condition_loot_available.gd")
const BTConditionCanWander = preload("res://core/npc/bt/conditions/bt_condition_can_wander.gd")
const BTConditionCanHide = preload("res://core/npc/bt/conditions/bt_condition_can_hide.gd")
const BTConditionUnderAttack = preload("res://core/npc/bt/conditions/bt_condition_under_attack.gd")
const BTConditionNeedsFood = preload("res://core/npc/bt/conditions/bt_condition_needs_food.gd")
const BTConditionNeedsRest = preload("res://core/npc/bt/conditions/bt_condition_needs_rest.gd")

static func build_civil_pacific() -> BehaviorTree:
	var tree: BehaviorTree = BehaviorTree.new()
	
	# Root selector
	var root: BTSelector = BTSelector.new()
	tree.add_child(root)
	
	# Priority 1: Flee if under attack
	var flee_seq: BTSequence = BTSequence.new()
	root.add_child(flee_seq)
	
	var under_attack_cond: BTConditionUnderAttack = BTConditionUnderAttack.new()
	flee_seq.add_child(under_attack_cond)
	
	var flee_action: BTActionFlee = BTActionFlee.new()
	flee_action.action_name = "flee"
	flee_seq.add_child(flee_action)
	
	# Priority 2: Patrol if routine active
	var patrol_seq: BTSequence = BTSequence.new()
	root.add_child(patrol_seq)
	
	var needs_patrol_cond: BTConditionRoutineActive = BTConditionRoutineActive.new()
	patrol_seq.add_child(needs_patrol_cond)
	
	var patrol_action: BTActionPatrol = BTActionPatrol.new()
	patrol_action.action_name = "patrol"
	patrol_seq.add_child(patrol_action)
	
	# Priority 3: Explore if curious
	var explore_seq: BTSequence = BTSequence.new()
	root.add_child(explore_seq)
	
	var can_explore_cond: BTConditionCanExplore = BTConditionCanExplore.new()
	explore_seq.add_child(can_explore_cond)
	
	var explore_action: BTActionWander = BTActionWander.new()
	explore_action.action_name = "wander"
	explore_seq.add_child(explore_action)
	
	# Priority 4: Converse if social
	var converse_seq: BTSequence = BTSequence.new()
	root.add_child(converse_seq)
	
	var can_converse_cond: BTConditionCanConverse = BTConditionCanConverse.new()
	converse_seq.add_child(can_converse_cond)
	
	var converse_action: BTActionConverse = BTActionConverse.new()
	converse_action.action_name = "converse"
	converse_seq.add_child(converse_action)
	
	# Priority 5: Work if office hours
	var work_seq: BTSequence = BTSequence.new()
	root.add_child(work_seq)
	
	var work_cond: BTConditionWorkHours = BTConditionWorkHours.new()
	work_seq.add_child(work_cond)
	
	var work_action: BTActionWork = BTActionWork.new()
	work_action.action_name = "work"
	work_seq.add_child(work_action)
	
	# Priority 6: Eat if hungry
	var eat_seq: BTSequence = BTSequence.new()
	root.add_child(eat_seq)
	
	var needs_food_cond: BTConditionNeedsFood = BTConditionNeedsFood.new()
	eat_seq.add_child(needs_food_cond)
	
	var eat_action: BTActionEat = BTActionEat.new()
	eat_action.action_name = "eat"
	eat_seq.add_child(eat_action)
	
	# Priority 7: Rest if tired
	var rest_seq: BTSequence = BTSequence.new()
	root.add_child(rest_seq)
	
	var needs_rest_cond: BTConditionNeedsRest = BTConditionNeedsRest.new()
	rest_seq.add_child(needs_rest_cond)
	
	var rest_action: BTActionRest = BTActionRest.new()
	rest_action.action_name = "rest"
	rest_seq.add_child(rest_action)
	
	# Default: Idle
	var idle_succeeder: BTAlwaysReturn = BTAlwaysReturn.new()
	idle_succeeder.return_result = BTAlwaysReturn.ReturnResult.RETURN_SUCCESS
	root.add_child(idle_succeeder)
	
	var idle_action: BTActionIdle = BTActionIdle.new()
	idle_action.action_name = "idle"
	idle_succeeder.add_child(idle_action)
	
	return tree

static func build_civil_hostile() -> BehaviorTree:
	var tree: BehaviorTree = BehaviorTree.new()
	
	var root: BTSelector = BTSelector.new()
	tree.add_child(root)
	
	# Priority 1: Flee if low health or high fear
	var flee_seq: BTSequence = BTSequence.new()
	root.add_child(flee_seq)
	
	var should_flee_cond: BTConditionShouldFlee = BTConditionShouldFlee.new()
	flee_seq.add_child(should_flee_cond)
	
	var flee_action: BTActionFlee = BTActionFlee.new()
	flee_action.action_name = "flee"
	flee_seq.add_child(flee_action)
	
	# Priority 2: Help if injured
	var help_seq: BTSequence = BTSequence.new()
	root.add_child(help_seq)
	
	var needs_help_cond: BTConditionNeedsHelp = BTConditionNeedsHelp.new()
	help_seq.add_child(needs_help_cond)
	
	var help_action: BTActionHelp = BTActionHelp.new()
	help_action.action_name = "help"
	help_seq.add_child(help_action)
	
	# Priority 3: Hide if can
	var hide_seq: BTSequence = BTSequence.new()
	root.add_child(hide_seq)
	
	var can_hide_cond: BTConditionCanHide = BTConditionCanHide.new()
	hide_seq.add_child(can_hide_cond)
	
	var hide_action: BTActionHide = BTActionHide.new()
	hide_action.action_name = "hide"
	hide_seq.add_child(hide_action)
	
	# Default: Flee
	var flee_succeeder: BTAlwaysReturn = BTAlwaysReturn.new()
	flee_succeeder.return_result = BTAlwaysReturn.ReturnResult.RETURN_SUCCESS
	root.add_child(flee_succeeder)
	
	var default_flee: BTActionFlee = BTActionFlee.new()
	default_flee.action_name = "flee"
	flee_succeeder.add_child(default_flee)
	
	return tree

static func build_police_pacific() -> BehaviorTree:
	var tree: BehaviorTree = BehaviorTree.new()
	
	var root: BTSelector = BTSelector.new()
	tree.add_child(root)
	
	# Priority 1: Alert if suspicious
	var alert_seq: BTSequence = BTSequence.new()
	root.add_child(alert_seq)
	
	var suspicious_cond: BTConditionSuspiciousActivity = BTConditionSuspiciousActivity.new()
	alert_seq.add_child(suspicious_cond)
	
	var alert_action: BTActionAlert = BTActionAlert.new()
	alert_action.action_name = "alert"
	alert_seq.add_child(alert_action)
	
	# Priority 2: Patrol
	var patrol_seq: BTSequence = BTSequence.new()
	root.add_child(patrol_seq)
	
	var routine_cond: BTConditionRoutineActive = BTConditionRoutineActive.new()
	patrol_seq.add_child(routine_cond)
	
	var patrol_action: BTActionPatrol = BTActionPatrol.new()
	patrol_action.action_name = "patrol"
	patrol_seq.add_child(patrol_action)
	
	# Priority 3: Converse if social
	var converse_seq: BTSequence = BTSequence.new()
	root.add_child(converse_seq)
	
	var can_converse_cond: BTConditionCanConverse = BTConditionCanConverse.new()
	converse_seq.add_child(can_converse_cond)
	
	var converse_action: BTActionConverse = BTActionConverse.new()
	converse_action.action_name = "converse"
	converse_seq.add_child(converse_action)
	
	# Default: Idle
	var idle_succeeder: BTAlwaysReturn = BTAlwaysReturn.new()
	idle_succeeder.return_result = BTAlwaysReturn.ReturnResult.RETURN_SUCCESS
	root.add_child(idle_succeeder)
	
	var idle_action: BTActionIdle = BTActionIdle.new()
	idle_action.action_name = "idle"
	idle_succeeder.add_child(idle_action)
	
	return tree

static func build_police_hostile() -> BehaviorTree:
	var tree: BehaviorTree = BehaviorTree.new()
	
	var root: BTSelector = BTSelector.new()
	tree.add_child(root)
	
	# Priority 1: Attack if enemy visible
	var attack_seq: BTSequence = BTSequence.new()
	root.add_child(attack_seq)
	
	var has_target_cond: BTConditionHasEnemy = BTConditionHasEnemy.new()
	attack_seq.add_child(has_target_cond)
	
	var attack_action: BTActionAttack = BTActionAttack.new()
	attack_action.action_name = "attack"
	attack_seq.add_child(attack_action)
	
	# Priority 2: Seek cover
	var cover_seq: BTSequence = BTSequence.new()
	root.add_child(cover_seq)
	
	var needs_cover_cond: BTConditionNeedsCover = BTConditionNeedsCover.new()
	cover_seq.add_child(needs_cover_cond)
	
	var cover_action: BTActionTakeCover = BTActionTakeCover.new()
	cover_action.action_name = "take_cover"
	cover_seq.add_child(cover_action)
	
	# Priority 3: Help injured allies
	var help_seq: BTSequence = BTSequence.new()
	root.add_child(help_seq)
	
	var needs_help_cond: BTConditionNeedsHelp = BTConditionNeedsHelp.new()
	help_seq.add_child(needs_help_cond)
	
	var help_action: BTActionHelp = BTActionHelp.new()
	help_action.action_name = "help"
	help_seq.add_child(help_action)
	
	# Default: Attack
	var attack_succeeder: BTAlwaysReturn = BTAlwaysReturn.new()
	attack_succeeder.return_result = BTAlwaysReturn.ReturnResult.RETURN_SUCCESS
	root.add_child(attack_succeeder)
	
	var default_attack: BTActionAttack = BTActionAttack.new()
	default_attack.action_name = "attack"
	attack_succeeder.add_child(default_attack)
	
	return tree

static func build_soldier_pacific() -> BehaviorTree:
	var tree: BehaviorTree = BehaviorTree.new()
	
	var root: BTSelector = BTSelector.new()
	tree.add_child(root)
	
	# Priority 1: Patrol
	var patrol_seq: BTSequence = BTSequence.new()
	root.add_child(patrol_seq)
	
	var routine_cond: BTConditionRoutineActive = BTConditionRoutineActive.new()
	patrol_seq.add_child(routine_cond)
	
	var patrol_action: BTActionPatrol = BTActionPatrol.new()
	patrol_action.action_name = "patrol"
	patrol_seq.add_child(patrol_action)
	
	# Priority 2: Guard
	var guard_seq: BTSequence = BTSequence.new()
	root.add_child(guard_seq)
	
	var guard_cond: BTConditionGuardPostActive = BTConditionGuardPostActive.new()
	guard_seq.add_child(guard_cond)
	
	var guard_action: BTActionGuard = BTActionGuard.new()
	guard_action.action_name = "guard"
	guard_seq.add_child(guard_action)
	
	# Priority 3: Converse
	var converse_seq: BTSequence = BTSequence.new()
	root.add_child(converse_seq)
	
	var can_converse_cond: BTConditionCanConverse = BTConditionCanConverse.new()
	converse_seq.add_child(can_converse_cond)
	
	var converse_action: BTActionConverse = BTActionConverse.new()
	converse_action.action_name = "converse"
	converse_seq.add_child(converse_action)
	
	# Default: Idle
	var idle_succeeder: BTAlwaysReturn = BTAlwaysReturn.new()
	idle_succeeder.return_result = BTAlwaysReturn.ReturnResult.RETURN_SUCCESS
	root.add_child(idle_succeeder)
	
	var idle_action: BTActionIdle = BTActionIdle.new()
	idle_action.action_name = "idle"
	idle_succeeder.add_child(idle_action)
	
	return tree

static func build_soldier_hostile() -> BehaviorTree:
	var tree: BehaviorTree = BehaviorTree.new()
	
	var root: BTSelector = BTSelector.new()
	tree.add_child(root)
	
	# Priority 1: Attack
	var attack_seq: BTSequence = BTSequence.new()
	root.add_child(attack_seq)
	
	var has_target_cond: BTConditionHasEnemy = BTConditionHasEnemy.new()
	attack_seq.add_child(has_target_cond)
	
	var attack_action: BTActionAttack = BTActionAttack.new()
	attack_action.action_name = "attack"
	attack_seq.add_child(attack_action)
	
	# Priority 2: Suppressive fire
	var suppress_seq: BTSequence = BTSequence.new()
	root.add_child(suppress_seq)
	
	var suppress_cond: BTConditionCanSuppress = BTConditionCanSuppress.new()
	suppress_seq.add_child(suppress_cond)
	
	var suppress_action: BTActionSuppress = BTActionSuppress.new()
	suppress_action.action_name = "suppress"
	suppress_seq.add_child(suppress_action)
	
	# Priority 3: Take cover
	var cover_seq: BTSequence = BTSequence.new()
	root.add_child(cover_seq)
	
	var cover_cond: BTConditionNeedsCover = BTConditionNeedsCover.new()
	cover_seq.add_child(cover_cond)
	
	var cover_action: BTActionTakeCover = BTActionTakeCover.new()
	cover_action.action_name = "take_cover"
	cover_seq.add_child(cover_action)
	
	# Default: Attack
	var attack_succeeder: BTAlwaysReturn = BTAlwaysReturn.new()
	attack_succeeder.return_result = BTAlwaysReturn.ReturnResult.RETURN_SUCCESS
	root.add_child(attack_succeeder)
	
	var default_attack: BTActionAttack = BTActionAttack.new()
	default_attack.action_name = "attack"
	attack_succeeder.add_child(default_attack)
	
	return tree

static func build_criminal_pacific() -> BehaviorTree:
	var tree: BehaviorTree = BehaviorTree.new()
	
	var root: BTSelector = BTSelector.new()
	tree.add_child(root)
	
	# Priority 1: Loot
	var loot_seq: BTSequence = BTSequence.new()
	root.add_child(loot_seq)
	
	var loot_cond: BTConditionLootAvailable = BTConditionLootAvailable.new()
	loot_seq.add_child(loot_cond)
	
	var loot_action: BTActionLoot = BTActionLoot.new()
	loot_action.action_name = "loot"
	loot_seq.add_child(loot_action)
	
	# Priority 2: Patrol
	var patrol_seq: BTSequence = BTSequence.new()
	root.add_child(patrol_seq)
	
	var routine_cond: BTConditionRoutineActive = BTConditionRoutineActive.new()
	patrol_seq.add_child(routine_cond)
	
	var patrol_action: BTActionPatrol = BTActionPatrol.new()
	patrol_action.action_name = "patrol"
	patrol_seq.add_child(patrol_action)
	
	# Priority 3: Converse
	var converse_seq: BTSequence = BTSequence.new()
	root.add_child(converse_seq)
	
	var can_converse_cond: BTConditionCanConverse = BTConditionCanConverse.new()
	converse_seq.add_child(can_converse_cond)
	
	var converse_action: BTActionConverse = BTActionConverse.new()
	converse_action.action_name = "converse"
	converse_seq.add_child(converse_action)
	
	# Default: Idle
	var idle_succeeder: BTAlwaysReturn = BTAlwaysReturn.new()
	idle_succeeder.return_result = BTAlwaysReturn.ReturnResult.RETURN_SUCCESS
	root.add_child(idle_succeeder)
	
	var idle_action: BTActionIdle = BTActionIdle.new()
	idle_action.action_name = "idle"
	idle_succeeder.add_child(idle_action)
	
	return tree

static func build_criminal_hostile() -> BehaviorTree:
	var tree: BehaviorTree = BehaviorTree.new()
	
	var root: BTSelector = BTSelector.new()
	tree.add_child(root)
	
	# Priority 1: Attack if enemy visible
	var attack_seq: BTSequence = BTSequence.new()
	root.add_child(attack_seq)
	
	var has_target_cond: BTConditionHasEnemy = BTConditionHasEnemy.new()
	attack_seq.add_child(has_target_cond)
	
	var attack_action: BTActionAttack = BTActionAttack.new()
	attack_action.action_name = "attack"
	attack_seq.add_child(attack_action)
	
	# Priority 2: Flee if outmatched
	var flee_seq: BTSequence = BTSequence.new()
	root.add_child(flee_seq)
	
	var outmatched_cond: BTConditionOutmatched = BTConditionOutmatched.new()
	flee_seq.add_child(outmatched_cond)
	
	var flee_action: BTActionFlee = BTActionFlee.new()
	flee_action.action_name = "flee"
	flee_seq.add_child(flee_action)
	
	# Priority 3: Take cover
	var cover_seq: BTSequence = BTSequence.new()
	root.add_child(cover_seq)
	
	var cover_cond: BTConditionNeedsCover = BTConditionNeedsCover.new()
	cover_seq.add_child(cover_cond)
	
	var cover_action: BTActionTakeCover = BTActionTakeCover.new()
	cover_action.action_name = "take_cover"
	cover_seq.add_child(cover_action)
	
	# Priority 4: Loot
	var loot_seq: BTSequence = BTSequence.new()
	root.add_child(loot_seq)
	
	var loot_cond: BTConditionLootAvailable = BTConditionLootAvailable.new()
	loot_seq.add_child(loot_cond)
	
	var loot_action: BTActionLoot = BTActionLoot.new()
	loot_action.action_name = "loot"
	loot_seq.add_child(loot_action)
	
	# Default: Attack
	var attack_succeeder: BTAlwaysReturn = BTAlwaysReturn.new()
	attack_succeeder.return_result = BTAlwaysReturn.ReturnResult.RETURN_SUCCESS
	root.add_child(attack_succeeder)
	
	var default_attack: BTActionAttack = BTActionAttack.new()
	default_attack.action_name = "attack"
	attack_succeeder.add_child(default_attack)
	
	return tree

static func build_office_pacific() -> BehaviorTree:
	var tree: BehaviorTree = BehaviorTree.new()
	
	var root: BTSelector = BTSelector.new()
	tree.add_child(root)
	
	# Priority 1: Work
	var work_seq: BTSequence = BTSequence.new()
	root.add_child(work_seq)
	
	var work_cond: BTConditionWorkHours = BTConditionWorkHours.new()
	work_seq.add_child(work_cond)
	
	var work_action: BTActionWork = BTActionWork.new()
	work_action.action_name = "work"
	work_seq.add_child(work_action)
	
	# Priority 2: Converse
	var converse_seq: BTSequence = BTSequence.new()
	root.add_child(converse_seq)
	
	var converse_cond: BTConditionCanConverse = BTConditionCanConverse.new()
	converse_seq.add_child(converse_cond)
	
	var converse_action: BTActionConverse = BTActionConverse.new()
	converse_action.action_name = "converse"
	converse_seq.add_child(converse_action)
	
	# Priority 3: Patrol
	var patrol_seq: BTSequence = BTSequence.new()
	root.add_child(patrol_seq)
	
	var routine_cond: BTConditionRoutineActive = BTConditionRoutineActive.new()
	patrol_seq.add_child(routine_cond)
	
	var patrol_action: BTActionPatrol = BTActionPatrol.new()
	patrol_action.action_name = "patrol"
	patrol_seq.add_child(patrol_action)
	
	# Priority 4: Eat
	var eat_seq: BTSequence = BTSequence.new()
	root.add_child(eat_seq)
	
	var needs_food_cond: BTConditionNeedsFood = BTConditionNeedsFood.new()
	eat_seq.add_child(needs_food_cond)
	
	var eat_action: BTActionEat = BTActionEat.new()
	eat_action.action_name = "eat"
	eat_seq.add_child(eat_action)
	
	# Priority 5: Rest
	var rest_seq: BTSequence = BTSequence.new()
	root.add_child(rest_seq)
	
	var needs_rest_cond: BTConditionNeedsRest = BTConditionNeedsRest.new()
	rest_seq.add_child(needs_rest_cond)
	
	var rest_action: BTActionRest = BTActionRest.new()
	rest_action.action_name = "rest"
	rest_seq.add_child(rest_action)
	
	# Default: Idle
	var idle_succeeder: BTAlwaysReturn = BTAlwaysReturn.new()
	idle_succeeder.return_result = BTAlwaysReturn.ReturnResult.RETURN_SUCCESS
	root.add_child(idle_succeeder)
	
	var idle_action: BTActionIdle = BTActionIdle.new()
	idle_action.action_name = "idle"
	idle_succeeder.add_child(idle_action)
	
	return tree

static func build_office_hostile() -> BehaviorTree:
	var tree: BehaviorTree = BehaviorTree.new()
	
	var root: BTSelector = BTSelector.new()
	tree.add_child(root)
	
	# Priority 1: Flee
	var flee_seq: BTSequence = BTSequence.new()
	root.add_child(flee_seq)
	
	var should_flee_cond: BTConditionShouldFlee = BTConditionShouldFlee.new()
	flee_seq.add_child(should_flee_cond)
	
	var flee_action: BTActionFlee = BTActionFlee.new()
	flee_action.action_name = "flee"
	flee_seq.add_child(flee_action)
	
	# Priority 2: Hide
	var hide_seq: BTSequence = BTSequence.new()
	root.add_child(hide_seq)
	
	var hide_cond: BTConditionCanHide = BTConditionCanHide.new()
	hide_seq.add_child(hide_cond)
	
	var hide_action: BTActionHide = BTActionHide.new()
	hide_action.action_name = "hide"
	hide_seq.add_child(hide_action)
	
	# Default: Flee
	var flee_succeeder: BTAlwaysReturn = BTAlwaysReturn.new()
	flee_succeeder.return_result = BTAlwaysReturn.ReturnResult.RETURN_SUCCESS
	root.add_child(flee_succeeder)
	
	var default_flee: BTActionFlee = BTActionFlee.new()
	default_flee.action_name = "flee"
	flee_succeeder.add_child(default_flee)
	
	return tree

static func build_zombie_pacific() -> BehaviorTree:
	var tree: BehaviorTree = BehaviorTree.new()
	
	var root: BTSelector = BTSelector.new()
	tree.add_child(root)
	
	# Priority 1: Wander
	var wander_seq: BTSequence = BTSequence.new()
	root.add_child(wander_seq)
	
	var wander_cond: BTConditionCanWander = BTConditionCanWander.new()
	wander_seq.add_child(wander_cond)
	
	var wander_action: BTActionWander = BTActionWander.new()
	wander_action.action_name = "wander"
	wander_seq.add_child(wander_action)
	
	# Default: Idle
	var idle_succeeder: BTAlwaysReturn = BTAlwaysReturn.new()
	idle_succeeder.return_result = BTAlwaysReturn.ReturnResult.RETURN_SUCCESS
	root.add_child(idle_succeeder)
	
	var idle_action: BTActionIdle = BTActionIdle.new()
	idle_action.action_name = "idle"
	idle_succeeder.add_child(idle_action)
	
	return tree

static func build_zombie_hostile() -> BehaviorTree:
	var tree: BehaviorTree = BehaviorTree.new()
	
	var root: BTSelector = BTSelector.new()
	tree.add_child(root)
	
	# Priority 1: Chase and attack
	var chase_seq: BTSequence = BTSequence.new()
	root.add_child(chase_seq)
	
	var has_target_cond: BTConditionHasEnemy = BTConditionHasEnemy.new()
	chase_seq.add_child(has_target_cond)
	
	var chase_action: BTActionChase = BTActionChase.new()
	chase_action.action_name = "chase"
	chase_seq.add_child(chase_action)
	
	var attack_action: BTActionAttack = BTActionAttack.new()
	attack_action.action_name = "attack"
	chase_seq.add_child(attack_action)
	
	# Priority 2: Wander
	var wander_seq: BTSequence = BTSequence.new()
	root.add_child(wander_seq)
	
	var wander_cond: BTConditionCanWander = BTConditionCanWander.new()
	wander_seq.add_child(wander_cond)
	
	var wander_action: BTActionWander = BTActionWander.new()
	wander_action.action_name = "wander"
	wander_seq.add_child(wander_action)
	
	# Default: Idle
	var idle_succeeder: BTAlwaysReturn = BTAlwaysReturn.new()
	idle_succeeder.return_result = BTAlwaysReturn.ReturnResult.RETURN_SUCCESS
	root.add_child(idle_succeeder)
	
	var idle_action: BTActionIdle = BTActionIdle.new()
	idle_action.action_name = "idle"
	idle_succeeder.add_child(idle_action)
	
	return tree

static func build_tree_for_role(role: String, mode: String) -> BehaviorTree:
	match role:
		"civil":
			return build_civil_pacific() if mode == "pacifico" else build_civil_hostile()
		"police":
			return build_police_pacific() if mode == "pacifico" else build_police_hostile()
		"soldier":
			return build_soldier_pacific() if mode == "pacifico" else build_soldier_hostile()
		"criminal":
			return build_criminal_pacific() if mode == "pacifico" else build_criminal_hostile()
		"office":
			return build_office_pacific() if mode == "pacifico" else build_office_hostile()
		"zombie":
			return build_zombie_pacific() if mode == "pacifico" else build_zombie_hostile()
		_:
			return build_civil_pacific()