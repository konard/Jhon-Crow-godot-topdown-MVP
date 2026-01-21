# Case Study: Issue 159 - Wall Penetration System Analysis

## Issue Summary

This document analyzes the implementation and debugging of the wall penetration system for bullets in the game.

## Reported Problems

1. **Hole display not working** - Entry/exit holes were circular decals, not bullet trails
2. **Penetration not working for player** - Player bullets may not have been triggering penetration
3. **Enemy bullets don't disappear after 48px travel** - Bullets were not being destroyed at max penetration distance

## Root Cause Analysis

### Problem 1: Visual Holes

**Original Implementation:**
- `spawn_penetration_hole()` in ImpactEffectsManager spawned `BulletHole.tscn` (circular radial gradient)
- Entry and exit holes were separate circular decals at penetration points

**Issue:**
- User expected a continuous dark trail through the wall (bullet path), not separate circular holes
- The visual feedback didn't clearly show the bullet trajectory through the wall

**Fix:**
- Disabled circular entry/exit hole spawning in `_spawn_penetration_hole_effect()`
- The visual trail is now created entirely by the `PenetrationHole` collision hole (Line2D drawing a dark line from entry to exit)
- Dust effects are still spawned at entry/exit for realism

### Problem 2: Player Penetration

**Original Implementation:**
```gdscript
if "shooter_position" in bullet:
    bullet.shooter_position = global_position
```

**Potential Issues:**
1. The `in` operator with GDScript objects checks property existence
2. While `shooter_position` is defined in the bullet script, timing issues could occur
3. The distance-based penetration calculation relies on `shooter_position` to determine ricochet vs penetration behavior

**Fix:**
- Removed conditional check - direct assignment since bullet script always has this property
- Added debug logging to trace distance calculations
- Changed from `if "shooter_position" in bullet:` to direct `bullet.shooter_position = global_position`

### Problem 3: Bullets Not Disappearing at 48px

**Original Implementation:**
```gdscript
func _is_still_inside_obstacle() -> bool:
    # ... raycast only 2 pixels forward/backward
    var ray_end := global_position + direction * 2.0
```

**Issues:**
1. Raycast distance (2 pixels) was too short for bullet speed (2500 px/s = ~41 pixels/frame at 60 FPS)
2. When max penetration distance was exceeded, bullet was destroyed without leaving a visual trail
3. The raycast couldn't reliably detect if bullet was still inside the obstacle

**Fixes:**
1. Increased raycast distance to 50 pixels (slightly more than max penetration of 48)
2. Added visual trail spawning before destroying bullet at max distance
3. Added dust effect at termination point

## Debug Logging

Debug logging is enabled (`_debug_penetration = true`) in bullet.gd to help trace penetration behavior in logs. Key log messages:

- `[Bullet] Starting wall penetration at ...`
- `[Bullet] Distance to wall: ... (N% of viewport)`
- `[Bullet] Point-blank shot - 100% penetration, ignoring ricochet`
- `[Bullet] Max penetration distance exceeded: ...`
- `[Bullet] Exiting penetration at ... after traveling N pixels through wall`
- `[Bullet] Raycast forward/backward hit penetrating body at distance ...`

## Files Modified

1. `scripts/projectiles/bullet.gd` - Main penetration logic fixes
2. `scripts/characters/player.gd` - Removed conditional shooter_position check
3. `scripts/objects/enemy.gd` - Removed conditional shooter_position check (3 instances)

## Game Logs Analyzed

Logs stored in `docs/case-studies/issue-159/logs/`:
- `game_log_20260121_071155.txt`
- `game_log_20260121_071551.txt`
- `game_log_20260121_072518.txt`
- `game_log_20260121_072958.txt`
- `game_log_20260121_073202.txt`

## Testing Recommendations

1. Test player shooting at thin walls (24px) at close range - should see penetration trail
2. Test player shooting at thick walls - bullet should stop inside and leave partial trail
3. Test enemy shooting at player through walls - should see trail and 48px limit
4. Verify dust effects appear at entry and exit points
5. Check debug logs for penetration messages when shooting at walls
