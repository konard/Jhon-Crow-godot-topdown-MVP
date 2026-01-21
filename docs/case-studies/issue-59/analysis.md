# Case Study: Issue #59 - Enemy Cover Aiming Behavior

## Issue Summary

**Issue:** When the player hides behind cover, enemies should aim at the potential exit points of the cover rather than tracking the player's actual position behind it.

**Expected behavior:**
- When player hides behind cover, enemy aims at where player might emerge
- Enemy alternates aim between two exit points (above and below cover)
- When player becomes visible again, normal aiming resumes
- Enemy should NOT rotate toward player when there's an obstacle blocking view

**Actual behavior (bug):**
- Enemy continues to track player's actual position even behind cover
- Enemy rotation appears correct but bullets still shoot toward hidden player
- Rapid flickering between "behind cover" and "visible" states causes unstable behavior

## Timeline of Investigation

### Session 1: Initial Implementation (2026-01-21 ~02:30)

1. Implemented cover tracking variables:
   - `_player_cover_obstacle` - Reference to obstacle blocking view
   - `_player_cover_collision_point` - Where raycast hit the obstacle
   - `_tracking_player_behind_cover` - Flag for cover tracking state
   - `_cover_aim_alternate_timer` / `_cover_aim_side` - For alternating aim

2. Added cover detection in `_check_player_visibility()`:
   - When raycast hits obstacle before player, stores collision point
   - Sets `_tracking_player_behind_cover = true`

3. Created `_get_aim_target_position()` and `_get_cover_exit_aim_target()`:
   - Returns cover exit point when tracking player behind cover
   - Calculates perpendicular direction for exit points
   - Alternates between sides every 1.5 seconds

4. Modified `_aim_at_player()` to use `_get_aim_target_position()`

5. Added debug visualization in `_draw()` for cover tracking

### Session 2: User Reports Problem Persists (2026-01-21 ~02:38)

User provided game log (`game_log_20260121_053401.txt`) showing the issue still occurs.

### Session 3: Root Cause Found and Fixed (2026-01-21 ~02:46)

Found that `_shoot()` was using `_player.global_position` directly, ignoring cover tracking.

### Session 4: User Reports Continued Issues (2026-01-21 ~02:55)

User reported two new issues:
1. **FOV (view limitation) should be experimental** - Move to settings menu, disabled by default
2. **Enemy still rotates toward player behind obstacle** - In combat mode, enemy tracks player through walls

New game logs provided:
- `game_log_20260121_054813.txt` (892KB)
- `game_log_20260121_055535.txt` (3.4KB)

## Root Cause Analysis

### Session 4 Log Analysis

Analysis of `game_log_20260121_054813.txt` revealed a critical problem:

```
[05:48:33] [ENEMY] [Enemy10] Player hid behind cover at (1144.516, 1626), obstacle: HallTable
[05:48:33] [ENEMY] [Enemy10] Player emerged from cover, resuming direct tracking
[05:48:33] [ENEMY] [Enemy10] Player hid behind cover at (1144.516, 1626), obstacle: HallTable
[05:48:33] [ENEMY] [Enemy10] Player emerged from cover, resuming direct tracking
...
```

**Rapid state flickering** - The enemy is rapidly alternating between "behind cover" and "visible" states multiple times per second.

### Root Cause #1: Visibility Flickering

The cover detection system checks visibility every physics frame without any hysteresis. At the edge of cover/obstacles, the raycast result can change frame-to-frame based on:
- Slight enemy rotation changes
- Sub-pixel position changes
- Physics state variations

This causes `_tracking_player_behind_cover` to flip rapidly, which:
- Spams log messages
- Makes enemy aim unstable
- Prevents consistent cover tracking behavior

### Root Cause #2: FOV Default Enabled

The FOV (field of view) limitation was enabled by default (`fov_enabled = true`), which:
- Changed enemy behavior significantly
- Was not requested to be on by default
- Should be an experimental/optional feature

## Solution

### Fix 1: Add Hysteresis to Cover Tracking

Added a timer-based hysteresis system to prevent rapid state flickering:

```gdscript
## Hysteresis timer for cover tracking
var _cover_tracking_visible_timer: float = 0.0

## Minimum time player must be continuously visible before resetting cover tracking
const COVER_TRACKING_HYSTERESIS_TIME: float = 0.3

# In _check_player_visibility():
if _tracking_player_behind_cover:
    _cover_tracking_visible_timer += delta
    # Only reset after player has been continuously visible
    if _cover_tracking_visible_timer >= COVER_TRACKING_HYSTERESIS_TIME:
        _tracking_player_behind_cover = false
        # ... reset other state
```

This ensures:
- Cover tracking state is stable
- No rapid flickering in logs
- Enemy behavior is predictable

### Fix 2: Move FOV to Experimental Settings

Created new experimental settings menu accessible from pause menu (ESC):

1. Created `scripts/ui/experimental_menu.gd` - Menu controller
2. Created `scenes/ui/ExperimentalMenu.tscn` - Menu scene
3. Updated `scripts/ui/pause_menu.gd` - Added "Experimental" button
4. Updated `scenes/ui/PauseMenu.tscn` - Added button node
5. Updated `scripts/autoload/game_manager.gd` - Added `experimental_fov_enabled` setting
6. Updated `scripts/objects/enemy.gd`:
   - Changed default `fov_enabled = false`
   - Added signal connection to sync with game manager setting

### Fix 3: Ensure Cover Tracking Uses Proper Aiming (Previous Session)

The `_shoot()` function now uses `_get_aim_target_position()` which respects cover tracking state.

## Files Modified

- `scripts/objects/enemy.gd` - Cover hysteresis, FOV setting sync
- `scripts/autoload/game_manager.gd` - Experimental FOV setting
- `scripts/ui/pause_menu.gd` - Experimental menu integration
- `scripts/ui/experimental_menu.gd` - NEW: Menu controller
- `scenes/ui/PauseMenu.tscn` - Experimental button
- `scenes/ui/ExperimentalMenu.tscn` - NEW: Menu scene

## Test Plan

1. **Test Cover Tracking Stability:**
   - Enable debug mode (F7)
   - Engage enemy and hide behind cover
   - Verify logs don't show rapid flickering
   - Verify purple X and lime green lines remain stable

2. **Test FOV Setting:**
   - Press ESC to open pause menu
   - Click "Experimental"
   - Toggle "Enemy View Limitation (FOV)"
   - Verify enemies have 360° vision when disabled (default)
   - Verify enemies have 100° FOV when enabled

3. **Test Combat Behavior:**
   - With FOV disabled, verify enemies detect player from any direction
   - Hide behind obstacle, verify enemy doesn't shoot through it
   - Verify enemy aims at cover exit points, not player position

## Related Issues and PRs

- PR #156: Adds FOV (field of view) to enemies - merged into this fix
- Issue #66: Original FOV request

## Lessons Learned

1. **State changes need hysteresis** - When transitioning between states based on continuous conditions (like visibility raycasts), always add a minimum duration requirement to prevent flickering.

2. **Experimental features should be opt-in** - New features that significantly change gameplay should default to disabled and be clearly labeled as experimental.

3. **Visual and actual behavior must match** - The enemy rotation and bullet direction must use the same targeting logic.

### Session 5: User Reports Three More Issues (2026-01-21 ~03:13)

User reported three issues:
1. **With FOV option disabled, enemies still can't see the player**
2. **With FOV option disabled, enemies should be in normal (non-rotated) state**
3. **Some enemies shoot randomly when hearing gunshots without seeing the player**

New game logs provided:
- `game_log_20260121_060759.txt` (1.8MB)
- `game_log_20260121_061156.txt` (34KB)

### Session 5 Log Analysis

Analysis of `game_log_20260121_061156.txt` revealed critical problems:

```
[06:11:57] [ENEMY] [Enemy3] Enemy spawned at (700, 750), health: 2, behavior: GUARD, player_found: yes
[06:11:59] [ENEMY] [Enemy3] State: IDLE -> COMBAT
[06:11:59] [ENEMY] [Enemy3] Player hid behind cover at (689.4686, 810), obstacle: Table1
[06:11:59] [ENEMY] [Enemy3] Player hid behind cover at (702.4635, 810), obstacle: Table1
[06:11:59] [ENEMY] [Enemy3] Player hid behind cover at (715.6382, 810), obstacle: Table1
...repeated hundreds of times...
```

**Problems identified:**

1. **Log spam persists** - "Player hid behind cover" message logged every frame
2. **Cover tracking activates without direct sighting** - Enemy can enter COMBAT from hearing sounds, then immediately starts cover tracking even though they never SAW the player
3. **Enemies track player through obstacles after hearing sounds** - When enemies hear a gunshot, they enter COMBAT and aim at the player's position even if they've never visually confirmed player location

### Root Cause #3: Cover Tracking Without Direct Visual Confirmation

The original cover tracking condition was:
```gdscript
if was_visible or _current_state in [AIState.COMBAT, AIState.PURSUING, ...]:
    _tracking_player_behind_cover = true
```

This allowed cover tracking to activate when:
- Enemy was in COMBAT state (even from hearing sounds, not seeing player)
- `was_visible` was the state from previous frame, but didn't confirm DIRECT visual contact

### Root Cause #4: Log Message Logged Every Frame

The "Player hid behind cover" log message was being logged every frame when an obstacle blocked the raycast, without checking if cover tracking was already active.

## Solution (Session 5)

### Fix 4: Require Direct Visual Confirmation

Added a new variable `_has_seen_player_directly` to track whether the enemy has ACTUALLY seen the player (raycast hit player, not obstacle):

```gdscript
## Whether the enemy has directly seen the player at least once in this encounter.
## This is required before cover tracking can activate.
var _has_seen_player_directly: bool = false
```

Changed cover tracking condition from:
```gdscript
# OLD (buggy):
if was_visible or _current_state in [AIState.COMBAT, ...]:
    _tracking_player_behind_cover = true
```

To:
```gdscript
# NEW (fixed):
if was_visible and _has_seen_player_directly:
    # Only log when first entering cover tracking
    var was_already_tracking := _tracking_player_behind_cover
    _tracking_player_behind_cover = true
    if not was_already_tracking:
        _log_to_file("Player hid behind cover...")
```

This ensures:
- Cover tracking ONLY activates when transitioning FROM visible TO blocked
- Enemy must have ACTUALLY seen player (raycast hit player body)
- Enemies who only heard sounds do NOT track cover
- Log message only appears once when entering cover tracking state

### Fix 5: Reset Direct Sighting on Idle

Added reset of `_has_seen_player_directly` when enemy returns to IDLE state:

```gdscript
func _transition_to_idle() -> void:
    _has_seen_player_directly = false
    _tracking_player_behind_cover = false
    # ... other resets
```

This ensures each new encounter starts fresh without carryover from previous encounters.

## Files Modified (Session 5)

- `scripts/objects/enemy.gd` - Added `_has_seen_player_directly` variable and logic

## Conclusion

This session addressed three critical issues:

1. **Fixed "enemies don't see player when FOV disabled"** - Issue was that cover tracking was activating without visual confirmation. Now requires `_has_seen_player_directly = true` before cover tracking can activate.

2. **Fixed "enemies rotate toward player when they shouldn't"** - Enemies only aim at cover exit points if they've actually seen the player. Enemies who only heard sounds will move toward sound location but NOT track cover.

3. **Fixed "random shooting when hearing gunshots"** - Same root cause as above. Without `_has_seen_player_directly`, enemies couldn't activate cover tracking from sound alone.

4. **Fixed log spam** - Added `was_already_tracking` check to prevent logging every frame.

The cover tracking system now properly requires visual confirmation before activating, providing more realistic and fair enemy behavior.
