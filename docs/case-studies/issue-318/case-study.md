# Case Study: Issue #318 - Enemies Should Not See Actions During Special Last Chance

## Overview

**Issue:** Enemies should not see actions during special last chance - if the player hid from view, enemies should not know where they went, should perceive it as teleportation. After the last chance effect ends, enemies should search for the player at their **last remembered position** (before the teleport), not immediately know where the player moved to.

**Related PR:** PR #316 - Enemy memory system implementation

## Timeline of Events

### 1. Enemy Memory System Added (PR #316)

The enemy memory system was implemented with:
- `EnemyMemory` class (`scripts/ai/enemy_memory.gd`) that tracks:
  - `suspected_position`: Where the enemy thinks the player is
  - `confidence`: How certain the enemy is (0.0-1.0)
  - `last_updated`: When the position was last updated
- Confidence levels:
  - Visual contact: 1.0 (full confidence)
  - Gunshot sound: 0.7
  - Reload/empty click: 0.6
  - Intel from other enemies: source confidence * 0.9
- Confidence thresholds:
  - HIGH (>0.8): Direct pursuit
  - MEDIUM (0.5-0.8): Cautious approach
  - LOW (0.3-0.5): Search mode
  - LOST (<0.05): Return to patrol

### 2. Last Chance Effect Implementation

The "Last Chance" effect (`scripts/autoload/last_chance_effects_manager.gd`):
- Triggers on hard mode when player is at 1 HP and a bullet threatens them
- Freezes time for 6 real seconds (everything except the player)
- Player can move and shoot during the freeze
- All fired bullets are frozen until time unfreezes
- Effect can only trigger once per life

### 3. Initial Fix Attempt (PR #319 v1)

The first fix implemented:
- Added `reset_memory()` method to `enemy.gd`
- Called `_reset_all_enemy_memory()` in `last_chance_effects_manager.gd` when effect ends
- Reset the `_memory` object, `_last_known_player_position`, and `_intel_share_timer`

### 4. Issue Still Present (User Report from Jhon-Crow)

User reported that even with the fix, enemies in PURSUING state still behave as if they know where the player is, going exactly to them after the last chance effect ends.

### 5. Second Round of Analysis (game_log_20260124_212430.txt)

User feedback (translated from Russian):
> "After last chance, enemies should transition to search state and search for the player sequentially, starting from where they remembered the player before the last chance. Currently some enemies remain aggressive and easily find the player."

## Root Cause Analysis (Final)

### The Core Problem

The previous fixes were incomplete. There were **multiple code paths** that allowed enemies to regain knowledge of the player's position almost immediately:

#### Code Path 1: Sound Propagation Bypass
The `on_sound_heard_with_intensity()` function was NOT blocked during the confusion period. This meant:
1. Memory is reset at time T
2. Confusion timer starts (0.5s)
3. Nearby enemy (Enemy7) can still see player after 0.5s
4. Enemy7 shoots at player
5. Gunshot sounds propagate to other enemies (Enemy8, Enemy9, Enemy10)
6. Other enemies receive sound and update their memory (confidence 0.7 for gunshots)
7. With 0.7 confidence (MEDIUM), they immediately transition to PURSUING

From `game_log_20260124_212430.txt`:
```
[21:24:44] [ENEMY] [Enemy8] Memory reset (last chance teleport effect)
[21:24:44] [ENEMY] [Enemy8] Confusion applied for 0.5 seconds
...
[21:24:45] [ENEMY] [Enemy7] Player distracted - priority attack triggered
[21:24:46] [ENEMY] [Enemy8] Memory: high confidence (0.89) - transitioning to PURSUING
[21:24:46] [ENEMY] [Enemy9] Memory: medium confidence (0.80) - transitioning to PURSUING
[21:24:47] [ENEMY] [Enemy10] Memory: medium confidence (0.70) - transitioning to PURSUING
```

#### Code Path 2: Priority Attack Bypass
The "player distracted" priority attack check and the vulnerability attack check did NOT check for confusion timer. This allowed enemies who could see the player to immediately attack.

#### Code Path 3: Complete Memory Reset
The memory was being completely reset (confidence = 0), which caused enemies to:
1. Transition to IDLE
2. Lose all knowledge of where the player WAS
3. Then re-detect the player through normal means

The user wanted enemies to **remember where the player was** and go **search that location**.

### The Actual Desired Behavior

According to the user:
1. **Before last chance**: Enemies remember player's position
2. **After last chance**: Enemies should transition to **SEARCH mode**
3. **In search mode**: Enemies investigate the **OLD remembered position** (where they last saw the player before the teleport)
4. Enemies should NOT immediately know the player's NEW position

## Final Fix Implementation

### Changes Made

1. **Extended confusion duration from 0.5s to 2.0s**
   - Gives player more time to escape and reposition
   - Enemies cannot see or hear anything during this period

2. **Added sound blocking during confusion**
   - `on_sound_heard_with_intensity()` now checks `_memory_reset_confusion_timer`
   - Prevents enemies from rebuilding memory via sound propagation

3. **Preserved old position with LOW confidence**
   - Instead of completely resetting memory, save the old `suspected_position`
   - Set confidence to 0.35 (LOW confidence, between 0.3 and 0.5)
   - This puts enemies in "search mode" - they investigate but don't attack aggressively

4. **Transition to PURSUING (search mode) instead of IDLE**
   - Enemies now transition to PURSUING state
   - PURSUING state uses memory system to navigate to suspected position
   - Enemies will go to where they LAST SAW the player, not the new position

5. **Blocked priority attacks during confusion**
   - "Player distracted" priority attack blocked during confusion
   - Vulnerability priority attack (reload/empty) blocked during confusion

### Code Changes in `enemy.gd`

```gdscript
## Timer for memory reset confusion effect (Issue #318). Blocks visibility and sounds after teleport.
var _memory_reset_confusion_timer: float = 0.0
const MEMORY_RESET_CONFUSION_DURATION: float = 2.0  ## Extended to 2s for better player escape window

## Reset enemy memory for last chance teleport effect (Issue #318).
## Preserves the LAST KNOWN position with LOW confidence so enemies search there.
func reset_memory() -> void:
    # Save the old suspected position BEFORE resetting
    var old_position := Vector2.ZERO
    var had_target := false
    if _memory != null and _memory.has_target():
        old_position = _memory.suspected_position
        had_target = true

    # Reset visibility and detection states
    _can_see_player = false
    _continuous_visibility_timer = 0.0
    _intel_share_timer = 0.0
    _pursuing_vulnerability_sound = false

    # Apply confusion timer - blocks both visibility AND sound reception
    _memory_reset_confusion_timer = MEMORY_RESET_CONFUSION_DURATION

    # If we had a target position, set LOW confidence so enemy searches there
    if had_target and old_position != Vector2.ZERO:
        _memory.suspected_position = old_position
        _memory.confidence = 0.35  # Low confidence - search mode
        _last_known_player_position = old_position
        _transition_to_pursuing()  # Search mode
    else:
        # No previous target - just reset to IDLE
        _memory.reset()
        _last_known_player_position = Vector2.ZERO
        _transition_to_idle()

## Sound handler - block during confusion
func on_sound_heard_with_intensity(...) -> void:
    if _memory_reset_confusion_timer > 0.0:
        return  # Ignore sounds during confusion

## Priority attack - block during confusion
var is_confused: bool = _memory_reset_confusion_timer > 0.0
if is_distraction_enabled and not is_confused and _can_see_player and _player:
    # Priority attack code...
```

## Expected Behavior After Fix

When last chance effect ends:
1. All enemies save their current suspected position
2. Visibility is reset (`_can_see_player = false`)
3. Confusion timer starts (2.0 seconds)
4. During confusion:
   - Enemies cannot see the player
   - Enemies cannot hear sounds
   - Priority attacks are blocked
5. Memory is set to LOW confidence (0.35) with the OLD position
6. Enemies transition to PURSUING (search mode)
7. Enemies navigate to the OLD remembered position
8. After reaching that position and not finding the player:
   - If they can see the player, they transition to COMBAT
   - If not, they transition to patrol/guard behavior (IDLE)

## Test Plan

- [x] Enemy updates memory when player is visible before last chance
- [x] During last chance effect, enemy memory is frozen (no updates)
- [x] When last chance ends, enemy memory is preserved with LOW confidence
- [x] When last chance ends, enemy `_can_see_player` is reset
- [x] When last chance ends, enemies transition to PURSUING (search mode)
- [x] Sounds are blocked during confusion period
- [x] Priority attacks are blocked during confusion period
- [ ] **Requires in-game testing**: Enemies search their OLD remembered position
- [ ] **Requires in-game testing**: Enemies do NOT know player's new position immediately
- [ ] **Requires in-game testing**: Confusion timer (2s) is sufficient for escape

## Files Changed

1. `scripts/objects/enemy.gd`:
   - Extended `MEMORY_RESET_CONFUSION_DURATION` to 2.0 seconds
   - Updated `reset_memory()` to preserve position with LOW confidence
   - Added confusion timer check in `on_sound_heard_with_intensity()`
   - Added confusion timer check in priority attack logic

## Attached Logs

- `game_log_20260124_204620.txt` - First user report showing issue
- `game_log_20260124_205037.txt` - Analysis showing memory reset but immediate re-acquisition
- `game_log_20260124_212430.txt` - Latest user report showing sound propagation bypass
