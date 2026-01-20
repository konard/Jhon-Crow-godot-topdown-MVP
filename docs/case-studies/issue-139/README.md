# Case Study: Issue #139 - Tutorial Level Implementation

## Overview

**Issue:** [#139 - добавь обучение на Test tier (C#)](https://github.com/Jhon-Crow/godot-topdown-MVP/issues/139)
**Pull Request:** [#142](https://github.com/Jhon-Crow/godot-topdown-MVP/pull/142)
**Date Created:** 2026-01-20
**Status:** In Progress (Follow-up after initial solution draft)

## Timeline of Events

### Phase 1: Initial Issue Creation (2026-01-20T18:17:02Z)

User @Jhon-Crow created issue #139 with the following requirements:

1. Rename "Test tier (C#)" to "Обучение" (Training/Tutorial)
2. Remove control hints from the screen (they shouldn't be visible on any level)
3. Tutorial flow:
   - Player approaches targets
   - Player shoots targets
   - Player reloads
   - Completion message appears with Q restart hint
4. Key prompts should float near the player until the action is completed

### Phase 2: Initial AI Solution Draft (2026-01-20T18:32:48Z)

The AI solver (Claude) created an initial solution draft that:

- Created `tutorial_level.gd` script with tutorial state machine
- Renamed the level menu entry
- Added floating prompts that follow the player
- Added target hit detection
- Added completion message

**Cost:**
- Public pricing estimate: $4.148673 USD
- Calculated by Anthropic: $2.490313 USD (40% lower)

### Phase 3: User Feedback (2026-01-20T18:38:09Z)

User @Jhon-Crow tested the compiled exe and reported the following issues:

1. **"на других уровнях не должно быть подсказок управления"** (Control hints shouldn't be on other levels)
   - TestTier.tscn and BuildingLevel.tscn still had InstructionsLabel showing WASD controls

2. **"на учебном уровне должно быть отображение кол-ва патронов"** (Tutorial level should show ammo count)
   - The tutorial level was missing the AmmoLabel UI element

3. **"prompt на учебной карте не появляется"** (Prompt on tutorial map doesn't appear)
   - The floating tutorial prompts weren't visible in the compiled executable

4. **"я использую собранные exe"** (I'm using compiled exe)
   - This indicated the issue was specific to exported/compiled builds, not the editor

## Root Cause Analysis

### Issue 1: Control Hints on Other Levels

**Root Cause:** The initial implementation focused only on the tutorial level, leaving the InstructionsLabel nodes in:
- `scenes/levels/TestTier.tscn` (lines 1344-1352)
- `scenes/levels/BuildingLevel.tscn` (lines 938-946)

Additionally, the GDScript files `test_tier.gd` and `building_level.gd` contained code that updated these labels:
```gdscript
var instructions_label := get_node_or_null("CanvasLayer/UI/InstructionsLabel")
if instructions_label:
    instructions_label.text = "WASD - Move | LMB - Shoot..."
```

**Fix Applied:**
1. Removed InstructionsLabel nodes from both scene files
2. Removed the label update code from both GDScript files

### Issue 2: Missing Ammo Count on Tutorial Level

**Root Cause:** The tutorial level scene (`scenes/levels/csharp/TestTier.tscn`) was created without copying the AmmoLabel from the main TestTier scene. The tutorial_level.gd script also lacked the ammo tracking functionality present in test_tier.gd.

**Fix Applied:**
1. Added AmmoLabel node to `scenes/levels/csharp/TestTier.tscn`
2. Added ammo tracking variables and functions to `tutorial_level.gd`:
   - `_ammo_label` reference
   - `_setup_ammo_tracking()` function
   - `_on_weapon_ammo_changed()` callback
   - `_on_player_ammo_changed()` callback
   - `_update_ammo_label()` and `_update_ammo_label_magazine()` functions

### Issue 3: Tutorial Prompts Not Appearing in Compiled Exe

**Root Cause:** The original `_update_prompt_position()` function used an unreliable method to calculate screen position:

```gdscript
# Original problematic code
var camera := get_viewport().get_camera_2d()
if camera:
    var screen_pos := _player.global_position - camera.global_position + get_viewport().size / 2.0
    _prompt_label.position = screen_pos + Vector2(-_prompt_label.size.x / 2, -80)
```

This approach had several problems in exported builds:
1. `get_viewport().size` returns the actual window size, which may differ from the designed resolution
2. The camera position calculation assumes a specific viewport setup
3. `_prompt_label.size.x` might be zero before the label is properly sized

**Fix Applied:**
```gdscript
# Fixed code using canvas transform
var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
var screen_pos: Vector2 = canvas_transform * _player.global_position
_prompt_label.custom_minimum_size = Vector2(300, 30)
_prompt_label.position = screen_pos + Vector2(-150, -80)
```

The canvas transform method works correctly because:
1. It accounts for camera position, zoom, and any other canvas transformations
2. It works consistently in both editor and exported builds
3. Using `custom_minimum_size` ensures the label has a known width for centering

## Technical Insights

### Godot Engine: Editor vs Export Differences

When testing Godot games, there are significant differences between running in the editor and running exported builds:

1. **Viewport Size:** The editor window size is dynamic, while exports can have fixed resolution settings
2. **Camera Transform:** The editor preview may apply different camera settings
3. **Debug Output:** `print()` statements don't show in exported builds by default
4. **Resource Loading:** Some resource paths may resolve differently

### Best Practices for Godot UI Positioning

For UI elements that need to follow world objects:

1. **Use Canvas Transform:** `get_viewport().get_canvas_transform() * world_position` reliably converts world to screen coordinates
2. **Set Minimum Sizes:** Always set `custom_minimum_size` for dynamically created labels to ensure consistent sizing
3. **Add Error Logging:** Use `push_error()` instead of `print()` for important warnings that should appear in export logs

### C# vs GDScript Signal Compatibility

The tutorial level needed to support both C# (PascalCase signals) and GDScript (snake_case signals):

```gdscript
# C# signals
if _player.has_signal("ReloadCompleted"):
    _player.ReloadCompleted.connect(_on_player_reload_completed)
# GDScript signals
elif _player.has_signal("reload_completed"):
    _player.reload_completed.connect(_on_player_reload_completed)
```

## Files Modified in Fix

1. `scenes/levels/TestTier.tscn` - Removed InstructionsLabel node
2. `scenes/levels/BuildingLevel.tscn` - Removed InstructionsLabel node
3. `scripts/levels/test_tier.gd` - Removed InstructionsLabel update code
4. `scripts/levels/building_level.gd` - Removed InstructionsLabel update code
5. `scenes/levels/csharp/TestTier.tscn` - Added AmmoLabel node
6. `scripts/levels/tutorial_level.gd` - Added ammo tracking and fixed prompt positioning

## Lessons Learned

1. **Test in Export Builds:** Always test gameplay features in exported builds, not just the editor
2. **Complete Feature Implementation:** When adding a new level, ensure all UI elements from reference levels are included
3. **Use Robust Positioning:** For UI that follows world objects, use canvas transforms instead of manual calculations
4. **Check All Affected Files:** When removing a feature, search all files to ensure no references remain

## Related Files

- [solution-draft-log.txt](./solution-draft-log.txt) - Complete AI execution trace
- [issue-data.json](./issue-data.json) - Original issue data
- [pr-data.json](./pr-data.json) - Pull request metadata
- [pr-comments.json](./pr-comments.json) - PR discussion comments
