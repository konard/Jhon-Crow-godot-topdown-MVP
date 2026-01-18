# Case Study: Issue #114 - Update AI (Player Distraction Attack)

## Issue Summary

**Issue Link:** https://github.com/Jhon-Crow/godot-topdown-MVP/issues/114

**Original Request (Russian):**
> Если игрок в прямой видимости врага и отводит прицел более чем на 23 градуса от направления врага - враг должен атаковать игрока, не важно, в каком состоянии он находится (с высшим приоритетом).
> Впиши это в существующую систему GOAP.
> Не сломай старый функционал в exe.

**Translation:**
> If the player is in direct line of sight of the enemy and turns their aim more than 23 degrees away from the enemy's direction, the enemy should attack the player with the highest priority, regardless of the enemy's current state.
> Integrate this into the existing GOAP system.
> Don't break the old functionality in the exe.

## Problem Analysis

### Root Cause
The original AI system lacked awareness of the player's aiming direction. Enemies would:
- Wait in cover or retreat even when the player wasn't looking at them
- Miss opportunities to attack when the player was distracted (aiming elsewhere)
- Follow standard engagement protocols regardless of player attention

### Key Requirements
1. **Detection:** Enemy must detect when player's aim is >23° away from the enemy
2. **Priority Override:** This should trigger highest-priority attack regardless of current state
3. **GOAP Integration:** The feature must work within the existing GOAP planning system
4. **Backward Compatibility:** Existing behavior must remain intact when player is aiming at enemy

## Solution Implementation

### 1. Player Distraction Detection (`scripts/objects/enemy.gd`)

Added a new function `_is_player_distracted()` that:
- Gets the player's aim direction (from player position to mouse cursor)
- Calculates the angle between player's aim and the direction to the enemy
- Returns `true` if the angle exceeds 23 degrees (0.4014 radians)

```gdscript
## Threshold angle for considering the player "distracted"
const PLAYER_DISTRACTION_ANGLE: float = 0.4014  # 23 degrees in radians

func _is_player_distracted() -> bool:
    # Calculate direction from player to enemy
    var dir_to_enemy = (enemy_pos - player_pos).normalized()

    # Calculate player's aim direction (toward mouse cursor)
    var aim_direction = (global_mouse_pos - player_pos).normalized()

    # Calculate angle between the two directions using dot product
    var dot = dir_to_enemy.dot(aim_direction)
    var angle = acos(clampf(dot, -1.0, 1.0))

    # Player is distracted if angle > 23 degrees
    return angle > PLAYER_DISTRACTION_ANGLE
```

### 2. GOAP World State Update

Added `player_distracted` to the GOAP world state:
- Initialized in `_initialize_goap_state()`
- Updated every frame in `_update_goap_state()`

### 3. New GOAP Action (`scripts/ai/enemy_actions.gd`)

Created `AttackDistractedPlayerAction` with:
- **Preconditions:** `player_visible: true`, `player_distracted: true`
- **Effects:** `player_engaged: true`
- **Cost:** 0.05 (lowest of all actions, ensuring highest priority)

```gdscript
class AttackDistractedPlayerAction extends GOAPAction:
    func _init() -> void:
        super._init("attack_distracted_player", 0.1)
        preconditions = {
            "player_visible": true,
            "player_distracted": true
        }
        effects = {
            "player_engaged": true
        }

    func get_cost(_agent: Node, world_state: Dictionary) -> float:
        if world_state.get("player_distracted", false):
            return 0.05  # Absolute highest priority
        return 100.0
```

### 4. State Machine Priority Override (`scripts/objects/enemy.gd`)

Added highest-priority check in `_process_ai_state()`:
- Checks if player is distracted AND visible at the START of state processing
- Forces transition to COMBAT state, bypassing all other state logic
- Skips normal detection delay to enable immediate attack

```gdscript
func _process_ai_state(delta: float) -> void:
    # HIGHEST PRIORITY: Distracted player attack
    if _goap_world_state.get("player_distracted", false) and _can_see_player:
        if _current_state != AIState.COMBAT:
            _transition_to_combat()
            _detection_delay_elapsed = true  # Skip delay, attack immediately
```

## Testing

### Unit Tests Added (`tests/unit/test_enemy_actions.gd`)

1. **Action Initialization Tests:**
   - `test_attack_distracted_player_action_initialization`
   - `test_attack_distracted_player_action_preconditions`
   - `test_attack_distracted_player_action_effects`

2. **Cost Calculation Tests:**
   - `test_attack_distracted_player_cost_when_distracted`
   - `test_attack_distracted_player_cost_when_not_distracted`

3. **Integration Tests:**
   - `test_distracted_player_attack_has_highest_priority`
   - `test_distracted_player_attack_overrides_other_states`

### Test Coverage
- Verifies action has lowest cost (0.05) when player is distracted
- Confirms GOAP planner selects `attack_distracted_player` over other actions
- Validates priority override even when enemy is under fire or in cover

## Files Modified

| File | Changes |
|------|---------|
| `scripts/objects/enemy.gd` | Added `PLAYER_DISTRACTION_ANGLE` constant, `_is_player_distracted()` function, `player_distracted` GOAP state, priority override in state machine |
| `scripts/ai/enemy_actions.gd` | Added `AttackDistractedPlayerAction` class, updated `create_all_actions()` |
| `tests/unit/test_enemy_actions.gd` | Added 7 new unit tests for the distracted player attack feature |

## Backward Compatibility

The implementation ensures backward compatibility by:
1. Only triggering when BOTH conditions are met (player visible AND aim >23° away)
2. Using the existing COMBAT state instead of creating a new state
3. Following established patterns from other GOAP actions
4. Not modifying any existing action behaviors or costs

## Timeline

1. Issue analysis and requirements gathering
2. Code exploration to understand GOAP system architecture
3. Implementation of `_is_player_distracted()` detection function
4. GOAP world state extension with `player_distracted`
5. Creation of `AttackDistractedPlayerAction` with lowest cost
6. State machine priority override integration
7. Unit test development and documentation

## Conclusion

The solution successfully implements the requested feature by:
- Detecting player distraction using precise angle calculation (23° threshold)
- Integrating seamlessly with the existing GOAP planning system
- Providing highest priority attack behavior regardless of enemy state
- Maintaining full backward compatibility with existing AI behaviors
