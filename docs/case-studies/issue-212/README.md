# Issue #212: Shotgun Pellets Grouping Together as Single Projectile

## Issue Summary

**Title:** fix дробовик
**Translation:** Fix shotgun
**Description:** иногда дробь ломается и летит как одна большая дробина
**Translation:** Sometimes the pellets break and fly as one large pellet

## Timeline of Events

1. The shotgun was implemented with a "cloud pattern" that spawns 6-12 pellets simultaneously
2. Each pellet is given a different angle based on the 15° spread angle and a random spatial offset (±15px)
3. Users reported that sometimes all pellets appear to merge into "one large pellet"
4. This issue occurs intermittently, suggesting a conditional code path

## Root Cause Analysis

### Problem Location

The issue is in `Scripts/Weapons/Shotgun.cs`, specifically in the `SpawnPelletWithOffset()` method at lines 1056-1102.

### The Point-Blank Detection

The code checks if a wall blocks the bullet spawn path:

```csharp
// Line 1063-1076
var (isBlocked, hitPosition, hitNormal) = CheckBulletSpawnPath(direction);

Vector2 spawnPosition;
if (isBlocked)
{
    // Wall detected at point-blank range - spawn at weapon position
    spawnPosition = GlobalPosition + direction * 2.0f;  // <-- PROBLEM: Only 2 pixels!
}
else
{
    // Normal case: spawn at offset position plus extra cloud offset
    spawnPosition = GlobalPosition + direction * (BulletSpawnOffset + extraOffset);
}
```

### Why This Causes Pellet Grouping

When `isBlocked` is true (wall detected at point-blank range):

1. **All pellets spawn at only 2 pixels from the gun position**
2. The spread angle is 15° (±7.5° from center)
3. At 2 pixels distance, the angular spread produces almost no visible separation

**Mathematical proof:**
- Perpendicular separation at 2px distance with 7.5° angle: `2 * tan(7.5°) ≈ 0.26 pixels`
- This is less than 1 pixel - all pellets are essentially at the **same position**

### Normal Case (No Wall)

When there's no wall blocking:
- `BulletSpawnOffset` = 20 pixels (default)
- `extraOffset` = ±15 pixels (from `MaxSpawnOffset`)
- Pellets spawn at 5-35 pixels from gun
- At 20 pixels with 7.5° spread: `20 * tan(7.5°) ≈ 2.6 pixels` separation - visible spread

### Code Flow

1. Player fires shotgun near a wall
2. `Fire()` calls `FirePelletsAsCloud()`
3. For each pellet (6-12), `SpawnPelletWithOffset()` is called
4. `CheckBulletSpawnPath()` returns `isBlocked = true` for ALL pellets (same origin)
5. ALL pellets spawn at `GlobalPosition + direction * 2.0f`
6. With minimal angular separation at 2 pixels, pellets appear grouped

## Affected Code Sections

### File: `Scripts/Weapons/Shotgun.cs`

**Function: `SpawnPelletWithOffset()`**
```csharp
// Lines 1066-1076
Vector2 spawnPosition;
if (isBlocked)
{
    // Wall detected at point-blank range - spawn at weapon position
    spawnPosition = GlobalPosition + direction * 2.0f;  // <-- BUG: Too small offset
}
else
{
    // Normal case: spawn at offset position plus extra cloud offset
    spawnPosition = GlobalPosition + direction * (BulletSpawnOffset + extraOffset);
}
```

## Proposed Solution

When a wall is detected at point-blank range, maintain the pellet spread by:

1. Using a minimum spawn distance that preserves visible spread
2. Still applying the `extraOffset` for cloud effect variation
3. Ensuring pellets spawn far enough apart to be visually distinct

### Fix Implementation

```csharp
if (isBlocked)
{
    // Wall detected at point-blank range
    // FIX: Use a minimum offset that preserves visible pellet spread
    // At 2px with 7.5° spread, pellets have <1px separation (appear grouped)
    // At 10px with 7.5° spread, pellets have ~1.3px separation (visible spread)
    // Still apply a portion of the cloud offset for variation
    float minSpawnOffset = 10.0f;
    float cloudOffset = Mathf.Max(0, extraOffset) * 0.5f;
    spawnPosition = GlobalPosition + direction * (minSpawnOffset + cloudOffset);
}
```

## Files to Modify

1. `Scripts/Weapons/Shotgun.cs`
   - `SpawnPelletWithOffset()` method

## Testing Checklist

- [ ] Fire shotgun at normal range - verify pellets spread correctly
- [ ] Fire shotgun directly against a wall (point-blank) - verify pellets still spread
- [ ] Fire shotgun at various angles near walls - verify spread is maintained
- [ ] Verify pellets still interact correctly with wall collision
- [ ] Verify pellets can still penetrate/ricochet as expected

## Log Files

- `game_log_20260122_082359.txt` - First gameplay session with shotgun
- `game_log_20260122_110105.txt` - Second gameplay session with shotgun

## Related Issues and PRs

- Issue #199 - Original shotgun implementation
- PR #201 - Cloud pattern implementation
- Issue #211 - Pellets not freezing in last chance mode (different issue)
- PR #220 - Fix for issue #211
