# Issue #199 - Fix Shotgun Mechanics

## Executive Summary

The shotgun weapon was added but has several mechanical issues that deviate from the intended design. This document analyzes the root causes and details the implemented solutions.

## Issue Translation (Russian to English)

Original issue text:
> A shotgun was added, but it shoots and reloads incorrectly.

### Expected Behavior

**Reload Sequence:**
1. RMB drag down (open chamber)
2. MMB → RMB drag down (load shell, repeatable up to 8 times)
3. RMB drag up (close chamber)

**Firing Sequence:**
1. LMB (fire)
2. RMB drag up (eject shell)
3. RMB drag down (chamber next round)

**Additional Requirements:**
- No magazine interface (shotgun doesn't use magazines)
- Fire pellets in "swarm" pattern (not as a flat wall)
- Ricochet limited to 35 degrees max
- Pellet speed should match assault rifle bullets

## Current Implementation Analysis

### 1. Reload Mechanism (Shotgun.cs)
**Current:** Uses standard magazine reload inherited from BaseWeapon
**Problem:** Magazine-based reload doesn't match pump-action shotgun mechanics
**Root Cause:** Shotgun extends BaseWeapon which assumes magazine-based ammo
**Status:** Partially addressed - magazine UI is now hidden for shotgun

### 2. Pellet Firing Pattern
**Current:** All pellets spawn simultaneously at the same position
**Problem:** Creates a "flat wall" pattern instead of realistic swarm
**Root Cause:** `FirePellets()` spawns all pellets in single loop without delay
**Status:** FIXED - Now uses `FirePelletsWithDelay()` with 8ms delays

### 3. Ricochet Angle
**Current:** `MaxRicochetAngle = 90.0f` in Bullet.cs
**Problem:** Allows ricochets at nearly perpendicular angles (unrealistic for pellets)
**Root Cause:** Same Bullet class is used for both rifle bullets and shotgun pellets
**Status:** FIXED - New ShotgunPellet.cs with MaxRicochetAngle = 35.0f

### 4. Pellet Speed
**Current:** `BulletSpeed = 1200.0` in ShotgunData.tres
**Problem:** Slower than assault rifle bullets (2500.0)
**Expected:** Should approximately match assault rifle speed
**Status:** FIXED - Updated to 2500.0

## Data Analysis

### Log File Analysis (game_log_20260122_042545.txt)

Key observations from log analysis:
- Shotgun fires 6-12 pellets per shot (random)
- All pellets spawn at same timestamp
- Ricochet events occur at various angles including high angles

### Log File Analysis (game_log_20260122_043643.txt)

Additional observations:
- Confirms simultaneous pellet spawning
- Shows ricochet behavior at angles near 90 degrees

## Implemented Solutions

### Solution 1: Created ShotgunPellet.cs
New projectile class specifically for shotgun pellets with:
- `MaxRicochetAngle = 35.0f` (down from 90.0f for bullets)
- No wall penetration capability (pellets stop on impact)
- Higher velocity retention on ricochet (0.75)
- Damage multiplier on ricochet (0.5)

**Key Code:**
```csharp
// Ricochet Configuration (Shotgun Pellet - limited to 35 degrees)
private const float MaxRicochetAngle = 35.0f;  // Was 90.0f in Bullet.cs
private const float BaseRicochetProbability = 1.0f;
private const float VelocityRetention = 0.75f;
private const float RicochetDamageMultiplier = 0.5f;
```

### Solution 2: Updated Shotgun.cs with Swarm Firing
Added delay between pellet spawns to create "swarm" effect:
- Default delay: 8ms between each pellet
- Pellets distributed across spread cone with randomness
- Some pellets ahead of others due to timing

**Key Code:**
```csharp
private async void FirePelletsWithDelay(Vector2 fireDirection, int pelletCount,
    float spreadRadians, float halfSpread, PackedScene projectileScene)
{
    for (int i = 0; i < pelletCount; i++)
    {
        SpawnPellet(pelletDirection, projectileScene);
        if (i < pelletCount - 1 && PelletSpawnDelay > 0)
        {
            await ToSignal(GetTree().CreateTimer(PelletSpawnDelay), "timeout"); // 8ms delay
        }
    }
}
```

### Solution 3: Updated ShotgunData.tres
Changed `BulletSpeed` from 1200.0 to 2500.0 to match assault rifle.

### Solution 4: Magazine UI Hidden for Shotgun
Added `UsesTubeMagazine` property to Shotgun class:
- When true, magazine counter UI is hidden
- Level scripts (building_level.gd, test_tier.gd) check this property
- Shows only ammo counter, not magazine inventory

**Key Code:**
```csharp
// In Shotgun.cs
public bool UsesTubeMagazine { get; } = true;
```

```gdscript
# In level scripts
if weapon != null and weapon.get("UsesTubeMagazine") == true:
    _magazines_label.visible = false
    return
```

## Files Modified

### New Files:
1. `Scripts/Projectiles/ShotgunPellet.cs` - New pellet projectile with 35° ricochet limit
2. `scenes/projectiles/csharp/ShotgunPellet.tscn` - Scene for shotgun pellets
3. `docs/case-studies/issue-199/analysis.md` - This analysis document
4. `docs/case-studies/issue-199/game_log_20260122_042545.txt` - Game log file
5. `docs/case-studies/issue-199/game_log_20260122_043643.txt` - Game log file

### Modified Files:
1. `Scripts/Weapons/Shotgun.cs` - Added swarm firing, PelletScene, UsesTubeMagazine
2. `resources/weapons/ShotgunData.tres` - Updated BulletSpeed to 2500.0
3. `scenes/weapons/csharp/Shotgun.tscn` - Added PelletScene reference
4. `scripts/levels/building_level.gd` - Hide magazine UI for shotgun
5. `scripts/levels/test_tier.gd` - Hide magazine UI for shotgun

## Known Limitations

The following features from the original request are not yet implemented:
- Full drag-and-drop reload sequence (RMB gestures for shell loading)
- Pump-action cycling after each shot (RMB drag up/down)
- Shell-by-shell loading animation

These require significant input system changes and are deferred for future implementation.

## References

- [Shotgun Pellet Ricochet Study](https://store.astm.org/jfs11425j.html)
- [2024 Ricochet Research](https://www.sciencedirect.com/science/article/abs/pii/S1355030624000704)
- Previous research: `docs/case-studies/issue-194/research-shotgun-mechanics.md`
