# Issue 109: Add Screen Shake Based on Weapon

## Issue Summary

**Original Issue (Russian):**
> добавь тряску экрана при стрельбе игрока.
> тряска экрана должна быть указана для каждого оружия своя. экран должен трястись в направлении, противоположном направлению стрельбы игрока.
> при выпускании каждой пули экран делать одно движение (дальность зависит от скорострельности - чем меньше скорострельность - тем дальше за один выстрел), движения суммируются. возвращение в исходное состояние экрана зависит от разброса (если достигнут максималный разброс - максимальная из указанных скоростей, если минимальный - минимальной, но для всего оружиям минимум 50ms).

**Translation:**
> Add screen shake when the player shoots.
> Screen shake should be specified individually for each weapon. The screen should shake in the direction opposite to the player's shooting direction.
> Each bullet fired should cause one shake movement (distance depends on fire rate - lower fire rate = farther shake per shot), movements accumulate. Return to original screen position depends on spread (if maximum spread is reached - use maximum speed, if minimum spread - minimum speed, but for all weapons minimum 50ms).

## Requirements Analysis

### 1. Per-Weapon Configuration
- Each weapon should have its own screen shake parameters
- Need to add new properties to `WeaponData.cs` resource

### 2. Directional Shake
- Shake direction must be **opposite** to shooting direction
- Example: shooting right causes camera to move left (recoil effect)

### 3. Shake Accumulation
- Each bullet adds one shake movement
- Shake distance per shot depends on fire rate:
  - Lower fire rate = larger shake per bullet
  - Higher fire rate = smaller shake per bullet (but accumulates faster)

### 4. Recovery Speed Based on Spread
- Recovery speed interpolates between min and max based on current spread
- At minimum spread → minimum recovery speed
- At maximum spread → maximum recovery speed
- Global minimum recovery time: 50ms for all weapons

## Technical Design

### Camera Shake System

Based on industry best practices (trauma-based shake from GDC talks), combined with the specific requirements:

#### GDScript Implementation (player.gd)
- Add shake parameters to Camera2D or player script
- Track current shake offset
- Calculate shake per bullet based on fire rate
- Apply shake in opposite direction to shooting
- Smooth recovery based on spread

#### C# Implementation (AssaultRifle.cs)
- Read shake parameters from WeaponData
- Signal to camera when shake should occur
- Camera handles the actual shake effect

### WeaponData Extensions

New properties to add:
```csharp
// Screen shake intensity per shot (pixels)
public float ScreenShakeIntensity { get; set; } = 5.0f;

// Minimum recovery speed (seconds for full recovery at min spread)
public float ScreenShakeMinRecoveryTime { get; set; } = 0.2f;

// Maximum recovery speed (seconds for full recovery at max spread)
public float ScreenShakeMaxRecoveryTime { get; set; } = 0.05f; // 50ms minimum per spec
```

### Shake Formula

For each bullet:
```
shake_distance = base_shake_intensity / fire_rate * fire_rate_factor
shake_direction = -shooting_direction
total_shake += shake_distance * shake_direction
```

Recovery speed calculation:
```
spread_ratio = (current_spread - min_spread) / (max_spread - min_spread)
recovery_time = lerp(min_recovery_time, max_recovery_time, spread_ratio)
recovery_time = max(recovery_time, 0.05)  # 50ms minimum
```

## Implementation Timeline

1. Add screen shake parameters to `WeaponData.cs`
2. Update `AssaultRifleData.tres` with shake values
3. Implement camera shake in GDScript `player.gd`
4. Implement camera shake signal in C# `AssaultRifle.cs`
5. Create camera shake handler for C# version
6. Add unit tests
7. Test and tune parameters

## References

- [Screen Shake :: Godot 4 Recipes](https://kidscancode.org/godot_recipes/4.x/2d/screen_shake/index.html)
- [Camera/Screen Shake for Godot 4 in GDscript](https://gist.github.com/Alkaliii/3d6d920ec3302c0ce26b5ab89b417a4a)
- [Additive 2D Camera Shake - Godot Forum](https://forum.godotengine.org/t/additive-2d-camera-shake-for-overlapping-shakes-in-rapid-succession/108424)
- [GDC Talk: Math for Game Programmers: Juicing Your Cameras With Math](https://www.youtube.com/watch?v=tu-Qe66AvtY)
