# Case Study: Issue #318 - Enemies Should Not See Actions During Special Last Chance

## Overview

**Issue:** Enemies should not see actions during special last chance - if the player hid from view, enemies should not know where they went, should perceive it as teleportation.

**Related PR:** PR #316 - Enemy memory system implementation

## Timeline of Events

### 1. Enemy Memory System Added (PR #316)

The enemy memory system was implemented with:
- `EnemyMemory` class (`scripts/ai/enemy_memory.gd`) that tracks:
  - `suspected_position`: Where the enemy thinks the player is
  - `confidence`: How certain the enemy is (0.0-1.0)
  - `last_updated`: When the position was last updated
- Confidence levels:
  - Visual contact: 1.0 (full confidence)
  - Gunshot sound: 0.7
  - Reload/empty click: 0.6
  - Intel from other enemies: source confidence * 0.9

### 2. Last Chance Effect Implementation

The "Last Chance" effect (`scripts/autoload/last_chance_effects_manager.gd`):
- Triggers on hard mode when player is at 1 HP and a bullet threatens them
- Freezes time for 6 real seconds (everything except the player)
- Player can move and shoot during the freeze
- All fired bullets are frozen until time unfreezes
- Effect can only trigger once per life

### 3. Initial Fix Attempt (PR #319 v1)

The first fix implemented:
- Added `reset_memory()` method to `enemy.gd`
- Called `_reset_all_enemy_memory()` in `last_chance_effects_manager.gd` when effect ends
- Reset the `_memory` object, `_last_known_player_position`, and `_intel_share_timer`

### 4. Issue Still Present (User Report from Jhon-Crow)

User reported that even with the fix, enemies in PURSUING state still behave as if they know where the player is, going exactly to them after the last chance effect ends.

## Root Cause Analysis (Revised)

### The Core Problem

The initial fix only reset the memory, but there are **multiple code paths** that give enemies access to the player's position:

#### Code Path 1: `_can_see_player` Check
In `_get_target_position()` (enemy.gd:3127):
```gdscript
func _get_target_position() -> Vector2:
    # If we can see the player, use their actual position
    if _can_see_player and _player:
        return _player.global_position  # <-- PROBLEM: Bypasses memory!
```

When the last chance effect ends:
1. Memory is reset ✓
2. But `_check_player_visibility()` runs in the next physics frame
3. If player is in line-of-sight, `_can_see_player` becomes `true`
4. `_get_target_position()` returns `_player.global_position` directly
5. Enemy immediately knows new player position!

#### Code Path 2: Fallback to Direct Player Position
In `_get_target_position()` (enemy.gd:3141):
```gdscript
    # Last resort: if player exists, use their position (even if can't see them)
    if _player:
        return _player.global_position  # <-- PROBLEM: Always accessible!
```

Even if memory is reset, this fallback still provides the player's real position.

#### Code Path 3: Direct Player Reference in PURSUING
In `_process_pursuing_state()` (enemy.gd:2342):
```gdscript
    # Use navigation-based pathfinding to move toward player
    _move_to_target_nav(_player.global_position, combat_move_speed)  # <-- PROBLEM!
```

The approach phase uses `_player.global_position` directly, not `_get_target_position()`.

### Evidence from New Logs

From `game_log_20260124_205037.txt`:
```
[20:50:45] [ENEMY] [Enemy1] Memory reset (last chance teleport effect)
...
[20:50:45] [INFO] [LastChance] Reset memory for 10 enemies (player teleport effect)
[20:50:45] [INFO] [LastChance] All process modes restored
...
[20:50:46] [ENEMY] [Enemy3] State: COMBAT -> PURSUING
[20:50:46] [ENEMY] [Enemy4] State: COMBAT -> PURSUING
[20:50:46] [ENEMY] [Enemy2] State: COMBAT -> PURSUING
[20:50:47] [ENEMY] [Enemy4] FLANKING started: target=(1298.44, 1515.316), ...
```

Enemies immediately transition to PURSUING and start FLANKING toward the player's **new** position (1298.44, 1515.316), not their old remembered position.

## Proposed Solution (Revised)

### Required Changes

1. **Reset `_can_see_player` on memory reset**
   - Prevents immediate re-acquisition via visibility check

2. **Add a "confusion" cooldown period**
   - After memory reset, enemies cannot re-acquire player for a brief period (e.g., 0.5-1.0 seconds)
   - This simulates the "teleportation confusion" effect

3. **Transition to IDLE state on memory reset**
   - Enemies in PURSUING/COMBAT should transition to IDLE
   - They must re-detect the player through normal means (visibility, sound)

4. **Fix `_get_target_position()` fallback**
   - Remove or condition the fallback that uses `_player.global_position` when player is not seen and memory is empty

5. **Fix direct player references in PURSUING**
   - The approach phase should use `_get_target_position()` instead of `_player.global_position`

### Implementation Details

Update `reset_memory()` in `enemy.gd`:
```gdscript
func reset_memory() -> void:
    # Reset memory
    if _memory != null:
        _memory.reset()
        _log_to_file("Memory reset (last chance teleport effect)")

    # Reset legacy position
    _last_known_player_position = Vector2.ZERO

    # Reset intel sharing timer
    _intel_share_timer = 0.0

    # CRITICAL: Reset visibility state to prevent immediate re-acquisition
    _can_see_player = false
    _continuous_visibility_timer = 0.0

    # Apply confusion cooldown (prevents seeing player for a brief moment)
    _memory_reset_confusion_timer = MEMORY_RESET_CONFUSION_DURATION

    # Transition active enemies to IDLE to require re-detection
    if _current_state in [AIState.PURSUING, AIState.COMBAT, AIState.ASSAULT, AIState.FLANKING]:
        _transition_to_idle()
```

## Files Changed

1. `scripts/objects/enemy.gd`:
   - Update `reset_memory()` method to reset visibility and state
   - Add `_memory_reset_confusion_timer` variable
   - Update `_check_player_visibility()` to check confusion timer
   - Update `_get_target_position()` to handle empty memory properly

2. `scripts/autoload/last_chance_effects_manager.gd`:
   - Already has `_reset_all_enemy_memory()` call (no changes needed)

## Test Plan

- [x] Enemy updates memory when player is visible before last chance
- [x] During last chance effect, enemy memory is frozen (no updates)
- [x] When last chance ends, enemy memory is reset
- [ ] **NEW: When last chance ends, enemy `_can_see_player` is reset**
- [ ] **NEW: When last chance ends, enemies in PURSUING/COMBAT/FLANKING transition to IDLE**
- [ ] **NEW: Enemies search their OLD remembered position (before reset)**
- [ ] Enemies do NOT know player's new position after reset
- [ ] Enemies must re-acquire player through visual contact or sound
- [ ] Multiple enemies all have memory reset
- [ ] Enemy-to-enemy intel sharing does not override reset (timer reset)
