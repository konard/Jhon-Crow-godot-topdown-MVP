# Case Study: Issue #167 - Special "Last Chance" Effect Not Working on Hard Difficulty

## Summary

The special "last chance" time-freeze effect for hard difficulty was not triggering when the player had 1 HP or less. Instead, the regular penultimate hit effect was being used in all cases.

## Root Cause

The bug was caused by **GDScript-C# interoperability issues** when trying to access the C# `HealthComponent.CurrentHealth` property from GDScript.

### Technical Details

In `last_chance_effects_manager.gd`, the `_get_player_health()` function attempted to read the player's current health from the C# `HealthComponent`:

```gdscript
var health_component: Node = _player.get_node_or_null("HealthComponent")
if health_component != null:
    if health_component.has_method("get") and health_component.get("CurrentHealth") != null:
        return health_component.get("CurrentHealth")
    if "CurrentHealth" in health_component:
        return health_component.CurrentHealth
```

However, this always returned `0.0` because:
1. The `get("CurrentHealth")` method doesn't work correctly for C# properties exposed to GDScript
2. The direct property access `health_component.CurrentHealth` also failed silently

### Evidence from Logs

From `game_log_20260121_105319.txt`:
```
[10:53:27] [INFO] [LastChance] Threat detected: @Area2D@538
[10:53:27] [INFO] [LastChance] Player health is 0.0 - effect requires exactly 1 HP or less but alive
[10:53:27] [INFO] [LastChance] Cannot trigger effect - conditions not met
[10:53:27] [INFO] [PenultimateHit] Player damaged: 1.0 damage, current health: 3.0
```

The log shows:
- `LastChanceEffectsManager` read player health as `0.0` (incorrect)
- `PenultimateHitEffectsManager` correctly received health as `3.0` from the `Damaged` signal

When player reached 1 HP:
```
[10:53:31] [INFO] [PenultimateHit] Player damaged: 1.0 damage, current health: 1.0
[10:53:31] [INFO] [PenultimateHit] Triggering penultimate hit effect (HP: 1.0)
...
[10:53:31] [INFO] [LastChance] Threat detected: @Area2D@818
[10:53:31] [INFO] [LastChance] Player health is 0.0 - effect requires exactly 1 HP or less but alive
```

The `LastChanceEffectsManager` still read `0.0` instead of `1.0`.

## Working Solution (penultimate_hit_effects_manager.gd)

The `penultimate_hit_effects_manager.gd` works correctly because it **caches the health from the signal parameters**:

```gdscript
func _on_player_damaged(amount: float, current_health: float) -> void:
    _log("Player damaged: %.1f damage, current health: %.1f" % [amount, current_health])
    _check_penultimate_state(current_health)  # Uses the signal parameter directly
```

The C# `Damaged` signal emits: `EmitSignal(SignalName.Damaged, actualDamage, CurrentHealth);`

## Fix Applied

Modified `last_chance_effects_manager.gd` to:

1. **Added a cached health variable:**
   ```gdscript
   var _player_current_health: float = 0.0
   ```

2. **Cache health from signals instead of querying the component:**
   ```gdscript
   func _on_player_damaged(_amount: float, current_health: float) -> void:
       _player_current_health = current_health
       _log("Player health updated (C# Damaged): %.1f" % _player_current_health)
   ```

3. **Connected to HealthComponent.HealthChanged signal for initial value:**
   ```gdscript
   if health_component != null and health_component.has_signal("HealthChanged"):
       health_component.HealthChanged.connect(_on_health_changed)
   ```

4. **Use cached value in `_can_trigger_effect()`:**
   ```gdscript
   if _player_current_health > 1.0 or _player_current_health <= 0.0:
       _log("Player health is %.1f - effect requires..." % _player_current_health)
       return false
   ```

## Timeline of Events

1. Player starts game on hard difficulty with full health (4 HP)
2. Health updates are received via `HealthChanged`/`Damaged` signals but were NOT being cached
3. Player takes damage, health decreases to 1 HP
4. Enemy bullet enters threat sphere
5. `_can_trigger_effect()` is called
6. `_get_player_health()` tries to read from HealthComponent - returns 0.0 (BUG)
7. Condition `current_health <= 0.0` is true (incorrectly), effect doesn't trigger
8. Regular penultimate effect triggers instead

## Lesson Learned

When working with C#/GDScript interoperability in Godot:
- **Prefer signal parameters over direct property access** for cross-language communication
- **Cache values from signals** when they need to be accessed later
- Direct property access from GDScript to C# nodes may fail silently and return default values

## Files Changed

- `scripts/autoload/last_chance_effects_manager.gd`

## Follow-up Issue: Player Cannot Move During Time Freeze

### Symptom

After the initial fix for health detection, the time-freeze effect triggered correctly, but the player was unable to move or aim during the 6-second freeze period.

### Root Cause

The initial implementation used `Engine.time_scale = 0` to freeze time, with `PROCESS_MODE_ALWAYS` set on the player to allow processing. However, this approach has a critical flaw:

**When `Engine.time_scale = 0`, the physics delta becomes 0.** This affects:
1. `_PhysicsProcess(delta)` receives `delta = 0`
2. `ApplyMovement()` multiplies velocity by delta, resulting in no movement
3. `MoveAndSlide()` doesn't move the character when physics delta is 0

Even though the player node had `PROCESS_MODE_ALWAYS`, the physics system effectively stopped working.

### Evidence from Logs

From `logs-batch4/game_log_20260121_112817.txt`:
```
[11:28:39] [INFO] [LastChance] Triggering last chance effect!
[11:28:39] [INFO] [LastChance] Starting last chance effect:
[11:28:39] [INFO] [LastChance]   - Time will be frozen (except player)
[11:28:39] [INFO] [LastChance]   - Duration: 6.0 real seconds
[11:28:39] [INFO] [LastChance] Player and all children process_mode set to ALWAYS
...
[11:28:45] [INFO] [LastChance] Effect duration expired after 6.00 real seconds
```

The effect lasted exactly 6 seconds as intended, but the player reported they couldn't move during this time.

### Solution

Instead of using `Engine.time_scale = 0`, we now:

1. **Keep `Engine.time_scale` at 1.0** - Physics delta remains normal
2. **Disable processing on all scene nodes** except the player
3. **Skip autoloads** (AudioManager, FileLogger, etc.)
4. **Skip the player and all its children** - They process normally

```gdscript
func _freeze_time() -> void:
    # CRITICAL: Do NOT set Engine.time_scale to 0!
    # Physics delta becomes 0 which makes MoveAndSlide() not work.

    # Freeze all top-level nodes except player and autoloads
    var root := get_tree().root
    for child in root.get_children():
        if child.name in ["FileLogger", "AudioManager", ...]:
            continue  # Skip autoloads
        _freeze_node_except_player(child)
```

### Files Changed

- `scripts/autoload/last_chance_effects_manager.gd` - Replaced `Engine.time_scale = 0` with node-based freezing

## Testing Instructions

1. Start the game on **Hard** difficulty
2. Take damage until you have **1 HP**
3. Wait for an enemy bullet to fly toward you
4. **Expected:** Blue sepia time-freeze effect should trigger
5. **Expected:** Player should be able to MOVE and AIM during the freeze
6. **Expected:** All enemies and bullets should be completely frozen
7. **Expected logs should show:**
   ```
   [LastChance] Player health updated (C# Damaged): 1.0
   [LastChance] Threat detected: Bullet
   [LastChance] Triggering last chance effect!
   [LastChance] Starting last chance effect:
   [LastChance] Froze all nodes except player and autoloads
   ```
