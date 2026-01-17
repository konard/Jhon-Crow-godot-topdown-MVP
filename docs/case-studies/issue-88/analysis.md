# Issue 88: Enemy AI Combat State Fix - Case Study Analysis

## Issue Summary
The enemy AI has behavior issues in COMBAT and PURSUING states where enemies stand still instead of properly executing their intended behaviors.

## Reported Problems

### Problem 1: PURSUING State - Enemies Just Stand Still
**Symptom**: In PURSUING state, enemies stand still and the countdown timer doesn't progress.

**Root Cause Analysis**:
Looking at `_process_pursuing_state()` (lines 1222-1311 in enemy.gd):

The issue was:
1. When entering PURSUING state, `_has_valid_cover` might be true (from previous state)
2. But `_has_pursuit_cover` is false
3. This means the enemy waits at current cover position
4. **When `_find_pursuit_cover_toward_player()` fails to find valid cover** (no cover closer to player), the code just returned without any fallback
5. The enemy got stuck in the waiting loop forever

**Solution Implemented**:
1. Reduced `PURSUIT_COVER_WAIT_DURATION` from 2.5s to 1.5s (within 1-2s range as requested)
2. Added fallback behavior when no pursuit cover is found:
   - If player is visible → transition to COMBAT
   - If flanking is enabled → transition to FLANKING
   - Otherwise → transition to COMBAT for direct approach

### Problem 2: COMBAT State - Timer Running but Enemies Not Moving
**Symptom**: In COMBAT state, if enemies are not in direct contact with the player, the timer just constantly runs while they stand still.

**Root Cause Analysis**:
The original `_process_combat_state()` had:
```gdscript
# In combat, enemy stands still and shoots (no velocity)
velocity = Vector2.ZERO
```

The issue:
1. Enemy enters COMBAT state
2. Enemy immediately stands still and starts the shooting timer
3. If enemy is far from player, they just stand and shoot without moving
4. No approach phase to get into direct contact

**Expected Behavior** (from owner's feedback):
- In COMBAT state, enemies should **come out for direct contact** with the player
- **Move toward the player first**, THEN shoot
- After the timer expires, go back to cover if still in COMBAT state

**Solution Implemented**:
1. Added new combat phase: **APPROACH**
   - New variables: `_combat_approaching`, `_combat_approach_timer`
   - New constants: `COMBAT_APPROACH_MAX_TIME` (2.0s), `COMBAT_DIRECT_CONTACT_DISTANCE` (250px)

2. Combat now has two phases:
   - **Approach Phase**: Enemy moves toward player while shooting
     - Ends when: within direct contact distance OR approach time exceeded
   - **Exposed Phase**: Enemy stands still and shoots for 2-3 seconds
     - Then returns to cover via SEEKING_COVER state

3. Updated debug labels to show current phase:
   - `COMBAT (APPROACH)` - moving toward player
   - `COMBAT (EXPOSED 2.5s)` - standing and shooting

## Implementation Details

### Files Modified
- `scripts/objects/enemy.gd`

### New Variables Added
```gdscript
## Whether the enemy is in the "approaching player" phase of combat.
var _combat_approaching: bool = false

## Timer for the approach phase of combat.
var _combat_approach_timer: float = 0.0

## Maximum time to spend approaching player before starting to shoot (seconds).
const COMBAT_APPROACH_MAX_TIME: float = 2.0

## Distance at which enemy is considered "close enough" to start shooting phase.
const COMBAT_DIRECT_CONTACT_DISTANCE: float = 250.0
```

### Constants Changed
```gdscript
## Duration to wait at each cover during pursuit (1-2 seconds, reduced for faster pursuit).
const PURSUIT_COVER_WAIT_DURATION: float = 1.5  # Was 2.5
```

### Functions Modified
1. `_process_combat_state()` - Complete rewrite to add approach phase
2. `_process_pursuing_state()` - Added fallback when no cover is found
3. `_update_debug_label()` - Added phase info for COMBAT and PURSUING states
4. `_transition_to_combat()` - Reset new combat variables
5. `_reset()` - Reset new combat variables

## Testing Notes
- Enable debug mode (F7) to see AI state labels above enemies
- Test single enemy: should approach player then shoot for 2-3s
- Test PURSUING state: should wait 1.5s at cover, then move or fallback
- Test combat cycling: approach → exposed → return to cover
- Verify existing behaviors (RETREATING, SUPPRESSED, FLANKING) still work

## References
- enemy.gd lines 740-852 (COMBAT state processing)
- enemy.gd lines 1222-1311 (PURSUING state processing)
- enemy.gd lines 2588-2604 (debug label updates)
- Issue comment from owner detailing expected behavior
