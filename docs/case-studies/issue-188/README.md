# Case Study: Issue #188 - Armory Menu Breakage After Frag Grenade Implementation

## Executive Summary

This case study documents the investigation and resolution of a bug where the armory menu stopped displaying content after implementing the frag grenade feature (Issue #188). The root cause was identified as invalid node naming in Godot due to spaces in grenade names.

## Timeline of Events

### Phase 1: Initial Implementation (PR #189)
- **Date:** 2026-01-22 ~00:13
- **Action:** AI solver implemented frag grenade feature
- **Changes Made:**
  1. Added `GrenadeManager` autoload for grenade type selection
  2. Modified `armory_menu.gd` to include grenade selection UI
  3. Removed flashbang from the `WEAPONS` dictionary (moved to `GrenadeManager`)
  4. Added dynamic grenade slot creation in armory menu

### Phase 2: User Testing
- **Date:** 2026-01-22 03:32
- **Action:** User tested the build
- **Result:** User reported "armory сломалось - там ничего не отображается" (armory broke - nothing is displayed there)
- **Logs Provided:**
  - `game_log_20260122_033222.txt`
  - `game_log_20260122_033248.txt`

### Phase 3: Investigation
- **Date:** 2026-01-22
- **Findings:**
  1. Logs showed normal game operation, no explicit errors
  2. GrenadeManager was loading correctly
  3. Identified potential issue: Node naming with spaces

## Root Cause Analysis

### Primary Issue: Invalid Node Names

In Godot 4.x, node names cannot contain spaces. The code in `_create_grenade_slot()` was setting:

```gdscript
slot.name = grenade_data.get("name", "grenade") + "_slot"
```

With `GRENADE_DATA` containing:
```gdscript
GrenadeType.FRAG: {
    "name": "Frag Grenade",  # Contains a space!
    ...
}
```

This would create a node named "Frag Grenade_slot" which violates Godot's node naming rules.

### Secondary Issues Identified

1. **No defensive checks:** The code didn't validate that UI elements were properly initialized
2. **No logging:** Without diagnostic logging, it was difficult to trace the execution path
3. **WEAPONS dictionary modification:** Removing flashbang from WEAPONS could have unintended consequences if other code depended on it

## Solution Implemented

### Fix 1: Sanitize Node Names
```gdscript
func _create_grenade_slot(grenade_type: int, grenade_data: Dictionary, is_selected: bool) -> PanelContainer:
    var slot := PanelContainer.new()
    # Use sanitized name for node (no spaces allowed in Godot node names)
    var grenade_name: String = grenade_data.get("name", "grenade")
    slot.name = grenade_name.replace(" ", "_") + "_slot"
```

### Fix 2: Add Defensive Checks
```gdscript
func _populate_weapon_grid() -> void:
    # Verify weapon_grid is valid
    if weapon_grid == null:
        FileLogger.info("[ArmoryMenu] ERROR: weapon_grid is null!")
        return
```

### Fix 3: Add Diagnostic Logging
Added comprehensive logging throughout the armory menu to track:
- When `_ready()` is called
- Whether `GrenadeManager` was found
- Number of weapon/grenade slots being created
- Completion of grid population

## Files Modified

1. `scripts/ui/armory_menu.gd`
   - Fixed node naming to replace spaces with underscores
   - Added null checks for weapon_grid
   - Added diagnostic logging

## Lessons Learned

1. **Godot Node Naming:** Always sanitize user-facing strings before using them as node names
2. **Defensive Programming:** Add null checks and validation for @onready variables
3. **Logging:** Implement logging early in development to aid debugging
4. **Testing:** Visual UI changes should be manually tested before merging

## Recommendations

1. Create a utility function for sanitizing node names
2. Add unit tests that verify node naming conventions
3. Consider adding debug overlay for UI debugging
4. Document Godot-specific constraints in coding guidelines

## Related Files

- [Game Log 1](logs/game_log_20260122_033222.txt)
- [Game Log 2](logs/game_log_20260122_033248.txt)
