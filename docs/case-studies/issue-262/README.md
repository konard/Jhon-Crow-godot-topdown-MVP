# Case Study: Issue #262 - Add Bullet Casings

## Issue Summary

**Issue:** [#262 - Add bullet casings](https://github.com/Jhon-Crow/godot-topdown-MVP/issues/262)

**Original Request (Russian):**
> при стрельбе из оружия должны вылетать гильзы соответствующих патронов (в момент проигрывания соответствующего звука).
> гильзы должны оставаться лежать на полу (не удаляться).

**Translation:**
> When firing weapons, casings of the corresponding cartridges should be ejected (at the moment of playing the corresponding sound).
> Casings should remain on the floor (not deleted).

## Problem Analysis

### Initial Feedback from PR #275 Comments

The repository owner (Jhon-Crow) reported the following issues with the initial implementation:

1. **Casings should eject to the right of the weapon** - Direction verification needed
2. **Casings have no sprite (just pink rectangle)** - Using PlaceholderTexture2D
3. **Different calibers should have different casing sprites** - Need caliber-specific sprites
4. **Shotgun casings should be red** - Color specification for shotgun shells
5. **Missing .NET assemblies in exe archive** - Build/export issue

### Root Cause Analysis

#### Issue 1: Pink Rectangle Instead of Sprite

**Root Cause:** The `Casing.tscn` scene was using `PlaceholderTexture2D` which renders as a magenta/pink rectangle in Godot.

```gdscript
# Original Casing.tscn (problematic)
[sub_resource type="PlaceholderTexture2D" id="PlaceholderTexture2D_casing"]
size = Vector2(8, 16)
```

**Solution:** Create actual PNG sprite assets for each caliber type and load them based on caliber data.

#### Issue 2: Casing Ejection Direction

**Root Cause:** The vector rotation formula for calculating "right side" was using clockwise rotation instead of counter-clockwise.

```csharp
// Original (incorrect for top-down with Y-down)
Vector2 weaponRight = new Vector2(direction.Y, -direction.X); // Clockwise

// Fixed (correct for Godot's coordinate system)
Vector2 weaponRight = new Vector2(-direction.Y, direction.X); // Counter-clockwise
```

In Godot's coordinate system where Y increases downward:
- Weapon pointing right (1, 0) → right side is DOWN (0, 1)
- Weapon pointing up (0, -1) → right side is RIGHT (1, 0)

#### Issue 3: Missing Caliber-Specific Visuals

**Root Cause:** The casing appearance system relied on color modulation rather than actual sprite textures, and the caliber matching logic was incomplete.

## Solution Implementation

### 1. Created Casing Sprites

Three new sprite assets were created in `assets/sprites/effects/`:

| Sprite | Caliber | Size | Color |
|--------|---------|------|-------|
| `casing_rifle.png` | 5.45x39mm | 8x16 px | Brass (gold) |
| `casing_pistol.png` | 9x19mm | 8x12 px | Silver |
| `casing_shotgun.png` | Buckshot | 10x20 px | Red with brass base |

### 2. Updated CaliberData Resource

Added `casing_sprite` property to `scripts/data/caliber_data.gd`:

```gdscript
## Sprite texture for ejected bullet casings.
## Different calibers have different casing appearances.
@export var casing_sprite: Texture2D = null
```

### 3. Updated Caliber Resources

Each caliber resource now references its specific casing sprite:
- `resources/calibers/caliber_545x39.tres` → `casing_rifle.png`
- `resources/calibers/caliber_9x19.tres` → `casing_pistol.png`
- `resources/calibers/caliber_buckshot.tres` → `casing_shotgun.png`

### 4. Updated Casing Script

The `_set_casing_appearance()` function in `scripts/effects/casing.gd` now:
1. First tries to load sprite from CaliberData
2. Falls back to color modulation if no sprite is defined
3. Properly type-checks CaliberData resources

### 5. Fixed Ejection Direction

Updated `SpawnCasing()` in `Scripts/AbstractClasses/BaseWeapon.cs` to use correct rotation formula for Godot's coordinate system.

## Files Changed

- `Scripts/AbstractClasses/BaseWeapon.cs` - Fixed ejection direction calculation
- `scripts/data/caliber_data.gd` - Added casing_sprite property
- `scripts/effects/casing.gd` - Updated appearance logic to use sprites
- `scenes/effects/Casing.tscn` - Replaced PlaceholderTexture2D with actual sprite
- `resources/calibers/caliber_545x39.tres` - Added casing sprite reference
- `resources/calibers/caliber_9x19.tres` - Added casing sprite reference
- `resources/calibers/caliber_buckshot.tres` - Added casing sprite reference
- `assets/sprites/effects/casing_rifle.png` - New sprite (brass)
- `assets/sprites/effects/casing_pistol.png` - New sprite (silver)
- `assets/sprites/effects/casing_shotgun.png` - New sprite (red)

## Timeline

1. **Initial Implementation:** Added basic casing system with placeholder texture
2. **Feedback Received:** Owner reported pink rectangles and direction issues
3. **Analysis:** Identified PlaceholderTexture2D and rotation formula issues
4. **Fix Applied:** Created proper sprites, updated caliber system, fixed physics

## Lessons Learned

1. **Never use PlaceholderTexture2D in production scenes** - Always create actual sprite assets
2. **Verify coordinate system conventions** - Godot uses Y-down, which affects rotation calculations
3. **Test with multiple weapon orientations** - Direction-based calculations need testing in all 4 cardinal directions
4. **Resource-based sprite assignment** - CaliberData is the right place for casing appearance data

## Related Files

- `logs/game_log_20260123_201124.txt` - Game log from testing session
- `logs/solution-draft-log-1.txt` - First solution attempt log
- `logs/solution-draft-log-2.txt` - Second solution attempt log
