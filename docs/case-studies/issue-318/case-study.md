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

## Root Cause Analysis

### The Problem

When the last chance effect is triggered:
1. Time freezes for all enemies (`process_mode = DISABLED`)
2. Player can move freely during the 6-second freeze
3. When time unfreezes, enemies still have their old `suspected_position` in memory
4. Enemies continue pursuing the player's OLD position, then see the player in a NEW position
5. This gives enemies "impossible knowledge" - they shouldn't know where the player moved during the freeze

### Evidence from Logs

From `game_log_20260124_201441.txt`:

```
[20:14:50] [INFO] [LastChance] Triggering last chance effect!
[20:14:50] [INFO] [LastChance] Starting last chance effect:
[20:14:50] [INFO] [LastChance]   - Time will be frozen (except player)
[20:14:50] [INFO] [LastChance]   - Duration: 6.0 real seconds
...
[20:14:56] [INFO] [LastChance] Effect duration expired after 6.02 real seconds
[20:14:56] [INFO] [LastChance] Ending last chance effect
...
[20:14:56] [ENEMY] [Enemy10] Player distracted - priority attack triggered
```

Immediately after the effect ends, enemies continue their pursuit with their old memory intact.

### Code Analysis

In `enemy.gd`, the `_update_memory()` function updates memory during `_physics_process()`:

```gdscript
func _update_memory(delta: float) -> void:
    if _memory == null:
        return

    # Visual detection: Update memory with player position at full confidence
    if _can_see_player and _player:
        _memory.update_position(_player.global_position, VISUAL_DETECTION_CONFIDENCE)
        _last_known_player_position = _player.global_position

    # Apply confidence decay over time
    _memory.decay(delta)
    ...
```

During the last chance freeze:
1. Enemies' processing is disabled (`PROCESS_MODE_DISABLED`)
2. `_update_memory()` is NOT called
3. Memory does NOT decay
4. When unfrozen, old memory remains intact

In `last_chance_effects_manager.gd`:
- No signal is emitted when the effect ends
- No notification is sent to enemies
- Enemy memory is not cleared/reset

## Proposed Solution

### Option 1: Clear Enemy Memory When Last Chance Ends

Add a signal in `last_chance_effects_manager.gd` that is emitted when the effect ends, and have enemies listen to it and reset their memory.

**Pros:**
- Simple implementation
- Clear separation of concerns

**Cons:**
- Requires enemies to listen for global signals

### Option 2: Reset Enemy Memory in LastChanceEffectsManager

When the last chance effect ends, iterate through all enemies and reset their memory.

**Pros:**
- Centralized logic
- No changes needed to enemy.gd for signal handling

**Cons:**
- Couples last_chance_effects_manager to enemy implementation details

### Chosen Approach: Option 2

The most straightforward solution is to have the `last_chance_effects_manager.gd` reset enemy memory when the effect ends. This is consistent with how the manager already handles other game state (freezing bullets, etc.).

## Implementation Details

1. Add a new function `_reset_enemy_memory()` in `last_chance_effects_manager.gd`
2. Call this function in `_end_last_chance_effect()` before unfreezing time
3. The function will:
   - Get all enemies from the "enemies" group
   - Call `reset_memory()` on each enemy that has this method
4. Add `reset_memory()` method to `enemy.gd` that:
   - Resets the `_memory` object
   - Clears `_last_known_player_position`

## Files Changed

1. `scripts/autoload/last_chance_effects_manager.gd` - Add enemy memory reset logic
2. `scripts/objects/enemy.gd` - Add `reset_memory()` method

## Test Plan

- [ ] Enemy updates memory when player is visible before last chance
- [ ] During last chance effect, enemy memory is frozen (no updates)
- [ ] When last chance ends, enemy memory is reset
- [ ] Enemies do NOT know player's new position after reset
- [ ] Enemies must re-acquire player through visual contact or sound
- [ ] Multiple enemies all have memory reset
- [ ] Enemy-to-enemy intel sharing does not override reset (5-second cooldown)
