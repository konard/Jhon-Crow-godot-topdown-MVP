# Case Study: Issue #165 - Penultimate Hit Effect

## Issue Summary

**Issue URL:** https://github.com/Jhon-Crow/godot-topdown-MVP/issues/165
**Pull Request:** https://github.com/Jhon-Crow/godot-topdown-MVP/pull/166
**Date:** 2026-01-21

### Original Requirements (Russian)

> когда в игрока попадают и у него остаётся 1 или менее hp - время замедляется до 0.25 и цвета на экране становится насыщеннее в 3 раза а враги в 4.

### Translated Requirements

When the player is hit and has **1 HP or less** remaining:
- Time slows down to **0.25** (25% speed)
- Screen colors become **3x more saturated**
- Enemy colors become **4x more saturated**

### Additional Requirements (from PR feedback)

User feedback on 2026-01-21T06:47:25Z added:
- "не заметил изменений" (didn't notice any changes)
- "увеличь ещё и контрастность в 2 раза" (also increase contrast by 2x)
- "эффект должен длиться 3 секунды реального времени" (effect should last 3 real seconds)

## Timeline of Events

### Phase 1: Initial Implementation (2026-01-21 ~06:00 UTC)

1. Created `PenultimateHitEffectsManager` autoload singleton
2. Implemented time slowdown via `Engine.time_scale = 0.25`
3. Created saturation shader (`saturation.gdshader`)
4. Added enemy saturation via sprite modulate color manipulation
5. Registered autoload in `project.godot`
6. Added "enemies" group to enemy scenes

### Phase 2: User Testing (2026-01-21 06:47 UTC)

User tested the game and reported:
- **Effect not visible** - User didn't notice any visual changes
- **Missing contrast** - Requested 2x contrast increase
- **Duration too short** - Effect should last 3 real seconds

### Phase 3: Root Cause Analysis (2026-01-21 07:00 UTC)

Investigation revealed multiple issues:

#### Root Cause #1: Shader Parameter Clamping

The saturation shader had a `hint_range(0.0, 1.0)` constraint:

```gdshader
// BEFORE (buggy)
uniform float saturation_boost : hint_range(0.0, 1.0) = 0.0;
```

This clamped the saturation boost to a maximum of 1.0, even though we were setting it to 2.0 for 3x saturation. The effective multiplier was only 2x instead of 3x.

#### Root Cause #2: No Logging

The manager had no logging, making it impossible to verify from game logs whether:
- The player was found
- The signal connection was successful
- The effect was being triggered
- The shader parameters were being applied

#### Root Cause #3: No Contrast Effect

The original requirements didn't include contrast, but user feedback clarified it was needed (2x increase).

#### Root Cause #4: Effect Duration

The original implementation ended the effect immediately when:
- Player health went above 1 HP
- Player died

User clarified the effect should last 3 real seconds (not game time seconds).

## Solution Implementation

### Fix #1: Extended Shader Range

Updated `saturation.gdshader`:

```gdshader
// AFTER (fixed)
uniform float saturation_boost : hint_range(0.0, 10.0) = 0.0;
uniform float contrast_boost : hint_range(0.0, 10.0) = 0.0;
```

### Fix #2: Added Contrast Effect

Added contrast calculation to the shader:

```gdshader
// Apply contrast adjustment
float contrast_factor = 1.0 + contrast_boost;
vec3 contrasted = (saturated - 0.5) * contrast_factor + 0.5;
```

### Fix #3: Real-Time Duration

Changed from instant end to 3-second real-time duration:

```gdscript
const EFFECT_DURATION_REAL_SECONDS: float = 3.0

func _process(_delta: float) -> void:
    if _is_effect_active:
        var current_time := Time.get_ticks_msec() / 1000.0
        var elapsed_real_time := current_time - _effect_start_time
        if elapsed_real_time >= EFFECT_DURATION_REAL_SECONDS:
            _end_penultimate_effect()
```

Using `Time.get_ticks_msec()` ensures the duration is not affected by `Engine.time_scale`.

### Fix #4: Comprehensive Logging

Added logging throughout the manager:

```gdscript
func _log(message: String) -> void:
    var logger: Node = get_node_or_null("/root/Logger")
    if logger and logger.has_method("info"):
        logger.info("[PenultimateHit] " + message)
    else:
        print("[PenultimateHit] " + message)
```

## Final Configuration

| Parameter | Value | Meaning |
|-----------|-------|---------|
| Time Scale | 0.25 | 25% speed (4x slower) |
| Saturation Boost | 2.0 | 3x saturation (1 + 2) |
| Contrast Boost | 1.0 | 2x contrast (1 + 1) |
| Enemy Saturation | 4.0 | 4x saturation multiplier |
| Duration | 3.0 | 3 real seconds |

## Files Changed

1. `scripts/shaders/saturation.gdshader` - Extended range, added contrast
2. `scripts/autoload/penultimate_hit_effects_manager.gd` - Added logging, contrast, real-time duration

## Lessons Learned

1. **Always verify shader parameter ranges** - `hint_range` in Godot shaders clamps values, even when set programmatically
2. **Add logging from the start** - Makes debugging much easier, especially for effects that users can't verbally describe
3. **Clarify duration behavior** - "Effect lasts 3 seconds" can mean game time or real time; always specify
4. **Test with extreme values** - A saturation boost of 2.0 should be visually obvious; if not, something is wrong

## Related Files

- [Game log from user testing](logs/game_log_20260121_093946.txt)
- [Initial solution draft log](logs/solution-draft-log-pr-166.txt)
