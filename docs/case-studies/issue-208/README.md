# Case Study: Issue #208 - Fix Shotgun Reload UI

## Issue Summary
**Issue**: fix ui заряжания дробовика (fix shotgun reloading UI)
**Date**: 2026-01-22
**Repository**: Jhon-Crow/godot-topdown-MVP

## Problem Description
When reloading the shotgun one shell at a time, the ammo counter in the UI should update immediately as each shell is loaded. Instead, the counter was only updating after firing the weapon.

### Expected Behavior
- Player loads shell (shell #1) → Ammo counter shows "1/X"
- Player loads shell (shell #2) → Ammo counter shows "2/X"
- (repeat until tube is full)

### Actual Behavior
- Player loads shell #1 → Counter stays at "0/X"
- Player loads shell #2 → Counter stays at "0/X"
- Player fires → Counter updates to "1/X" (now incorrect since one shell was consumed)

## Root Cause Analysis

### Architecture Overview
The game uses a signal-based communication pattern between weapons and UI:

```
Shotgun.cs (C#) → emits signals → building_level.gd (GDScript) → updates UI labels
```

### Signal Flow

#### During Reload (LoadShell method)
```
LoadShell() called
    ↓
ShellsInTube++
    ↓
EmitSignal(ShellCountChanged, ShellsInTube, TubeMagazineCapacity)
    ↓
❌ NOT CONNECTED TO UI
```

#### During Firing (Fire method)
```
Fire() called
    ↓
ShellsInTube--
    ↓
EmitSignal(AmmoChanged, ShellsInTube, ReserveAmmo)
    ↓
✅ CONNECTED: _on_weapon_ammo_changed()
    ↓
_update_ammo_label_magazine()
```

### The Bug
The `building_level.gd` script connected to the following weapon signals:
- `AmmoChanged` ✅ (connected)
- `MagazinesChanged` ✅ (connected)
- `Fired` ✅ (connected)
- `ShellCountChanged` ❌ (NOT connected)

The `ShellCountChanged` signal is emitted by `Shotgun.cs` every time a shell is loaded (line 567), but the UI wasn't listening to it.

### Key Files Involved
1. **Scripts/Weapons/Shotgun.cs** - Shotgun weapon implementation
   - `LoadShell()` method (line 534-569) - emits `ShellCountChanged`
   - `Fire()` method (line 612-684) - emits `AmmoChanged`

2. **scripts/levels/building_level.gd** - Level UI controller
   - `_setup_player_tracking()` (line 168-238) - signal connections
   - `_on_weapon_ammo_changed()` (line 403-409) - updates ammo label

## Solution

### Implementation
Added connection to `ShellCountChanged` signal in `_setup_player_tracking()`:

```gdscript
# Connect to ShellCountChanged for shotgun - updates ammo UI during shell-by-shell reload
if weapon.has_signal("ShellCountChanged"):
    weapon.ShellCountChanged.connect(_on_shell_count_changed)
```

Created new handler function:

```gdscript
## Called when shotgun shell count changes (during shell-by-shell reload).
## This allows the ammo counter to update immediately as each shell is loaded.
func _on_shell_count_changed(shell_count: int, capacity: int) -> void:
    # Get the reserve ammo from the weapon for display
    var reserve_ammo: int = 0
    if _player:
        var weapon = _player.get_node_or_null("Shotgun")
        if weapon != null and weapon.get("ReserveAmmo") != null:
            reserve_ammo = weapon.ReserveAmmo
    _update_ammo_label_magazine(shell_count, reserve_ammo)
```

### Design Decisions
1. **Reuse existing `_update_ammo_label_magazine()` function** - Maintains consistency with how ammo is displayed across different scenarios
2. **Fetch `ReserveAmmo` from weapon** - The `ShellCountChanged` signal only passes shell count and capacity, so we need to retrieve reserve ammo separately
3. **Check for shotgun weapon specifically** - The signal is shotgun-specific (tube magazine loading), so we only look for the Shotgun node

### Files Changed
- `scripts/levels/building_level.gd`
  - Added signal connection (line 202-204)
  - Added handler function (line 419-429)

## Testing
The fix was verified by:
1. Code review confirming signal is now connected
2. Handler function properly fetches reserve ammo and updates the ammo label
3. The same `_update_ammo_label_magazine()` function is used, ensuring consistent display format and color coding

## Prevention
To prevent similar issues in the future:
1. When adding new signals to weapons, ensure corresponding UI connections are created
2. Document all weapon signals and their purposes in code comments
3. Consider adding integration tests that verify UI updates for all weapon states

## Timeline
- **Issue Reported**: Issue #208 opened
- **Root Cause Identified**: Missing signal connection between `ShellCountChanged` and UI
- **Fix Implemented**: Connected signal and added handler function
- **PR Created**: #209

## Related Code References
- `Scripts/Weapons/Shotgun.cs:567` - ShellCountChanged signal emission during reload
- `scripts/levels/building_level.gd:203` - Signal connection (after fix)
- `scripts/levels/building_level.gd:421` - Handler function (after fix)
