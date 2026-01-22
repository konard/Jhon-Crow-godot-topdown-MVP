# Case Study: Issue #218 - Mini UZI Not Appearing in Armory

## Summary

After adding the Mini UZI weapon to the game, users reported that it was not appearing in the armory menu, making it impossible to select the weapon for gameplay.

## Timeline of Events

### Phase 1: Feature Implementation (Initial PR)

1. **Mini UZI weapon files created:**
   - `Scripts/Weapons/MiniUzi.cs` - C# weapon script with high fire rate, spread mechanics
   - `resources/calibers/caliber_9x19.tres` - 9mm caliber data (can_penetrate=false, max_ricochet_angle=20)
   - `resources/weapons/MiniUziData.tres` - Weapon configuration (15 shots/sec, 0.5 damage, 32 mag)
   - `scenes/projectiles/Bullet9mm.tscn` - 9mm bullet scene
   - `scenes/weapons/csharp/MiniUzi.tscn` - Mini UZI weapon scene

2. **Game Manager updated:**
   - `scripts/autoload/game_manager.gd` - Added `"mini_uzi"` to `WEAPON_SCENES` dictionary (line 35)

3. **Level scripts updated:**
   - `scripts/levels/tutorial_level.gd` - Added Mini UZI weapon swapping support (lines 154-177)
   - `scripts/levels/building_level.gd` - Added Mini UZI weapon swapping support (lines 892-915)

### Phase 2: Bug Discovery

User reported the issue with the following observation:
- "uzi не добавилось в armory, возможно конфликт языков или импортов"
- (Translation: "UZI was not added to armory, possibly a language or import conflict")

### Phase 3: Investigation

#### Game Log Analysis

The provided game log (`game_log_20260122_102037.txt`) showed:
- Game initialized correctly
- All systems loaded properly
- Armory menu opened at 10:20:38 and 10:20:55
- No error messages related to Mini UZI
- No log entry showing Mini UZI being loaded or displayed

Key log entries:
```
[10:20:38] [INFO] [PauseMenu] Armory button pressed
[10:20:38] [INFO] [PauseMenu] Creating new armory menu instance
[10:20:38] [INFO] [PauseMenu] armory_menu_scene resource path: res://scenes/ui/ArmoryMenu.tscn
[10:20:38] [INFO] [PauseMenu] _populate_weapon_grid method exists
```

The log shows the armory menu was created and `_populate_weapon_grid` was called, but no Mini UZI-specific loading occurred.

#### Code Analysis

**File: `scripts/ui/armory_menu.gd`**

The `WEAPONS` dictionary (lines 16-75) defines all weapons that appear in the armory menu:

```gdscript
const WEAPONS: Dictionary = {
    "m16": {...},
    "flashbang": {...},
    "frag_grenade": {...},
    "ak47": {...},
    "shotgun": {...},
    "smg": {...},
    "sniper": {...},
    "pistol": {...}
}
```

**Finding:** The `"mini_uzi"` entry was **not present** in this dictionary, despite being added to:
- `game_manager.gd` `WEAPON_SCENES` dictionary
- `tutorial_level.gd` weapon swapping logic
- `building_level.gd` weapon swapping logic

## Root Cause

**The Mini UZI was added to the game's internal weapon handling system but was never added to the armory menu's display dictionary.**

The architecture requires weapons to be registered in two places:
1. `game_manager.gd` - For runtime weapon scene loading
2. `armory_menu.gd` - For UI display in the armory selection menu

This is a **data synchronization issue** between the weapon system and the UI layer.

## Solution

### Fix Applied

1. **Added Mini UZI to armory_menu.gd WEAPONS dictionary:**

```gdscript
"mini_uzi": {
    "name": "Mini UZI",
    "icon_path": "res://assets/sprites/weapons/mini_uzi_icon.png",
    "unlocked": true,
    "description": "Submachine gun - 15 shots/sec, 9mm bullets (0.5 damage), high spread, ricochets at ≤20°, no wall penetration. Press LMB to fire.",
    "is_grenade": false
},
```

2. **Created weapon icon:**
   - `assets/sprites/weapons/mini_uzi_icon.png` - 80x24 pixel RGBA icon matching other weapon icons

## Lessons Learned

1. **Checklist for Adding New Weapons:**
   - [ ] Create weapon script (C# or GDScript)
   - [ ] Create weapon data resource (.tres)
   - [ ] Create caliber data if new caliber
   - [ ] Create bullet scene if new caliber
   - [ ] Create weapon scene (.tscn)
   - [ ] Add to `game_manager.gd` `WEAPON_SCENES` dictionary
   - [ ] **Add to `armory_menu.gd` `WEAPONS` dictionary**
   - [ ] Create weapon icon for armory display
   - [ ] Update level scripts for weapon swapping support

2. **Architecture Consideration:**
   The dual-registration requirement (game_manager + armory_menu) creates a maintenance burden. Consider:
   - Single source of truth for weapon definitions
   - Auto-discovery of weapons from resources folder
   - Centralized weapon registry

## Files Modified in Fix

- `scripts/ui/armory_menu.gd` - Added mini_uzi to WEAPONS dictionary
- `assets/sprites/weapons/mini_uzi_icon.png` - New icon file

## Verification

After the fix:
1. Mini UZI should appear in the armory menu
2. Selecting Mini UZI should set it as the active weapon
3. Starting a level should equip the Mini UZI
4. Weapon should function with all specified properties (15 shots/sec, 0.5 damage, etc.)

---

# Phase 2: Additional Bug Fixes (PR #219 - Iteration 2)

## New Issues Discovered

After the initial fix, user testing revealed two additional bugs:

### Bug 1: UZI always shoots to the right

**Symptom:** "узи сейчас стреляет всегда в одном направлении (вправо)"
(Translation: "UZI always shoots in one direction (to the right)")

### Bug 2: UZI bullets don't stop during Last Chance mode

**Symptom:** "во время последнего шанса на высокой сложности пули узи не останавливаются"
(Translation: "During last chance on high difficulty, UZI bullets don't stop")

## Root Cause Analysis

### Bug 1: Direction Issue - Property Name Case Mismatch

**Problem:** C# and GDScript have different naming conventions:
- C# uses PascalCase: `Direction`, `Speed`, `ShooterId`, `ShooterPosition`
- GDScript uses snake_case: `direction`, `speed`, `shooter_id`, `shooter_position`

In `Scripts/AbstractClasses/BaseWeapon.cs` (lines 341-367), the code was setting properties using PascalCase:
```csharp
bullet.Set("Direction", direction);
bullet.Set("Speed", WeaponData.BulletSpeed);
bullet.Set("ShooterId", owner.GetInstanceId());
bullet.Set("ShooterPosition", GlobalPosition);
```

But the `scripts/projectiles/bullet.gd` script (line 33) declares the property as:
```gdscript
var direction: Vector2 = Vector2.RIGHT
```

Since Godot property names are case-sensitive, `Direction` != `direction`, so the direction was never set, defaulting to `Vector2.RIGHT`.

### Bug 2: Bullets Not Freezing - Same Case Mismatch

The `scripts/autoload/last_chance_effects_manager.gd` (lines 825-829) checks for `shooter_id`:
```gdscript
if "shooter_id" in node:
    shooter_id = node.shooter_id
elif "ShooterId" in node:
    shooter_id = node.ShooterId
```

While this code handles both cases, the underlying issue was that C# weapons were setting `ShooterId` (PascalCase), which worked with the fallback, but fixing the direction issue required fixing all properties to use consistent snake_case.

## Solution

### Fix Applied to `Scripts/AbstractClasses/BaseWeapon.cs`

Changed property names from PascalCase to snake_case to match GDScript conventions:

**Before:**
```csharp
bullet.Set("Direction", direction);
bullet.Set("Speed", WeaponData.BulletSpeed);
bullet.Set("ShooterId", owner.GetInstanceId());
bullet.Set("ShooterPosition", GlobalPosition);
```

**After:**
```csharp
bullet.Set("direction", direction);
bullet.Set("speed", WeaponData.BulletSpeed);
bullet.Set("shooter_id", owner.GetInstanceId());
bullet.Set("shooter_position", GlobalPosition);
```

## Lessons Learned (Updated)

1. **Cross-Language Property Access:**
   - When C# code sets properties on GDScript nodes, use GDScript naming conventions (snake_case)
   - Godot property names are **case-sensitive**
   - Document the expected property names in comments

2. **Testing Checklist for Cross-Language Features:**
   - [ ] Verify property names match between C# and GDScript
   - [ ] Test actual bullet direction in gameplay
   - [ ] Test with game mechanics that depend on bullet properties (Last Chance mode)
   - [ ] Log property values during debugging

## Files Modified in Phase 2

- `Scripts/AbstractClasses/BaseWeapon.cs` - Fixed property names to use snake_case

## Game Logs Analyzed

- `docs/case-studies/issue-218/logs/game_log_20260122_102037.txt` - Initial test
- `docs/case-studies/issue-218/logs/game_log_20260122_102836.txt` - Detailed gameplay test showing:
  - Mini UZI successfully selected from armory (line 80)
  - Bullet penetration warnings about shooter_position=(0,0) indicating the fix was needed
  - Last Chance mode detecting "Bullet" and "Bullet9mm" threats

## Related Files

- `Scripts/Weapons/MiniUzi.cs` - Weapon implementation
- `resources/weapons/MiniUziData.tres` - Weapon data
- `resources/calibers/caliber_9x19.tres` - Caliber data
- `scenes/weapons/csharp/MiniUzi.tscn` - Weapon scene
- `scenes/projectiles/Bullet9mm.tscn` - Bullet scene
- `scripts/autoload/game_manager.gd` - Game manager with weapon scenes
- `scripts/levels/tutorial_level.gd` - Tutorial level weapon support
- `scripts/levels/building_level.gd` - Building level weapon support
