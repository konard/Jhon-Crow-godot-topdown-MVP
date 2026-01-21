# Case Study: Issue #97 - Add Assault Rifle Model

## Issue Summary

**Issue:** [#97 - добавить модель штурмовой винтовки](https://github.com/Jhon-Crow/godot-topdown-MVP/issues/97)
**Author:** Jhon-Crow
**Date Created:** (See GitHub issue)
**Status:** In Progress

### Original Request (Russian)
> добавить модель к существующей штурмовой винтовке (модель что то типа m16)

### Translation
> Add a model to the existing assault rifle (something like M16)

### Additional Requirements (from PR #176 feedback)
> m16 должна быть и у врагов и у игрока

**Translation:** M16 should be on both enemies AND player.

### Reference Provided
- [SimplePlanes Assault Rifle with Cycling Action](https://www.simpleplanes.com/a/cD8RVZ/Assault-Rifle-with-Cycling-Action)

---

## Timeline of Events

### Phase 1: Initial Issue Analysis (2026-01-21)
1. Issue opened requesting visual model for assault rifle
2. Reference provided: SimplePlanes AEV-972 Groza (drawing from M16, AEK-971, Groza-M, AK series, SCAR-H)
3. Project analyzed to determine implementation approach
4. **Key Finding:** Project is 2D-only (Node2D-based), not 3D

### Phase 2: First Implementation Attempt
1. 2D sprite approach selected (appropriate for project type)
2. M16-style rifle sprite created (80x24 pixels)
3. Sprite integrated into C# AssaultRifle scene
4. Rotation logic added to follow aim direction
5. **Result:** PR #176 created

### Phase 3: User Testing & Feedback (2026-01-21 15:24)
1. User reported: "не появилась" (didn't appear)
2. User suggested: "возможно опять проблема с двуязычностью проекта" (possibly bilingual project issue)
3. User clarified: "m16 должна быть и у врагов и у игрока" (M16 for both enemies AND player)
4. Game log provided: `game_log_20260121_152404.txt`

### Phase 4: Root Cause Investigation
1. Analyzed game log - AssaultRifle is firing correctly (visible in sound propagation logs)
2. Identified bilingual architecture issue: C# vs GDScript implementations
3. **Root Cause 1:** UID mismatch for texture resource
4. **Root Cause 2:** GDScript Enemy doesn't have weapon visual

---

## Root Cause Analysis

### Problem 1: Texture Not Loading (UID Mismatch)

**Technical Details:**
- Godot 4 uses UIDs (Unique Identifiers) for resource referencing
- The M16 texture was added with a manually created UID: `uid://drw7q4m6n8x2p`
- When Godot imports the texture, it assigns its OWN UID which doesn't match
- Result: Texture resource not found, sprite appears invisible

**Evidence from AssaultRifle.tscn (before fix):**
```
[ext_resource type="Texture2D" uid="uid://drw7q4m6n8x2p" path="res://assets/sprites/weapons/m16_rifle.png" id="4_rifle_sprite"]
```

**Solution:** Remove the UID, use path-only reference:
```
[ext_resource type="Texture2D" path="res://assets/sprites/weapons/m16_rifle.png" id="4_rifle_sprite"]
```

### Problem 2: Enemies Don't Have Weapon Visual

**Technical Details:**
- The project has TWO parallel implementations:
  - **C# path:** `scenes/characters/csharp/Player.tscn` → uses `scenes/weapons/csharp/AssaultRifle.tscn` (HAS M16 sprite)
  - **GDScript path:** `scenes/objects/Enemy.tscn` → `scripts/objects/enemy.gd` fires bullets directly (NO weapon visual)

**Architecture Analysis:**
```
C# Player Path:
Player.tscn → AssaultRifle.tscn (child) → RifleSprite (Sprite2D) ✓

GDScript Enemy Path:
Enemy.tscn → enemy.gd → direct bullet instantiation, NO weapon visual ✗
```

**Evidence from enemy.gd line 3349:**
```gdscript
func _shoot() -> void:
    if bullet_scene == null or _player == null:
        return
    ...
    var bullet := bullet_scene.instantiate()
    # No weapon visual, just bullet
```

**Solution:** Add WeaponSprite node to Enemy.tscn and rotation logic to enemy.gd

### Problem 3: Bilingual Project Architecture

**Technical Details:**
This project uses BOTH C# and GDScript:
- C# for newer implementations (Player, AssaultRifle)
- GDScript for older/utility code (Enemy AI, sound propagation)

This creates inconsistencies where visual changes to one system don't automatically propagate to the other.

**Recommendation:** Consider consolidating weapon visuals into a shared approach or ensuring both systems are updated together.

---

## Technical Analysis

### File Structure Before Fix
```
scenes/
├── characters/
│   ├── Player.tscn (GDScript, NO weapon)
│   └── csharp/
│       └── Player.tscn (C#, HAS AssaultRifle child)
├── objects/
│   ├── Enemy.tscn (GDScript, NO weapon visual)
│   └── csharp/
│       └── Enemy.tscn (C#, NO shooting logic)
└── weapons/
    └── csharp/
        └── AssaultRifle.tscn (HAS RifleSprite, but UID broken)
```

### Files Modified (Second Iteration)

1. **`scenes/weapons/csharp/AssaultRifle.tscn`**
   - Removed UID from texture ext_resource to fix loading

2. **`scenes/objects/Enemy.tscn`**
   - Added ext_resource for M16 texture
   - Added WeaponSprite (Sprite2D) node

3. **`scripts/objects/enemy.gd`**
   - Added `@onready var _weapon_sprite: Sprite2D = $WeaponSprite`
   - Added `_update_weapon_sprite_rotation()` function
   - Call rotation update in `_physics_process()`

---

## Solution Implementation

### Fix 1: Remove UID from Texture Reference

**Before:**
```
[ext_resource type="Texture2D" uid="uid://drw7q4m6n8x2p" path="res://assets/sprites/weapons/m16_rifle.png" id="4_rifle_sprite"]
```

**After:**
```
[ext_resource type="Texture2D" path="res://assets/sprites/weapons/m16_rifle.png" id="4_rifle_sprite"]
```

### Fix 2: Add Weapon Sprite to Enemy Scene

**Enemy.tscn changes:**
```
[ext_resource type="Texture2D" path="res://assets/sprites/weapons/m16_rifle.png" id="3_rifle_sprite"]

[node name="WeaponSprite" type="Sprite2D" parent="."]
z_index = 1
texture = ExtResource("3_rifle_sprite")
offset = Vector2(20, 0)
```

### Fix 3: Add Weapon Rotation Logic to enemy.gd

```gdscript
## Reference to the weapon sprite for visual rotation.
@onready var _weapon_sprite: Sprite2D = $WeaponSprite

## Updates the weapon sprite rotation to match the enemy's aim direction.
func _update_weapon_sprite_rotation() -> void:
    if not _weapon_sprite:
        return

    _weapon_sprite.rotation = rotation

    # Flip the sprite vertically when aiming left
    var aiming_left := absf(rotation) > PI / 2.0
    _weapon_sprite.flip_v = aiming_left
```

---

## Logs & Evidence

### Game Log Analysis
- Location: `logs/game_log_20260121_152404.txt`
- Key observations:
  - AssaultRifle is firing correctly (sound propagation shows `source=PLAYER (AssaultRifle)`)
  - Enemies are firing correctly (sound propagation shows `source=ENEMY`)
  - No Godot errors related to missing textures in the log
  - The issue is visual-only (texture not rendering)

---

## Research Data

### M16 Rifle Specifications
| Specification | Value |
|--------------|-------|
| Caliber | 5.56×45mm NATO |
| Action | Gas-operated, rotating bolt |
| Rate of Fire | 700-950 rounds/min |
| Muzzle Velocity | 960 m/s |
| Effective Range | 550m (point), 800m (area) |
| Weight | 3.3 kg (unloaded) |
| Length | 1000mm |
| Barrel Length | 508mm |
| Magazine Capacity | 20 or 30 rounds |

### Godot 4 UID System
- UIDs provide stable resource references across moves/renames
- Auto-generated when resources are imported
- Stored in `.godot/uid_cache.bin` (not committed to git)
- Manual UIDs in .tscn files must match what Godot generates, or use path-only

---

## Lessons Learned

1. **Godot UIDs are auto-generated** - Never manually create UIDs for new resources; either let Godot generate them or use path-only references

2. **Bilingual projects require extra care** - When making visual changes, ensure both C# and GDScript code paths are updated

3. **Test with fresh project import** - The original implementation worked in development because the UID cache existed; fresh clone would fail

4. **User feedback is essential** - The "не появилась" (didn't appear) feedback led directly to discovering the UID mismatch

5. **Check all entity types** - Initial implementation only covered the player; enemy weapon visuals were overlooked

---

## References

### Primary Sources
- [M16 Rifle - Wikipedia](https://en.wikipedia.org/wiki/M16_rifle)
- [Godot 4 Resource UIDs Documentation](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)
- [SimplePlanes Reference Model](https://www.simpleplanes.com/a/cD8RVZ/Assault-Rifle-with-Cycling-Action)

### Game Project Context
- Engine: Godot 4.3
- Language: C# (primary), GDScript (utilities)
- Type: 2D Top-Down Shooter
- Repository: [Jhon-Crow/godot-topdown-MVP](https://github.com/Jhon-Crow/godot-topdown-MVP)

---

## Appendix: Files Created/Modified

### New Files (First Iteration)
- `docs/case-studies/issue-97/README.md` - This document
- `docs/case-studies/issue-97/references/simpleplanes-reference.md`
- `docs/case-studies/issue-97/references/m16-specifications.md`
- `assets/sprites/weapons/m16_rifle.png` - M16 rifle sprite (80x24 pixels)
- `assets/sprites/weapons/m16_basic.png` - Alternative sprite (64x20 pixels)
- `assets/sprites/weapons/m16_simple.png` - Simple sprite (48x16 pixels)

### New Files (Second Iteration)
- `docs/case-studies/issue-97/logs/game_log_20260121_152404.txt` - User-provided game log

### Modified Files (First Iteration)
- `scenes/weapons/csharp/AssaultRifle.tscn` - Added Sprite2D node for rifle visual
- `Scripts/Weapons/AssaultRifle.cs` - Added sprite rotation following aim direction

### Modified Files (Second Iteration)
- `scenes/weapons/csharp/AssaultRifle.tscn` - **Removed UID from texture reference**
- `scenes/objects/Enemy.tscn` - **Added WeaponSprite node**
- `scripts/objects/enemy.gd` - **Added weapon sprite rotation logic**
