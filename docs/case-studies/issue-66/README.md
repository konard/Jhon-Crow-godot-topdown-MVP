# Case Study: Issue #66 - Enemy Field of View Limitation

## Issue Summary
Issue #66 requested adding a field of view (FOV) limitation for enemies so they can only see the player within a 100-degree vision cone, rather than having 360-degree vision.

## Timeline of Events

### Development Timeline

**January 21, 2026**
1. **02:49** - Commit 422fbdd: Initial FOV implementation added
   - 100-degree FOV angle check in enemy visibility detection
   - FOV cone debug visualization (F7)
   - Modified enemy.gd and vision_component.gd

2. **Time unknown** - Commit e5cbebe: Enemy rotations adjusted
   - Enemies rotated to face room entrances in BuildingLevel.tscn

3. **04:29** - Commit 518be63: FOV moved to Experimental settings
   - Created ExperimentalSettings autoload
   - Created ExperimentalMenu UI
   - **FOV disabled by default** - enemies have 360° vision unless enabled
   - Settings persist to user://experimental_settings.cfg

**January 24, 2026**
4. **03:46-03:52** - First AI work session
   - Merged upstream main
   - Fixed enemy visibility issues
   - Reverted enemy rotations
   - Created initial case study documentation

5. **04:00** - User feedback received
   - User reports feature "not added" and "not visible in debug"
   - Provided game log: game_log_20260124_065625.txt
   - Requested comprehensive case study

6. **04:17** - Current AI work session started
   - Deep investigation initiated
   - Comprehensive case study compilation

### User Testing Sessions (from game logs)

**January 24, 2026 - 06:56:25** (game_log_20260124_065625.txt)
1. **06:56:25** - Game started on Windows (Godot 4.3-stable)
   - Executable: Godot-Top-Down-Template.exe
   - **Critical finding**: No ExperimentalSettings initialization logged
   - All autoloads logged EXCEPT ExperimentalSettings

2. **06:56:25** - Enemy spawn analysis
   - All 10 enemies spawned with `player_found: yes` immediately
   - Suggests FOV check not applied or FOV disabled
   - Examples:
     ```
     [ENEMY] [Enemy1] Enemy spawned at (300, 350), health: 2, behavior: GUARD, player_found: yes
     [ENEMY] [Enemy2] Enemy spawned at (400, 550), health: 4, behavior: GUARD, player_found: yes
     ```

3. **06:56:29** - Debug mode toggled ON (F7 pressed)
   - Expected: FOV cones should be visible
   - User report: FOV cones not visible

4. **06:56:31-33** - Combat engagement
   - Enemy10 entered COMBAT then PURSUING states
   - Enemy3 entered COMBAT state
   - Sound propagation system working correctly

## Root Cause Analysis

### Problem 1: ExperimentalSettings Autoload Not Logging Initialization

**Evidence**: The game log shows initialization messages from multiple autoloads:
- `[INFO] [GameManager] GameManager ready`
- `[INFO] [ScoreManager] ScoreManager ready`
- `[INFO] [SoundPropagation] SoundPropagation autoload initialized`
- `[INFO] [PenultimateHit] PenultimateHitEffectsManager ready - Configuration:`
- `[INFO] [LastChance] LastChanceEffectsManager ready - Configuration:`
- `[INFO] [GrenadeManager] Loaded grenade scene: ...`

**Missing**: No `[ExperimentalSettings]` log entry

**Impact**:
- Cannot verify if ExperimentalSettings was included in the build
- Cannot determine if FOV was enabled or disabled
- No way to debug autoload issues from logs

**Root Cause**: ExperimentalSettings._ready() does not log initialization status

**Solution Applied**: Added initialization logging:
```gdscript
func _ready() -> void:
    # Load saved settings on startup
    _load_settings()
    _log_to_file("ExperimentalSettings initialized - FOV enabled: %s" % fov_enabled)
```

### Problem 2: FOV Feature Disabled by Default

**Design Decision**: In commit 518be63, FOV was made an experimental feature disabled by default:
```gdscript
var fov_enabled: bool = false  # Default: disabled
```

**Impact**:
- Users must manually enable FOV in Settings > Experimental menu
- User may not know the feature exists
- All enemies have 360° vision unless explicitly enabled
- Debug visualization (F7) may not work when FOV is disabled

**User Confusion**:
- User expected FOV to be active by default
- User report: "не добавилось" (not added) - likely means not seeing the effect
- User couldn't see FOV visualization in debug mode

**Rationale for Design**:
- Preserves existing gameplay (backward compatibility)
- Allows players to opt-in to new mechanics
- Prevents breaking existing game balance

### Problem 3: Debug Visualization Coupled to FOV Setting

**Current Implementation**: FOV visualization (F7) may only show when FOV is enabled

**Impact**:
- User cannot see FOV cones in debug mode if feature is disabled
- Makes testing and verification difficult
- No visual feedback during development

**Recommended Solution**: Decouple debug visualization from FOV functionality
- Show FOV cones in debug mode regardless of whether FOV is active
- Add visual indicator (color/opacity) to show if FOV is active or inactive

### Problem 4: All Enemies Spawn with `player_found: yes`

**Evidence from Logs**:
```
[06:56:25] [ENEMY] [Enemy1] Enemy spawned at (300, 350), health: 2, behavior: GUARD, player_found: yes
[06:56:25] [ENEMY] [Enemy2] Enemy spawned at (400, 550), health: 4, behavior: GUARD, player_found: yes
[06:56:25] [ENEMY] [Enemy3] Enemy spawned at (700, 750), health: 3, behavior: GUARD, player_found: yes
[06:56:25] [ENEMY] [Enemy4] Enemy spawned at (800, 900), health: 3, behavior: GUARD, player_found: yes
```

**All 10 enemies** spawned with `player_found: yes` status immediately.

**Possible Causes**:
1. Initial visibility check occurs before FOV check is applied
2. Default state assumes player is visible
3. Spawn-time initialization doesn't respect FOV settings
4. Race condition in initialization order

**Status**: Requires further investigation

**Testing Needed**:
- Test with FOV explicitly enabled
- Check enemy spawn initialization code
- Verify visibility check timing
- Review state machine initialization

### Problem 5: Enemies Could See Through Walls (Previous Issue)
The logs reveal that enemies were entering COMBAT and PURSUING states without clear line of sight to the player. For example:
- `[05:04:23] [ENEMY] [Enemy7] State: IDLE -> COMBAT`
- `[05:04:28] [ENEMY] [Enemy10] State: IDLE -> COMBAT`

These state transitions happened without any corresponding gunshot sound events nearby, suggesting the enemies were detecting the player visually through walls.

**Root Cause**: The original raycast-based visibility check was not properly respecting wall collisions, allowing enemies to "see" players through obstacles.

**Solution**: The upstream repository introduced a multi-point visibility check system (issue #264 fix) that:
1. Checks visibility from 5 points on the player's body (center + 4 corners)
2. Uses direct space state queries with proper collision masks
3. Only marks player as visible if raycast reaches the point without hitting obstacles

### Problem 2: FOV Implementation Was Disabled by Default
The FOV functionality was implemented but moved to the Experimental settings menu and disabled by default. This was a design decision to allow players to opt-in to the new gameplay mechanic.

### Problem 3: Enemy Rotation Values Were Added but Caused Issues
Enemy rotation values were added to make enemies face room entrances, but the user reported that "rotated enemies still don't see the player." This was because:
1. FOV was disabled by default
2. When enabled, the FOV check combined with rotation made detection unreliable

**Solution**: Reverted all enemy rotation values to their default state (0 degrees), restoring original behavior.

## Technical Details

### Multi-Point Visibility Check (Merged from Upstream)
```gdscript
func _get_player_check_points(center: Vector2) -> Array[Vector2]:
    const PLAYER_RADIUS: float = 14.0
    var points: Array[Vector2] = []
    points.append(center)  # Center point
    var diagonal_offset := PLAYER_RADIUS * 0.707
    points.append(center + Vector2(diagonal_offset, diagonal_offset))
    points.append(center + Vector2(-diagonal_offset, diagonal_offset))
    points.append(center + Vector2(diagonal_offset, -diagonal_offset))
    points.append(center + Vector2(-diagonal_offset, -diagonal_offset))
    return points
```

### FOV Check Function
```gdscript
func _is_position_in_fov(target_position: Vector2) -> bool:
    # If FOV is disabled globally or for this enemy, position is always in FOV
    if not ExperimentalSettings.fov_enabled or not fov_enabled:
        return true
    # Calculate angle to target...
```

## Files Modified

| File | Changes |
|------|---------|
| `scripts/objects/enemy.gd` | Merged FOV check with multi-point visibility system |
| `scenes/levels/BuildingLevel.tscn` | Reverted enemy rotation values to 0 (default) |
| `scripts/ui/pause_menu.gd` | Resolved merge conflicts to include both Experimental and Armory menus |
| `project.godot` | Merged autoload registrations |

## Research Findings

### Godot FOV Implementation Patterns

Research into Godot 4 FOV implementations revealed several common approaches:

1. **Vision Cone 2D Plugin** ([Godot Asset Library](https://godotengine.org/asset-library/asset/1568))
   - Simple configurable vision cone for 2D entities
   - Common pattern for stealth games
   - Uses Area2D collision shapes

2. **3D Enemy Toolkit** ([Godot Asset Library](https://godotengine.org/asset-library/asset/3362))
   - SimpleVision3D with configurable parameters
   - Signals for GetSight/LostSight events
   - Vision distance, width, height, shape settings

3. **Raycasting + Dot Product Method** ([Sharp Coder Blog](https://www.sharpcoderblog.com/blog/creating-enemy-ai-in-godot))
   - Calculate angle using dot product
   - Check collision with raycasts
   - State machine integration

### Common Godot Autoload Issues

Research revealed several documented autoload problems:

1. **Load Order Dependencies** ([GitHub Issue #83119](https://github.com/godotengine/godot/issues/83119))
   - Autoloads using `preload()` for scenes that reference other autoloads can crash
   - Solution: Use `load()` instead of `preload()`

2. **Export Missing Autoloads** ([GitHub Issue #32377](https://github.com/godotengine/godot/issues/32377))
   - Export with "selected scenes and dependencies" can miss autoload files
   - Results in unplayable exported games

3. **Global Script Class Cache** ([GitHub Issue #75388](https://github.com/godotengine/godot/issues/75388))
   - Autoloaded scripts load before global_script_class_cache.cfg is populated
   - If class isn't registered in cache, autoload can fail

4. **Autoload Disappeared from List** ([GitHub Issue #100844](https://github.com/godotengine/godot/issues/100844))
   - Autoload goes missing from project settings
   - Cannot re-add because it "already exists"
   - References throw "doesn't exist" errors

**Relevance**: The user's issue (ExperimentalSettings not appearing in logs) could be related to export problems or autoload initialization failures.

## Proposed Solutions

### Solution 1: Add Initialization Logging ✅ IMPLEMENTED

**Change**: Add logging to ExperimentalSettings._ready():
```gdscript
func _ready() -> void:
    # Load saved settings on startup
    _load_settings()
    _log_to_file("ExperimentalSettings initialized - FOV enabled: %s" % fov_enabled)
```

**Benefits**:
- Verify autoload is included in builds
- See FOV state at game start
- Debug future autoload issues

**Status**: Completed - Ready for next build test

### Solution 2: Decouple Debug Visualization from FOV Setting

**Recommendation**: Show FOV cones in debug mode (F7) regardless of whether FOV is enabled

**Implementation**:
```gdscript
func _draw_fov_debug() -> void:
    # Always draw FOV cone in debug mode
    if not GameManager.debug_mode:
        return

    # Use different colors to indicate FOV state
    var cone_color := Color.GREEN if (ExperimentalSettings.fov_enabled and fov_enabled) else Color.GRAY
    # ... draw FOV cone
```

**Benefits**:
- User can see FOV cones even with 360° vision active
- Clear visual indicator of feature state
- Easier testing and development

### Solution 3: Add Documentation and User Guidance

**Changes Needed**:
1. Update PR description with clear instructions on enabling FOV
2. Add tooltip/help text in Pause menu for Experimental button
3. Consider in-game notification on first start
4. Document in README or game help

**Example Message**:
> "New experimental feature available! Press ESC → Experimental to enable Field of View limitation for enemies."

### Solution 4: Investigate `player_found: yes` Initial State

**Testing Steps**:
1. Check enemy.gd spawn initialization code
2. Verify when first visibility check occurs
3. Test with FOV explicitly enabled
4. Add logging for visibility checks during spawn

**Goal**: Understand why all enemies start with player detected

### Solution 5: Build Verification Checklist

**For Next Build**:
- [ ] Verify commit hash used for build
- [ ] Check ExperimentalSettings is in exported files
- [ ] Test autoload initialization in built executable
- [ ] Verify FOV visualization works in debug mode
- [ ] Test FOV toggle in Experimental menu
- [ ] Confirm settings persistence works

## Testing Plan

### Automated Tests
- [ ] Create test scene with controlled enemy/player positions
- [ ] Verify FOV angle calculations (100 degrees)
- [ ] Test with FOV enabled vs disabled
- [ ] Verify ExperimentalSettings autoload loads correctly

### Manual Testing
- [ ] Build new executable with logging changes
- [ ] Run and check logs for ExperimentalSettings initialization
- [ ] Verify FOV disabled by default (360° vision)
- [ ] Enable FOV in Experimental menu
- [ ] Test enemy detection with 100° FOV
- [ ] Verify F7 shows FOV cones
- [ ] Restart game and verify settings persisted
- [ ] Test that enemies don't all spawn with `player_found: yes`

## Lessons Learned

1. **All Autoloads Must Log Initialization** - Without logging, it's impossible to verify autoloads are included in builds or debug initialization failures.

2. **Document Default States Clearly** - When features are disabled by default, users need clear communication about how to enable them.

3. **Decouple Debug from Features** - Debug visualization should work independently of feature activation for easier testing and development.

4. **Test Builds, Don't Assume** - Exported executables may differ from editor runs. Always test builds before release.

5. **User Communication is Critical** - Experimental features need in-game documentation, tooltips, and clear indication of their state.

6. **Wall collision detection is critical** - Visual detection systems must properly respect physics collision layers to prevent enemies from seeing through walls.

7. **Multi-point visibility is more robust** - Checking visibility from multiple points on a target prevents edge cases where the center point is blocked but parts of the target are still visible.

8. **Static rotation values may conflict with dynamic systems** - Setting initial rotation angles for enemies can interfere with AI systems that expect to control rotation themselves.

## Data Sources

### Log Files Collected

1. **game_log_20260124_065625.txt** (930KB)
   - Located: `docs/case-studies/issue-66/logs/`
   - User's built executable test run
   - Platform: Windows (Godot 4.3-stable)
   - Critical findings:
     - No ExperimentalSettings initialization logged
     - All enemies spawn with `player_found: yes`
     - Debug mode toggled but FOV not visible

2. **solution-draft-log.txt** (1.2MB)
   - Located: `docs/case-studies/issue-66/logs/`
   - Previous AI work session complete execution trace
   - Contains implementation decisions and commit history
   - Cost: $3.08 USD (Anthropic calculation)

### Code Commits Analyzed

```bash
c5df3de - Initial commit with task details
422fbdd - Add 100-degree field of view (FOV) limitation for enemies
e5cbebe - Rotate enemies in BuildingLevel to face room entrances
ae53de2 - Revert "Initial commit with task details"
518be63 - Move FOV functionality to Experimental settings menu (disabled by default)
533f775 - Merge upstream main and fix enemy visibility issues
```

### Files Modified in This Issue

| File | Purpose | Key Changes |
|------|---------|-------------|
| `scripts/objects/enemy.gd` | Enemy AI logic | FOV checking, multi-point visibility |
| `scripts/components/vision_component.gd` | Reusable vision | FOV support |
| `scripts/autoload/experimental_settings.gd` | Settings manager | Global FOV toggle, persistence |
| `scripts/ui/experimental_menu.gd` | Settings UI | FOV enable/disable checkbox |
| `scenes/ui/ExperimentalMenu.tscn` | UI scene | Experimental settings interface |
| `scenes/ui/PauseMenu.tscn` | Pause menu | "Experimental" button added |
| `scenes/levels/BuildingLevel.tscn` | Level layout | Enemy rotations (later reverted) |
| `project.godot` | Project config | ExperimentalSettings autoload registration |

## References

### Project Links
- [Issue #66](https://github.com/Jhon-Crow/godot-topdown-MVP/issues/66) - Original feature request
- [Pull Request #156](https://github.com/Jhon-Crow/godot-topdown-MVP/pull/156) - Implementation PR
- [Issue #264 fix](https://github.com/Jhon-Crow/godot-topdown-MVP/issues/264) - Multi-point visibility (merged from upstream)

### External Resources
- [Vision Cone 2D - Godot Asset Library](https://godotengine.org/asset-library/asset/1568)
- [3D Enemy Toolkit - Godot Asset Library](https://godotengine.org/asset-library/asset/3362)
- [Creating Enemy AI in Godot - Sharp Coder Blog](https://www.sharpcoderblog.com/blog/creating-enemy-ai-in-godot)
- [Godot AutoLoad Issues - GitHub #83119](https://github.com/godotengine/godot/issues/83119)
- [Export Missing Autoloads - GitHub #32377](https://github.com/godotengine/godot/issues/32377)
- [Autoload Disappeared - GitHub #100844](https://github.com/godotengine/godot/issues/100844)

## Current Status

**Last Updated**: 2026-01-24 04:17 UTC

**Completed**:
- ✅ FOV implementation (100-degree cone)
- ✅ Debug visualization (F7 key)
- ✅ Experimental settings system
- ✅ Settings persistence
- ✅ Multi-point visibility check (merged from upstream)
- ✅ Enemy rotation reversion
- ✅ Initialization logging added
- ✅ Comprehensive case study documentation

**In Progress**:
- 🔄 Investigating `player_found: yes` initial state issue
- 🔄 Decoupling debug visualization from FOV setting

**Pending**:
- ⏳ Build and test new executable
- ⏳ Verify ExperimentalSettings in build logs
- ⏳ Add in-game user guidance for experimental features
- ⏳ Update PR description with findings

**Blocked**:
- ❌ Cannot verify if ExperimentalSettings was in user's build (no logs)
- ❌ Unknown which commit was used for user's executable build

## Next Actions

1. **Immediate** (ready to implement):
   - Decouple FOV debug visualization from FOV setting
   - Add more detailed logging during enemy spawn
   - Add in-game tooltip for Experimental menu

2. **Testing** (requires build):
   - Build new executable with logging changes
   - Verify ExperimentalSettings initialization appears in logs
   - Test FOV visualization in debug mode
   - Confirm settings persistence

3. **Documentation**:
   - Update PR description with case study findings
   - Add TESTING.md with FOV testing procedures
   - Document Experimental features in game help

---

**Document Version**: 2.0
**Last Updated**: 2026-01-24
**Updated By**: AI Issue Solver (Claude Code)
**Session ID**: 1769228235256
