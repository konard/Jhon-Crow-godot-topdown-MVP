# Case Study: Issue #84 - Sound Propagation System

## Issue Summary
**Title:** добавить систему распространения звука (Add sound propagation system)
**Repository:** Jhon-Crow/godot-topdown-MVP
**Issue URL:** https://github.com/Jhon-Crow/godot-topdown-MVP/issues/84
**PR URL:** https://github.com/Jhon-Crow/godot-topdown-MVP/pull/113

## Requirements
Original requirements (translated from Russian):
1. Sounds produced by player and enemies (in-game sounds) should propagate realistically
2. System should be extensible
3. Add COMBAT mode transition for all enemies who hear player or enemy gunshots
4. Don't break existing functionality

## Timeline of Events

### Initial Implementation (v1)
- Created `SoundPropagation` autoload singleton
- Implemented basic distance-based sound propagation
- Set gunshot range to 1500 pixels
- Added enemy listener registration and `on_sound_heard` callback
- Enemies transition to COMBAT when hearing gunshots in IDLE state

### User Feedback
User reported: "не работает" (it doesn't work)

Requirements clarification:
1. Sound should propagate approximately viewport size
2. Need physically correct sound modeling (with performance considerations)

### Root Cause Analysis

#### Issue 1: Arbitrary Propagation Distance
The original gunshot range of 1500 pixels was arbitrary and not tied to any game-specific metric. The viewport is 1280x720 pixels with a diagonal of ~1469 pixels.

#### Issue 2: No Physically-Based Attenuation
The original implementation was binary - either a listener heard a sound at full volume or not at all. Real sound follows the **inverse square law** where intensity decreases with distance squared.

#### Issue 3: Potential Timing Issues
The `_register_sound_listener()` was called directly in `_ready()` without ensuring the SoundPropagation autoload was fully initialized.

#### Issue 4: Rigid State Check
Enemies only reacted to sounds when in `AIState.IDLE` state, which was too restrictive for realistic behavior.

## Solution Implementation (v2)

### 1. Viewport-Based Propagation Distance
```gdscript
const VIEWPORT_WIDTH: float = 1280.0
const VIEWPORT_HEIGHT: float = 720.0
const VIEWPORT_DIAGONAL: float = 1468.6  # sqrt(1280^2 + 720^2)

const PROPAGATION_DISTANCES: Dictionary = {
    SoundType.GUNSHOT: 1468.6,      # Approximately viewport diagonal
    SoundType.EXPLOSION: 2200.0,    # 1.5x viewport diagonal
    SoundType.FOOTSTEP: 180.0,      # Very short range
    SoundType.RELOAD: 360.0,        # Short range
    SoundType.IMPACT: 550.0         # Medium range
}
```

### 2. Physically-Based Intensity Calculation
Implemented inverse square law for sound attenuation:

```gdscript
## Reference distance for sound intensity calculations (in pixels).
const REFERENCE_DISTANCE: float = 50.0

## Calculate sound intensity at a given distance using inverse square law.
func calculate_intensity(distance: float) -> float:
    if distance <= REFERENCE_DISTANCE:
        return 1.0

    # Inverse square law: I = I₀ * (r₀/r)²
    var intensity := pow(REFERENCE_DISTANCE / distance, 2.0)
    return clampf(intensity, 0.0, 1.0)
```

Also added atmospheric absorption for more realism:
```gdscript
func calculate_intensity_with_absorption(distance: float, absorption_coefficient: float = 0.001) -> float:
    var base_intensity := calculate_intensity(distance)
    var absorption_factor := exp(-absorption_coefficient * distance)
    return clampf(base_intensity * absorption_factor, 0.0, 1.0)
```

### 3. Deferred Registration
```gdscript
func _register_sound_listener() -> void:
    call_deferred("_deferred_register_sound_listener")

func _deferred_register_sound_listener() -> void:
    var sound_propagation: Node = get_node_or_null("/root/SoundPropagation")
    if sound_propagation and sound_propagation.has_method("register_listener"):
        sound_propagation.register_listener(self)
```

### 4. Intensity-Based Reactions
Added new callback with intensity parameter:
```gdscript
func on_sound_heard_with_intensity(sound_type: int, position: Vector2,
                                   source_type: int, source_node: Node2D,
                                   intensity: float) -> void:
    # React based on current state and intensity
    if _current_state == AIState.IDLE:
        should_react = intensity >= 0.01  # Almost always react
    elif _current_state in [AIState.FLANKING, AIState.RETREATING]:
        should_react = intensity >= 0.3   # Only loud sounds
```

## Physics Background

### Inverse Square Law
Sound intensity decreases with the square of distance from the source. For every doubling of distance, intensity decreases by a factor of 4 (or -6 dB).

Formula: `I = I₀ × (r₀/r)²`

Where:
- `I` = intensity at distance r
- `I₀` = intensity at reference distance r₀
- `r₀` = reference distance (50 pixels in our implementation)
- `r` = actual distance

### Atmospheric Absorption
High-frequency content is absorbed more rapidly over distance. This is modeled with exponential decay:

Formula: `I_absorbed = I × e^(-α × r)`

Where:
- `α` = absorption coefficient (0.001 default)
- `r` = distance

## Test Coverage

Added 10 new unit tests:
1. `test_calculate_intensity_at_reference_distance`
2. `test_calculate_intensity_closer_than_reference`
3. `test_calculate_intensity_at_zero_distance`
4. `test_calculate_intensity_inverse_square_law`
5. `test_calculate_intensity_at_triple_reference`
6. `test_calculate_intensity_at_viewport_distance`
7. `test_calculate_intensity_with_absorption`
8. `test_intensity_decreases_with_distance`
9. `test_emit_sound_passes_intensity_to_listener`
10. `test_emit_sound_respects_min_intensity_threshold`

## Sources and References

### Sound Attenuation and Physics
- [Inverse Square Law for Sound](http://hyperphysics.phy-astr.gsu.edu/hbase/Acoustic/invsqs.html)
- [Sound Propagation - Engineering Toolbox](https://www.engineeringtoolbox.com/inverse-square-law-d_890.html)
- [Inverse Distance Law - Sengpiel Audio](https://sengpielaudio.com/calculator-distancelaw.htm)

### Game Audio Implementation
- [Advanced Distance Attenuation - CRI Middleware](https://blog.criware.com/index.php/2022/06/13/advanced-distance-attenuation/)
- [Inverse Square Law for Sound Falloff - GameDev.net](https://www.gamedev.net/forums/topic/674921-inverse-square-law-for-sound-falloff/)
- [DayZ Weapon Sound System](https://dayz.fandom.com/wiki/Weapon_Sound)

### Academic Research
- [Procedural Synthesis of Gunshot Sounds Based on Physically Motivated Models - ResearchGate](https://www.researchgate.net/publication/315862064_Procedural_Synthesis_of_Gunshot_Sounds_Based_on_Physically_Motivated_Models)
- [GSOUND: Interactive Sound Propagation for Games - UNC Chapel Hill](http://gamma.cs.unc.edu/GSOUND/gsound_aes41st.pdf)

## Lessons Learned

1. **Tie game parameters to meaningful metrics**: Using viewport size as a reference for sound propagation makes the system more intuitive and gameplay-aligned.

2. **Use physically-inspired models**: Even simplified physics models (like inverse square law) provide more realistic and extensible systems than arbitrary values.

3. **Use deferred initialization**: When dealing with autoloads and dependencies, use `call_deferred` to ensure proper initialization order.

4. **Provide intensity information to listeners**: This allows for more nuanced reactions (like only reacting to loud sounds during combat).

5. **Test edge cases**: Include tests for boundary conditions like zero distance, reference distance, and viewport distance.
