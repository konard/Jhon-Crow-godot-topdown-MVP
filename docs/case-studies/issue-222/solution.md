# Issue 222: Solution Implementation

## Date: 2026-01-22

## Solution Summary

Implemented a three-step reload animation for the assault rifle in `player.gd`, following the same pattern used for the existing grenade animation system.

## Changes Made

### 1. Added Reload Animation System

Added to `player.gd`:

#### New Enum
```gdscript
enum ReloadAnimPhase {
    NONE,               # Normal arm positions (weapon held)
    GRAB_MAGAZINE,      # Step 1: Left hand moves to chest to grab new magazine
    INSERT_MAGAZINE,    # Step 2: Left hand brings magazine to weapon, inserts it
    PULL_BOLT,          # Step 3: Character pulls the charging handle
    RETURN_IDLE         # Arms return to normal weapon-holding position
}
```

#### Animation Position Constants
- `RELOAD_ARM_LEFT_GRAB` - Left hand at chest/vest magazine pouch
- `RELOAD_ARM_LEFT_INSERT` - Left hand at weapon magwell
- `RELOAD_ARM_LEFT_SUPPORT` - Left hand on foregrip during bolt pull
- `RELOAD_ARM_RIGHT_BOLT` - Right hand pulls charging handle back

#### Animation Rotation Constants
- `RELOAD_ARM_ROT_LEFT_GRAB` - Arm rotation when grabbing from chest
- `RELOAD_ARM_ROT_LEFT_INSERT` - Left arm rotation when inserting
- `RELOAD_ARM_ROT_RIGHT_BOLT` - Right arm rotation when pulling bolt

#### Duration Constants
- `RELOAD_ANIM_GRAB_DURATION = 0.25s`
- `RELOAD_ANIM_INSERT_DURATION = 0.3s`
- `RELOAD_ANIM_BOLT_DURATION = 0.2s`
- `RELOAD_ANIM_RETURN_DURATION = 0.2s`

### 2. New Functions

- `_start_reload_anim_phase(phase, duration)` - Starts a reload animation phase
- `_update_reload_animation(delta)` - Updates animation each frame with smooth interpolation

### 3. Integration Points

- Modified `_physics_process()` to call `_update_reload_animation(delta)`
- Modified `_physics_process()` to only run walk animation when not in reload animation
- Modified `_handle_sequence_reload_input()` to trigger animation phases:
  - Step 0→1 (R press): Triggers `GRAB_MAGAZINE`
  - Step 1→2 (F press): Triggers `INSERT_MAGAZINE`
  - Step 2→complete (R press): Triggers `PULL_BOLT`
- Modified `_handle_simple_reload_input()` to start animation
- Modified simple reload timer to progress through phases automatically
- Modified `cancel_reload()` to reset animation to `RETURN_IDLE`

## Animation Behavior

### Sequence Reload Mode (R-F-R)
Each key press triggers the corresponding animation phase, synchronized with the existing sound effects:
1. **R press** → Left arm moves to chest to grab magazine (with mag_out sound)
2. **F press** → Left arm moves to weapon, inserts magazine (with mag_in sound)
3. **R press** → Both arms involved in pulling bolt (with m16_bolt sound)

### Simple Reload Mode (press R once)
Animation automatically progresses through all three phases, dividing the `reload_time` into thirds for each phase.

## Technical Notes

- Uses smooth interpolation (`lerp`) for natural-looking transitions
- Arms return to base positions after reload completes
- Walking animation is paused during reload animation
- Animation can be cancelled (arms return to idle)
- Follows the same pattern as the existing grenade animation system for consistency

## Files Modified

- `scripts/characters/player.gd` - Main implementation

## Testing

To test the reload animation:
1. Start the game and deplete some ammunition
2. Press R to initiate reload (observe left arm moving to chest)
3. Press F to insert magazine (observe left arm moving to weapon)
4. Press R to pull bolt (observe right arm pulling back)
5. Arms should return to normal position after reload completes
