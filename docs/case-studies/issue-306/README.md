# Case Study: Issue #306 - Add Realistic Field of View for Enemies

## Issue Summary

Issue #306 requested adding a realistic field of view (FOV) limitation for enemies. The original issue title is in Russian: "добавить реалистичный угол зрения врагам" (add realistic field of view to enemies).

The issue referenced PR #156 which contained a comprehensive FOV implementation that should be analyzed and integrated.

## Timeline of Events

### Development Timeline

**January 24, 2026**

1. **Issue #306 created** - Request to analyze PR #156 branch and integrate working FOV features
2. **Issue comment received** - Request to download logs and data, compile to `./docs/case-studies/issue-306`, perform deep case study analysis, reconstruct timeline, find root causes, and propose solutions

### Referenced Work: PR #156

PR #156 ("Add 100-degree field of view limitation for enemies") contained extensive work on FOV implementation:

- **Initial FOV Implementation** - 100-degree FOV angle check in enemy visibility detection
- **FOV Cone Debug Visualization** - F7 key to show FOV cones
- **Experimental Settings System** - FOV disabled by default, can be enabled in Settings > Experimental
- **Settings Persistence** - Settings saved to user://experimental_settings.cfg
- **Smooth Rotation** - MODEL_ROTATION_SPEED for realistic head/body turning (3.0 rad/s)
- **IDLE Scanning Behavior** - GUARD enemies look at passages every 10 seconds

## Technical Analysis

### Key Features from PR #156

| Feature | Description |
|---------|-------------|
| **100-degree FOV** | Enemies can only see within a 100-degree cone centered on their facing direction |
| **Experimental Setting** | FOV is disabled by default, preserving original 360-degree gameplay |
| **Debug Visualization** | FOV cones visible in debug mode (F7) with color-coded status |
| **Settings Persistence** | FOV preference saved across game sessions |
| **Smooth Rotation** | MODEL_ROTATION_SPEED (3.0 rad/s ~ 172 deg/s) for realistic head turning |
| **IDLE Scanning** | GUARD enemies scan passages/openings every 10 seconds |

### FOV Implementation Details

The FOV check uses a dot product calculation to determine if the target is within the vision cone:

```gdscript
func _is_position_in_fov(target_pos: Vector2) -> bool:
    var experimental_settings: Node = get_node_or_null("/root/ExperimentalSettings")
    var global_fov_enabled := experimental_settings and experimental_settings.has_method("is_fov_enabled") and experimental_settings.is_fov_enabled()
    if not global_fov_enabled or not fov_enabled or fov_angle <= 0.0:
        return true  # FOV disabled - 360 degree vision
    var facing_angle := _enemy_model.global_rotation if _enemy_model else rotation
    var dir_to_target := (target_pos - global_position).normalized()
    var dot := Vector2.from_angle(facing_angle).dot(dir_to_target)
    var angle_to_target := rad_to_deg(acos(clampf(dot, -1.0, 1.0)))
    var in_fov := angle_to_target <= fov_angle / 2.0
    return in_fov
```

### Files to be Modified/Created

| File | Type | Changes |
|------|------|---------|
| `scripts/autoload/experimental_settings.gd` | **NEW** | Global experimental features manager |
| `scripts/ui/experimental_menu.gd` | **NEW** | UI for toggling experimental features |
| `scenes/ui/ExperimentalMenu.tscn` | **NEW** | Experimental settings menu scene |
| `scenes/ui/PauseMenu.tscn` | MODIFY | Add "Experimental" button |
| `scripts/ui/pause_menu.gd` | MODIFY | Handle Experimental menu |
| `scripts/objects/enemy.gd` | MODIFY | FOV checking, smooth rotation, scanning |
| `scripts/components/vision_component.gd` | MODIFY | FOV support in vision component |
| `project.godot` | MODIFY | Register ExperimentalSettings autoload |

## Implementation Plan

### Phase 1: Core Infrastructure
1. Create `experimental_settings.gd` autoload
2. Register autoload in `project.godot`
3. Create `ExperimentalMenu.tscn` and `experimental_menu.gd`

### Phase 2: UI Integration
4. Modify `PauseMenu.tscn` to add Experimental button
5. Modify `pause_menu.gd` to handle Experimental menu

### Phase 3: FOV Logic
6. Add FOV export variables to `enemy.gd`
7. Add FOV checking function to `enemy.gd`
8. Modify `_check_player_visibility()` to include FOV check
9. Add debug FOV cone visualization

### Phase 4: Enhanced Behavior
10. Add smooth rotation with MODEL_ROTATION_SPEED
11. Add IDLE scanning behavior for GUARD enemies
12. Update `vision_component.gd` with FOV support

## How to Use FOV Feature

1. Press **Esc** during gameplay to open Pause Menu
2. Select **Experimental** button
3. Enable **Enemy FOV Limitation** checkbox
4. Resume game - enemies now have 100 degree vision
5. Press **F7** to visualize FOV cones:
   - **Green cone** = FOV active (100 degree vision)
   - **Gray cone** = FOV disabled (360 degree vision)

## References

- [Issue #306](https://github.com/Jhon-Crow/godot-topdown-MVP/issues/306) - Original feature request
- [Pull Request #156](https://github.com/Jhon-Crow/godot-topdown-MVP/pull/156) - Reference implementation
- [Issue #66](https://github.com/Jhon-Crow/godot-topdown-MVP/issues/66) - Related FOV request

---

**Document Version**: 1.0
**Last Updated**: 2026-01-24
**Updated By**: AI Issue Solver (Claude Code)
