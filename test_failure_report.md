# Test Failure Report - AI2 Integration Tests
**Date:** 2026-11-21
**Project:** UNTITLED (Godot 4.7, Termux aarch64)
**Commit Reference:** 52285c3

---

## Executive Summary

Executed 4 test suites related to NPC AI, steering, and behavior tree integration. **3 of 4 test suites have failures** totaling 7 failed assertions across 87 total assertions.

| Test Suite | Total Assertions | Passed | Failed | Pass Rate |
|------------|-----------------|--------|--------|-----------|
| test_ai2_integration.gd | 13 | 11 | 2 | 84.6% |
| test_b1_npc_movement.gd | 16 | 16 | 0 | 100% |
| test_game_ai.gd | 26 | 22 | 4 | 84.6% |
| test_z1_nozombies.gd | 32 | 31 | 1 | 96.9% |
| **TOTAL** | **87** | **80** | **7** | **92.0%** |

---

## Detailed Failure Analysis

### 1. test_ai2_integration.gd (2 failures)

**File:** `tests/test_ai2_integration.gd` (claimed by helper_1795222981)

#### Failure 1: "steering + BT integrados avanzan"
- **Expected:** 8 of 9 NPCs advance >1m in 10s simulated time (300 physics frames)
- **Actual:** 6 of 10 NPCs advanced >1m
- **Observation:** All NPCs report `action_id=idle` despite having valid `move_target` set in blackboard

#### Failure 2: "hostile mode ataca cuando ve objetivo"
- **Expected:** At least one hostile NPC attempts attack action
- **Actual:** No hostile NPCs attacked; all report `action_id=idle`
- **Observation:** Hostile NPCs (role=criminal) use criminal_hostile tree but conditions not met

---

### 2. test_b1_npc_movement.gd (0 failures - PASSED)

**File:** `tests/test_b1_npc_movement.gd`

- **Status:** PASSED (16/16 assertions)
- **Note:** Test has lower threshold (0.75m after 240 frames, at least 50% of NPCs)
- **Observation:** NPCs still get `action_id=idle` but steering produces minimal movement that accumulates to pass the test

---

### 3. test_game_ai.gd (4 failures)

**File:** `tests/test_game_ai.gd`

#### Failure 1: "todos los NPC usan CharacterModel con modelo 3D real"
- NPCs not using CharacterModel with real 3D model

#### Failure 2: "el hostil que ve al jugador reduce su salud"
- Hostile NPC seeing player doesn't reduce player health
- Combat/damage integration not working

#### Failure 3: "el civil huye al ver un arma (movimiento 0.23, accion flee)"
- Civilian should flee when seeing weapon
- Actual: movement 0.23, action=flee (movement too low)

#### Failure 4: "CharacterModel genera ragdoll real de la muerte"
- CharacterModel doesn't generate real death ragdoll
- Ragdoll system not implemented

---

### 4. test_z1_nozombies.gd (1 failure)

**File:** `tests/test_z1_nozombies.gd`

#### Failure: "CharacterModel: SKINS dictionary tiene humano no enemy"
- **Expected:** `SKINS["humano"]` contains `"enemy_zombie_basic"`
- **Actual:** `SKINS["humano"]` maps to `"criminal_punk.gltf"`
- **Location:** `core/game/character_model.gd` line ~120

---

## Root Cause Analysis

### Primary Root Cause: Behavior Tree Conditions Not Met

The behavior tree system in `core/npc/bt/bt_tree_builder.gd` builds trees with condition-action sequences. For civilian_pacific mode:

1. **Flee if under attack** → `BTConditionUnderAttack` + `BTActionFlee`
2. **Patrol if routine active** → `BTConditionRoutineActive` + `BTActionPatrol`
3. **Explore if curious** → `BTConditionCanExplore` + `BTActionWander`
4. **Converse if social** → `BTConditionCanConverse` + `BTActionConverse`
5. **Work if office hours** → `BTConditionWorkHours` + `BTActionWork`
6. **Eat if hungry** → `BTConditionNeedsFood` + `BTActionEat`
7. **Rest if tired** → `BTConditionNeedsRest` + `BTActionRest`
8. **Default: Idle** → `BTActionIdle`

**Why NPCs get "idle":**
- NPCs spawned with **empty routine array** (`game_world.gd:893`: `"routine": []`)
- `BTConditionRoutineActive` checks `routine_stop` from blackboard → fails when routine empty
- `BTConditionCanExplore` requires: curiosity ≥ 0.5, fear ≤ 0.3, fatigue ≤ 0.6, mode="pacifico"
- Random personality/needs generation may not meet all thresholds
- All conditions fail → fallthrough to default `BTActionIdle`

**Evidence from logs:**
```
[BT] NPC npc_08: got action_id=idle
[BT] NPC npc_08 tick: action=idle, move_target=(14.73393, 0.0, 5.378504), time=0.0
```
- Move target IS being set (by wander/explore logic in idle action?)
- But action_id is "idle" not "patrol" or "wander"

### Secondary Root Causes

1. **CharacterModel SKINS mapping mismatch** (`core/game/character_model.gd`)
   - Test expects zombie model for "humano" key
   - Code maps "humano" to "criminal_punk.gltf"
   - Asset availability may differ from test expectations

2. **Combat system not integrated with BT** (`core/npc/npc_combat.gd`, `core/game/armed_npc.gd`)
   - Hostile attack conditions (`BTConditionHasEnemy`, `BTConditionHasAdvantage`) not evaluating true
   - Damage application not triggered from behavior tree actions

3. **Ragdoll system not implemented** (`core/game/character_model.gd`)
   - No ragdoll generation on death
   - Test expects real physics ragdoll

4. **Steering integration works but action is wrong**
   - Steering computes acceleration correctly (non-zero values in logs)
   - NPCs move minimally because "idle" action doesn't sustain movement toward target
   - `_update_steering` uses `move_target` from blackboard but action is "idle"

---

## Recommended Fixes

### Priority 1: Fix NPC Movement (Behavior Tree Conditions)

**Option A: Provide default routines for spawned NPCs**
- Modify `game_world.gd:_spawn_living_npcs` to generate patrol routes
- Use `patrol_points` pool (already passed in spawn options)

**Option B: Add fallback wander action in civilian_pacific tree**
- Add `BTActionWander` as fallback before idle
- Lower `BTConditionCanExplore` thresholds or make it always true in pacific mode

**Option C: Fix idle action to actually move toward target**
- Current `BTActionIdle` likely returns OK immediately
- Should use `move_target` from blackboard and return RUNNING while moving

### Priority 2: Fix CharacterModel SKINS Mapping
- Align `character_model.gd` SKINS with test expectations
- Or update test to match actual asset availability
- Verify "enemy_zombie_basic" asset exists

### Priority 3: Fix Hostile Attack Behavior
- Verify `BTConditionHasEnemy` and `BTConditionHasAdvantage` logic
- Ensure combat component properly sets threat/target in blackboard
- Connect `BTActionAttack` to combat damage system

### Priority 4: Implement Ragdoll System
- Add ragdoll generation in `CharacterModel` on death
- Integrate with `ArmedNpc` death handling

---

## Files Requiring Changes (Claim Status)

| File | Status | Claimed By |
|------|--------|------------|
| `tests/test_ai2_integration.gd` | **Claimed** | helper_1795222981 |
| `core/game/game_world.gd` | Available (B) | - |
| `core/npc/bt/bt_tree_builder.gd` | Claimed | helper_1795222981, helper_1795229999 |
| `core/npc/bt/conditions/bt_condition_routine_active.gd` | Available (B) | - |
| `core/npc/bt/conditions/bt_condition_can_explore.gd` | Available (B) | - |
| `core/npc/bt/actions/bt_action_idle.gd` | Available (B) | - |
| `core/npc/bt/actions/bt_action_wander.gd` | Available (B) | - |
| `core/game/character_model.gd` | Claimed | helper_1795226419, helper_1795228393 |
| `core/npc/npc_combat.gd` | Claimed | helper_1795228367 |
| `core/game/armed_npc.gd` | Claimed | helper_1795222981, helper_1795228342 |

---

## Next Steps

1. **Coordinate with helper_1795222981** who claims `test_ai2_integration.gd` and related BT files
2. **Claim available files** to implement fixes:
   - `core/game/game_world.gd` - add routines to spawned NPCs
   - `core/npc/bt/conditions/bt_condition_routine_active.gd` - adjust condition
   - `core/npc/bt/actions/bt_action_idle.gd` - make idle move toward target
3. **Update test expectations** for CharacterModel SKINS if asset differs
4. **Re-run all tests** after fixes to verify 8/9 NPCs advance >1m and hostile attacks work

---

## Test Commands for Verification

```bash
# Run integration test
termux-chroot "bash -c \"grun ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless --path . --script tests/test_ai2_integration.gd\""

# Run movement test
termux-chroot "bash -c \"grun ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless --path . --script tests/test_b1_npc_movement.gd\""

# Run game AI test
termux-chroot "bash -c \"grun ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless --path . --script tests/test_game_ai.gd\""

# Run no zombies test
termux-chroot "bash -c \"grun ~/tools/godot-4.7-stable/Godot_v4.7-stable_linux.arm64 --headless --path . --script tests/test_z1_nozombies.gd\""
```