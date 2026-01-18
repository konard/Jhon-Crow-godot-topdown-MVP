# Case Study: Issue #94 - AI Enemies Shooting Through Walls in COMBAT State

## Issue Summary

**Issue URL:** https://github.com/Jhon-Crow/godot-topdown-MVP/issues/94

**Problem Description (Russian):**
> враги находясь за тонким укрытием или сбоку укрытия начинают стрелять в сторону игрока, при этом все снаряды попадают в стену, в которую направлен выстрел.
> добавь проверку чтоб избежать стрельбы в стену, к которой враг находится впритык.
> сделай надёжный выход врага из укрытия (чтоб выход из укрытия прекращался только тогда, когда враг точно может попасть в игрока).

**English Translation:**
> Enemies behind thin cover or at the side of cover start shooting toward the player, but all projectiles hit the wall they're aiming through.
> Add a check to prevent shooting into a wall that the enemy is right next to.
> Make a reliable cover exit mechanism (so that exiting cover only stops when the enemy can definitely hit the player).

## Timeline and Sequence of Events

### Current Behavior Flow

1. **Enemy detects player** -> `_can_see_player` becomes true via raycast from enemy center to player
2. **Enemy enters COMBAT state** -> Approaches player and starts shooting phase
3. **Enemy positioned near wall/cover edge** -> Enemy is close to or touching thin cover
4. **Shooting logic executes** -> `_shoot()` is called
5. **Shot validation** -> `_should_shoot_at_target()` checks:
   - `_is_firing_line_clear_of_friendlies()` - checks for friendly fire
   - `_is_shot_clear_of_cover()` - checks if obstacles block the shot
6. **BUG: Shot appears clear** -> Raycast from `bullet_spawn_offset` (30px ahead) misses the adjacent wall
7. **Bullet spawns and hits wall** -> Bullet spawns at offset position and immediately collides

## Root Cause Analysis

### Primary Issue: Bullet Spawn Point Validation

**Location:** `scripts/objects/enemy.gd:1893-1917` (`_is_shot_clear_of_cover()`)

The current implementation:
```gdscript
func _is_shot_clear_of_cover(target_position: Vector2) -> bool:
    var direction := (target_position - global_position).normalized()
    var distance := global_position.distance_to(target_position)

    var space_state := get_world_2d().direct_space_state
    var query := PhysicsRayQueryParameters2D.new()
    query.from = global_position + direction * bullet_spawn_offset  # Start from bullet spawn point
    query.to = target_position
    query.collision_mask = 4  # Only check obstacles (layer 3)
    # ... rest of validation
```

**Problem:** The raycast starts from `global_position + direction * bullet_spawn_offset`, which is 30 pixels ahead of the enemy's center. When the enemy is positioned:
- Flush against a wall
- At the side of thin cover
- Very close to any obstacle

The raycast starting point may already be **past** the wall (on the wrong side), or the short distance from enemy center to bullet spawn point crosses through the wall undetected.

### Missing Check: Enemy-to-Spawn-Point Wall Detection

There is no check to verify that the path from the enemy's center to the bullet spawn point is clear.

## First Implementation Attempt (FAILED)

### What Was Done

The first fix attempt added extensive changes to `_process_combat_state()`:
1. Added a new `_is_immediate_path_clear()` function with multiple raycasts (center + two side checks)
2. Modified the exposed phase logic to check wall clearance before entering
3. Added `else: return` branches for null player checks
4. Modified multiple state transitions

### What Went Wrong

**User Feedback:**
> "everything broke - enemies stopped moving, taking damage, etc. F7 debug toggle also stopped working"

**Analysis:**
The changes were too extensive and modified the state machine flow in ways that caused unintended side effects:

1. **Structural changes to `_process_combat_state()`**: The addition of conditional blocks with `else: return` statements altered the control flow
2. **Complex multi-raycast function**: The side-ray checks added complexity that wasn't necessary for the core fix
3. **State machine modifications**: Changes to exposed phase entry/exit conditions affected enemy behavior

The key lesson: **Making multiple changes to a complex state machine simultaneously makes it hard to identify which change caused the regression.**

## Second Implementation Attempt (CONSERVATIVE)

### Approach

After reverting to the main branch, a minimal and conservative fix was implemented:

1. **Single new function**: `_is_bullet_spawn_clear()` - performs ONE raycast from enemy center to bullet spawn point
2. **No state machine changes**: Only the shooting validation was modified
3. **Fail-open safety**: If physics isn't available, allow shooting (prevents total breakage)
4. **Targeted modifications**: Only three places in code were touched

### Implementation Details

```gdscript
## Check if there's an obstacle immediately in front of the enemy that would block bullets.
## This prevents shooting into walls that the enemy is flush against or very close to.
## Uses a single raycast from enemy center to the bullet spawn position.
func _is_bullet_spawn_clear(direction: Vector2) -> bool:
    var space_state := get_world_2d().direct_space_state
    if space_state == null:
        return true  # Fail-open: allow shooting if physics not available

    # Check from enemy center to bullet spawn position plus a small buffer
    var check_distance := bullet_spawn_offset + 5.0

    var query := PhysicsRayQueryParameters2D.new()
    query.from = global_position
    query.to = global_position + direction * check_distance
    query.collision_mask = 4  # Only check obstacles (layer 3)
    query.exclude = [get_rid()]

    var result := space_state.intersect_ray(query)
    if not result.is_empty():
        _log_debug("Bullet spawn blocked: wall at distance %.1f" % [
            global_position.distance_to(result["position"])])
        return false

    return true
```

### Changes Made

1. **`_should_shoot_at_target()`**: Added call to `_is_bullet_spawn_clear()` at the start
2. **`_shoot_with_inaccuracy()`**: Added post-inaccuracy check to prevent rotated shots hitting walls
3. **`_shoot_burst_shot()`**: Added post-rotation check for burst fire

### Total Lines Changed: ~50 (compared to ~150 in first attempt)

## Lessons Learned

1. **Minimal changes**: When fixing a bug in a complex system, make the smallest possible change
2. **Don't modify state machines unless necessary**: The core issue was in shooting validation, not state transitions
3. **Fail-open for safety**: Non-critical checks should fail open (allow the action) if the check itself fails
4. **Test incrementally**: Each change should be testable in isolation
5. **Preserve existing behavior**: Only modify what's strictly necessary to fix the bug

## Impact Assessment

### Files Modified
- `scripts/objects/enemy.gd`

### Risk Level: Low
- Changes are additive (new validation check)
- No state machine modifications
- Existing functionality is preserved
- Fail-open design prevents total breakage

## Testing Strategy

1. **Basic test**: Enemy next to thin wall should not shoot into wall
2. **Normal combat**: Enemy not near walls should shoot normally
3. **Edge cases**:
   - Enemy flush against wall, player on other side
   - Enemy at corner of cover
   - Enemy at edge of thin pillar
4. **Regression test**: Verify enemies still move, take damage, F7 debug works

## References

- Issue: https://github.com/Jhon-Crow/godot-topdown-MVP/issues/94
- Pull Request: https://github.com/Jhon-Crow/godot-topdown-MVP/pull/95
- Main file: `scripts/objects/enemy.gd`
- Key functions:
  - `_shoot()` - Line 2395
  - `_should_shoot_at_target()` - Line 1948
  - `_is_bullet_spawn_clear()` - Line 1923 (NEW)
  - `_is_shot_clear_of_cover()` - Line 1893
