# Issue #59 Analysis: Enemy Aiming at Player Behind Cover

## Issue Summary (Russian -> English Translation)

**Original Title:** "fix when the player is behind cover, the enemy should not keep them 'in sight'"

**Issue Description:**
When the player is presumably behind cover (the enemy can't hit them), the enemy still rotates towards the player's movement direction.

**Expected Behavior:**
1. When the player hides behind cover and the enemy sees this, that cover is considered "player's cover"
2. Enemies should aim slightly above or below this cover (where the player might appear)
3. The cover status should reset when the enemy sees the player again

## Root Cause Analysis

### Original Code Behavior (scripts/objects/enemy.gd)

The `_aim_at_player()` function always aimed directly at `_player.global_position`:

```gdscript
func _aim_at_player() -> void:
    if _player == null:
        return
    var direction := (_player.global_position - global_position).normalized()
    var target_angle := direction.angle()
    # ... rotation logic
```

This meant:
- Even when `_can_see_player` was `false` (player behind cover), the enemy still rotated toward the player's actual position
- In COMBAT state, `rotation = direction_to_player.angle()` directly set rotation to face player
- In PURSUING state and other states, `_aim_at_player()` was called even when visibility was blocked

### Missing Features (Before Fix)

1. **No cover position tracking**: When the player hid behind cover, the system didn't remember WHERE they hid
2. **No "aim at cover exits" behavior**: Enemies didn't aim at likely emergence points
3. **No cover obstacle tracking**: The system didn't track which obstacle the player hid behind

## Implemented Solution

### 1. Cover Position Tracking

New variables added to track cover information:

```gdscript
## Position where the player was last seen before going behind cover.
var _player_last_visible_position: Vector2 = Vector2.ZERO

## The obstacle/collider that the player hid behind.
var _player_cover_obstacle: Object = null

## Position of the cover obstacle's collision point (where raycast hit).
var _player_cover_collision_point: Vector2 = Vector2.ZERO

## Whether the enemy is actively tracking a player who hid behind cover.
var _tracking_player_behind_cover: bool = false

## Timer for alternating aim between cover exit points.
var _cover_aim_alternate_timer: float = 0.0

## Current side to aim at (1.0 = one side, -1.0 = other side of cover).
var _cover_aim_side: float = 1.0
```

### 2. Modified `_check_player_visibility()`

When the raycast hits an obstacle instead of the player:
- Stores the obstacle reference (`_player_cover_obstacle`)
- Stores the collision point (`_player_cover_collision_point`)
- Stores the player's last visible position (`_player_last_visible_position`)
- Sets `_tracking_player_behind_cover = true`

When the player becomes visible again:
- Resets all tracking variables
- Logs the state change for debugging

### 3. New Aiming System

Created two new functions:

**`_get_aim_target_position()`** - Returns the correct position to aim at:
- If player is behind cover: returns cover exit point
- Otherwise: returns player's actual position

**`_get_cover_exit_aim_target()`** - Calculates cover exit points:
- Computes perpendicular direction to the cover collision point
- Alternates between two exit points (above/below cover) every 1.5 seconds
- Uses 80 pixel offset from cover center

### 4. Updated `_aim_at_player()`

Modified to use `_get_aim_target_position()` instead of directly accessing `_player.global_position`:

```gdscript
func _aim_at_player() -> void:
    if _player == null:
        return
    var target_position := _get_aim_target_position()
    var direction := (target_position - global_position).normalized()
    var target_angle := direction.angle()
    # ... rotation logic
```

### 5. Updated Direct Rotation Assignments

Replaced direct `rotation = direction_to_player.angle()` calls with `_aim_at_player()` in:
- COMBAT state sidestepping (line 1329)
- COMBAT state seeking clear shot (line 1381)
- COMBAT state approach phase (line 1434)

### 6. Debug Visualization (F7)

Added visual feedback when `debug_label_enabled` is true:
- Purple line and X marker at cover collision point
- Lime green line to current aim target (exit point)
- Small lime green squares at both potential exit positions

## Files Modified

1. `scripts/objects/enemy.gd` - All changes in this file:
   - Added new tracking variables (lines 551-576)
   - Modified `_check_player_visibility()` (lines 3367-3430)
   - Modified `_aim_at_player()` (lines 3433-3463)
   - Added `_get_aim_target_position()` (lines 3466-3478)
   - Added `_get_cover_exit_aim_target()` (lines 3481-3503)
   - Updated COMBAT state rotation handling
   - Modified `_reset()` to include new variables
   - Added debug visualization in `_draw()` (lines 4180-4215)

## Testing Strategy

1. **Visual Test (F7 Debug)**:
   - Enter game, press F7 to enable debug mode
   - Hide behind cover while enemy is tracking you
   - Verify purple X appears at cover collision point
   - Verify lime green line shows current aim direction
   - Verify aim alternates between exit points every 1.5 seconds

2. **Gameplay Test**:
   - Aggro an enemy, then hide behind cover
   - Observe that enemy doesn't track your exact position
   - Observe that enemy aims at cover edges
   - Emerge from cover and verify enemy resumes direct tracking

3. **State Transition Test**:
   - Verify cover tracking activates in COMBAT, PURSUING, FLANKING, ASSAULT states
   - Verify cover tracking resets on player visibility
   - Verify cover tracking resets on enemy reset/respawn
