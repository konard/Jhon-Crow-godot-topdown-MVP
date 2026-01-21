# Case Study: Issue #59 - Enemy Cover Aiming Behavior

## Issue Summary

**Issue:** When the player hides behind cover, enemies should aim at the potential exit points of the cover rather than tracking the player's actual position behind it.

**Expected behavior:**
- When player hides behind cover, enemy aims at where player might emerge
- Enemy alternates aim between two exit points (above and below cover)
- When player becomes visible again, normal aiming resumes

**Actual behavior (bug):**
- Enemy continues to track player's actual position even behind cover
- Enemy rotation appears correct but bullets still shoot toward hidden player

## Timeline of Investigation

### Session 1: Initial Implementation (2026-01-21 ~02:30)

1. Implemented cover tracking variables:
   - `_player_cover_obstacle` - Reference to obstacle blocking view
   - `_player_cover_collision_point` - Where raycast hit the obstacle
   - `_tracking_player_behind_cover` - Flag for cover tracking state
   - `_cover_aim_alternate_timer` / `_cover_aim_side` - For alternating aim

2. Added cover detection in `_check_player_visibility()`:
   - When raycast hits obstacle before player, stores collision point
   - Sets `_tracking_player_behind_cover = true`

3. Created `_get_aim_target_position()` and `_get_cover_exit_aim_target()`:
   - Returns cover exit point when tracking player behind cover
   - Calculates perpendicular direction for exit points
   - Alternates between sides every 1.5 seconds

4. Modified `_aim_at_player()` to use `_get_aim_target_position()`

5. Added debug visualization in `_draw()` for cover tracking

### Session 2: User Reports Problem Persists (2026-01-21 ~02:38)

User provided game log (`game_log_20260121_053401.txt`) showing the issue still occurs.

## Root Cause Analysis

### Log Analysis

Searched game log for cover-related messages:
- Found many `IN_COVER` state transitions (enemy taking cover from player)
- **No "Player hid behind cover" messages appeared**
- This indicates `_log_debug()` messages were not being logged

### Code Review

Examined `_log_debug()` function:
```gdscript
func _log_debug(message: String) -> void:
    if debug_logging:
        print("[Enemy %s] %s" % [name, message])
```

The `debug_logging` variable is `false` by default, so cover tracking debug messages never appeared in the log.

### Critical Bug Found

**In `_shoot()` function (line 3507):**
```gdscript
func _shoot() -> void:
    ...
    var target_position := _player.global_position  # <-- BUG: Always uses player's actual position!

    # Apply lead prediction if enabled
    if enable_lead_prediction:
        target_position = _calculate_lead_prediction()
    ...
```

The `_shoot()` function completely ignores the cover tracking system and always shoots at `_player.global_position`.

**Result:** The enemy visually rotates toward cover exit points (via `_aim_at_player()` using `_get_aim_target_position()`), but the bullets are still fired at the player's actual hidden position.

### Additional Issues Found

1. **No logging to file** - Cover tracking uses `_log_debug()` which only prints to console when `debug_logging=true`, not to the file logger. Important events should use `_log_to_file()`.

2. **Shooting behavior inconsistency** - Even if the enemy can't see the player, bullets may still be fired in their direction if enemy is in certain states.

## Solution

### Fix 1: Make `_shoot()` Use Cover Exit Position

The `_shoot()` function should use `_get_aim_target_position()` when determining where to shoot:

```gdscript
func _shoot() -> void:
    ...
    # When player is behind cover, shoot at cover exit points, not player position
    var base_target := _get_aim_target_position()
    var target_position := base_target

    # Only apply lead prediction when shooting at visible player
    if enable_lead_prediction and not _tracking_player_behind_cover:
        target_position = _calculate_lead_prediction()
    ...
```

### Fix 2: Add File Logging for Cover Tracking

Add `_log_to_file()` calls for important cover tracking events:
- When player hides behind cover
- When player emerges from cover
- When switching aim sides

### Fix 3: Prevent Shooting When Player Not Visible

Consider whether enemies should shoot at all when tracking a player behind cover, or only aim there as a deterrent. Current implementation allows shooting at cover exits which seems intentional for suppressive fire.

## Files Modified

- `scripts/objects/enemy.gd` - Main implementation

## Test Plan

1. Enable debug mode (F7) in game
2. Find enemy and engage in combat
3. Hide behind cover/obstacle
4. Verify:
   - Purple X appears at cover collision point
   - Lime green line shows aim target at cover exit
   - Enemy bullets are actually fired at cover exit points (not at player)
   - Enemy alternates aim between both exit points
5. Emerge from cover and verify normal tracking resumes

## Related Issues and PRs

- PR #156: Adds FOV (field of view) to enemies - merged into this fix
- Issue #66: Original FOV request

## Conclusion

The bug was a classic case of "visual feedback not matching actual behavior" - the enemy appeared to aim correctly (rotation) but bullets went to the wrong target. The fix ensures both visual aim AND bullet trajectory respect the cover exit position system.
