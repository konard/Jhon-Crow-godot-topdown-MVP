# Case Study: Enemy Grenade Throw on Suspicion (Issue #379)

## Issue Summary

**Issue**: [#379 - враг бросает гранату по подозрению](https://github.com/Jhon-Crow/godot-topdown-MVP/issues/379)

**Title Translation**: "Enemy throws grenade on suspicion"

**Original Description (Russian)**:
> если враг сильно подозревает, что где то находится игрок - должен бросить туда гранату и штурмовать.

**English Translation**:
> If the enemy strongly suspects that the player is somewhere - they should throw a grenade there and assault.

## Problem Statement

The game currently has a grenade throwing system with 6 trigger conditions (implemented in PR #364), but none of them account for **suspicion-based behavior**. The enemy memory system tracks a `suspected_position` with a `confidence` level (0.0-1.0), but this information is not currently used to trigger grenade throws.

The request is to add a **7th trigger condition**: when an enemy has **high confidence** (strong suspicion) about the player's location but cannot visually confirm it, they should throw a grenade to that suspected position and then assault.

## Existing System Analysis

### Current Grenade Trigger Conditions (6 triggers)

1. **Trigger 1 - Suppression Hidden**: Player suppressed enemy/allies, then hid for 6+ seconds
2. **Trigger 2 - Pursuit Defense**: Enemy under fire AND player approaching at ≥50 px/sec
3. **Trigger 3 - Witness Kills**: Enemy witnessed 2+ player kills within 30 seconds
4. **Trigger 4 - Sound-Based**: Heard reload/empty click sound, can't see player
5. **Trigger 5 - Sustained Fire**: 10 seconds of gunshots within 1/6 viewport zone
6. **Trigger 6 - Desperation**: Enemy health ≤ 1 HP

### Enemy Memory System

**File**: `scripts/ai/enemy_memory.gd`

Key properties:
- `suspected_position: Vector2` - The suspected player location
- `confidence: float` (0.0-1.0) - Certainty about the position

Confidence sources:
- Direct visual contact: 1.0
- Sound (gunshot): 0.7
- Sound (reload/empty click): 0.6
- Information from other enemies: source_confidence × 0.9

Confidence thresholds:
- HIGH: ≥ 0.8 (direct pursuit behavior)
- MEDIUM: 0.5-0.8 (cautious approach)
- LOW: 0.3-0.5 (search/patrol)
- LOST: < 0.05 (target lost)

### Gap Analysis

The issue requests triggering a grenade when confidence is **high** (0.8+) but player is **not visible**. This scenario is not currently covered by any existing trigger:

| Scenario | Player Visible | Covered By |
|----------|----------------|------------|
| High confidence, visible | Yes | Normal combat (no grenade needed) |
| High confidence, not visible | **No** | **NOT COVERED - Issue #379** |
| Medium confidence, not visible | No | Partially by T1, T4, T5 |
| Sound-based position | No | Trigger 4 |
| After suppression | No | Trigger 1 |

## Proposed Solution: Trigger 7 - Suspicion-Based

### Trigger Condition

**When**: Enemy has high confidence (≥0.8) about suspected position AND cannot see player AND has not been able to see player for X seconds

**Action**: Throw grenade to suspected position, then transition to ASSAULT state

### Implementation Design

```gdscript
## Constants for Trigger 7
const GRENADE_SUSPICION_CONFIDENCE_THRESHOLD: float = 0.8
const GRENADE_SUSPICION_HIDDEN_TIME: float = 3.0  # Seconds player must be hidden

## State variables for Trigger 7
var _high_suspicion_hidden_timer: float = 0.0

## Update Trigger 7: High suspicion but player hidden
func _update_trigger_suspicion_hidden(delta: float) -> void:
    if _memory == null:
        return

    # Check if we have high confidence but can't see player
    if _memory.is_high_confidence() and not _can_see_player:
        _high_suspicion_hidden_timer += delta
    else:
        _high_suspicion_hidden_timer = 0.0

## Check Trigger 7: High suspicion + player hidden for threshold time
func _should_trigger_suspicion_grenade() -> bool:
    if _memory == null or not _memory.has_target():
        return false

    # Must have high confidence
    if not _memory.is_high_confidence():
        return false

    # Must not be able to see player
    if _can_see_player:
        return false

    # Player must have been hidden for threshold time
    return _high_suspicion_hidden_timer >= GRENADE_SUSPICION_HIDDEN_TIME
```

### Target Position

The grenade should be thrown at `_memory.suspected_position`.

### Post-Throw Behavior: Assault

After throwing the grenade, the enemy should transition to **ASSAULT** state to follow up. This creates the "flush and assault" tactical behavior requested.

### Integration Points

1. Add `_update_trigger_suspicion_hidden(delta)` call in `_update_grenade_triggers()`
2. Add `_should_trigger_suspicion_grenade()` check
3. Add `trigger_7_suspicion` to GOAP world state
4. Update `_get_grenade_target_position()` to include Trigger 7
5. Implement state transition to ASSAULT after throw (optional but recommended)

## Research Sources

See [research-sources.md](./research-sources.md) for detailed external references.

### Key Insights from Industry

1. **F.E.A.R. AI Principle**: "if the player is hiding, they'll be offensive and try to flush him out" using grenades
2. **Stealth Game AI Pattern**: High suspicion states transition from "investigation" to "attack" when confidence threshold is met
3. **GOAP Integration**: Each enemy independently evaluates trigger conditions, creating emergent tactical coordination

## Priority and Cost

Suggested GOAP cost: **0.35** (between Trigger 2: Pursuit at 0.3 and Trigger 3: Witness Kills at 0.4)

Rationale: This trigger represents active hunting behavior based on strong suspicion, which should have moderate priority - more urgent than reactive triggers but less than desperate situations.

## Files to Modify

1. `scripts/objects/enemy.gd` - Add Trigger 7 implementation
2. `scripts/ai/enemy_actions.gd` (optional) - Add GOAP action for suspicion grenade

## Test Scenarios

1. **Basic Test**: Let enemy see player, then hide. Wait for grenade throw when confidence is high.
2. **Decay Test**: Let enemy see player, hide for longer than confidence decay time. Grenade should NOT be thrown.
3. **Confidence Source Test**: Make sound near enemy (gunshot = 0.7 confidence). Should NOT trigger (below threshold).
4. **Assault Follow-up Test**: Verify enemy transitions to ASSAULT state after throwing grenade.
5. **Cooldown Test**: Verify grenade cooldown applies after suspicion-based throw.

## Related PRs and Issues

- PR #364: Enemy grenade throwing system implementation
- PR #376: Prevent enemy self-damage from grenade throws
- Issue #363: Original grenade system request

---

*Case study created: 2026-01-25*
