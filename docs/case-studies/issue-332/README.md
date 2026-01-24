# Case Study: Issue #332 - Enemy FOV Logic Improvements

## Issue Summary

Issue #332 "fix логика врагов с полем зрения" (fix enemy FOV logic) requests three distinct improvements to the enemy AI field of view system:

1. **Debug visual mismatch**: The debug visualization doesn't show the actual look direction when an enemy turns their head while standing still
2. **Damage response**: Enemies should turn to face the direction when hit by player bullets (currently no reaction)
3. **Tactical sector coverage**: Multiple enemies should coordinate to cover different sectors (all possible player approach directions)

## Current Codebase Analysis

### 1. FOV Debug Visualization Issue

**Location**: `scripts/objects/enemy.gd:4826-4841`

The current `_draw_fov_cone()` function draws the vision cone using `Vector2.from_angle()` relative to the CharacterBody2D origin:

```gdscript
func _draw_fov_cone(fill_color: Color, edge_color: Color) -> void:
    var half_fov := deg_to_rad(fov_angle / 2.0)
    var cone_length := 400.0
    var left_end := Vector2.from_angle(-half_fov) * cone_length
    var right_end := Vector2.from_angle(half_fov) * cone_length
    # ...
```

**Root Cause**: The cone is drawn at angle 0 (facing right), but the enemy's actual facing direction is determined by `_enemy_model.global_rotation`. When the enemy's head/body rotates (like during idle scanning), the debug cone stays pointing right while the actual FOV follows the model rotation.

**Evidence from codebase**:
- Model rotation is controlled by `_enemy_model.global_rotation` (line 1021-1054)
- Idle scanning smoothly rotates the model to `_idle_scan_targets` angles (line 1031-1033)
- FOV cone drawing doesn't account for model rotation

### 2. Damage Response (Turn When Hit)

**Location**: `scripts/objects/enemy.gd:4140-4208`

The current `on_hit_with_bullet_info()` function:
- Stores hit direction in `_last_hit_direction` (line 4158)
- Shows hit flash effect (line 4166)
- Tracks hits for retreat behavior (line 4161)
- But does **NOT** turn the enemy to face the attacker

```gdscript
func on_hit_with_bullet_info(hit_direction: Vector2, caliber_data: Resource,
                              has_ricocheted: bool, has_penetrated: bool) -> void:
    if not _is_alive:
        return
    hit.emit()
    _last_hit_direction = hit_direction  # Stored but not used for rotation!
    _hits_taken_in_encounter += 1
    _show_hit_flash()
    _current_health -= 1
    # ... no rotation logic
```

**Evidence**: The `_last_hit_direction` is only used for death animation (`_death_animation.start_death_animation(_last_hit_direction)` at line 4369), not for turning toward the attacker.

### 3. Tactical Sector Coverage

**Current state**: Enemies operate independently without coordination on aiming directions. When in IDLE/GUARD mode:
- PATROL mode: Enemies move between patrol points, facing movement direction
- GUARD mode: Enemies use idle scanning to look at detected passages (lines 4070-4123)

The idle scanning system (`_detect_passages_for_scanning()`) finds openings/passages around each enemy and creates scan targets, but:
- Each enemy scans independently
- No coordination between nearby enemies
- No consideration of other enemies' sectors

## Online Research Findings

### Tactical AI Sector Coverage

Research from multiple sources provides solutions for coordinated sector coverage:

#### 1. F.E.A.R.'s Squad AI System
Source: [GDC Vault - Three States and a Plan: The AI of F.E.A.R.](https://gdcvault.com/play/1013282/Three-States-and-a-Plan)

F.E.A.R. uses four key squad behaviors:
- **Get-to-Cover**: Orders soldiers into valid cover while laying suppression fire
- **Advance-Cover**: Move soldiers into cover closer to the player with suppression
- **Orderly-Advance**: Move as orderly file, each soldier covering different side
- **Search**: Separate into groups of two, systematic sweep

Key insight: "Assign behaviors to individuals such as laying suppression fire, moving into position, or following orders. This approach with a central coordinator is easier to implement than just having the soldiers try to collaborate with each other locally."

#### 2. Killzone's Directional Cover System
Source: [Killzone's AI: dynamic procedural combat tactics](http://cse.unl.edu/~choueiry/Documents/straatman_remco_killzone_ai.pdf)

Each waypoint contains visibility data with 24 bytes representing distance to sight-blocking obstacles in different directions. This allows quick testing of cover effectiveness without costly line-of-sight checks.

#### 3. Combat Manager Pattern
Source: [GameDev.net - Enemy Communication](https://www.gamedev.net/forums/topic/704518-enemy-comunication/)

"Creating a combat manager/attacker manager associated with the player creates a list of distinct valid spots for enemies. When an enemy decides to attack, it requests a free space from the manager object and registers itself as the occupant."

**Influence maps** can enforce spacing between agents - see Game AI Pro chapter on "Modular Tactical Influence Maps".

### Damage Response (Turn When Hit)

Source: [Shooter Tutorial - Base Enemy & Hit Reactions](https://kolosdev.com/2025/07/29/shooter-tutorial-base-enemy-hit-reactions-behavior-tree/)

Standard approach:
1. Store attacker's position/direction when damage is received
2. In hit/stunned state, rotate enemy to face that direction
3. Transition to "alert" or "combat" state targeting that attacker

FSM design note: "The enemy can transition to a StunnedState practically from any other state (apart from dead state). That's because it is assumed that players can hit enemies regardless of the state they are in."

### Vision Cone Visualization

Source: [Godot Asset Library - Vision Cone 2D](https://godotengine.org/asset-library/asset/1568)

Existing Godot plugins:
- **Vision Cone 2D** (godot-vision-cone): Configurable vision cone for 2D entities, uses raycast in uniform directions
- **godot-field-of-view**: FOV algorithm implemented in GDScript
- **VisionCone3D**: For 3D projects, has editor gizmo and debug draw

## Proposed Solutions

### Solution 1: Fix FOV Debug Visualization

**Problem**: Cone drawn at fixed angle, doesn't follow model rotation

**Fix**: Modify `_draw_fov_cone()` to account for `_enemy_model.global_rotation`:

```gdscript
func _draw_fov_cone(fill_color: Color, edge_color: Color) -> void:
    var half_fov := deg_to_rad(fov_angle / 2.0)
    var cone_length := 400.0

    # Get the actual facing direction from the enemy model
    var facing_angle := 0.0
    if _enemy_model:
        facing_angle = _enemy_model.global_rotation

    # Draw cone edges relative to facing direction
    var left_end := Vector2.from_angle(facing_angle - half_fov) * cone_length
    var right_end := Vector2.from_angle(facing_angle + half_fov) * cone_length

    # Build polygon points around the facing direction
    var cone_points: PackedVector2Array = [Vector2.ZERO]
    var arc_segments := 16
    for i in range(arc_segments + 1):
        var angle := facing_angle - half_fov + (float(i) / arc_segments) * 2 * half_fov
        cone_points.append(Vector2.from_angle(angle) * cone_length)

    draw_colored_polygon(cone_points, fill_color)
    draw_line(Vector2.ZERO, left_end, edge_color, 2.0)
    draw_line(Vector2.ZERO, right_end, edge_color, 2.0)

    # Draw arc edge
    for i in range(arc_segments):
        var a1 := facing_angle - half_fov + (float(i) / arc_segments) * 2 * half_fov
        var a2 := facing_angle - half_fov + (float(i + 1) / arc_segments) * 2 * half_fov
        draw_line(Vector2.from_angle(a1) * cone_length,
                  Vector2.from_angle(a2) * cone_length, edge_color, 1.5)
```

**Complexity**: Low
**Files affected**: `scripts/objects/enemy.gd` (modify `_draw_fov_cone`)

### Solution 2: Turn Enemy When Hit by Player Bullet

**Problem**: Enemies don't react to damage by turning toward attacker

**Fix**: Modify `on_hit_with_bullet_info()` to trigger rotation toward the attacker:

```gdscript
func on_hit_with_bullet_info(hit_direction: Vector2, caliber_data: Resource,
                              has_ricocheted: bool, has_penetrated: bool) -> void:
    if not _is_alive:
        return

    hit.emit()
    _last_hit_direction = hit_direction
    _hits_taken_in_encounter += 1
    _show_hit_flash()

    # NEW: Turn to face the attacker (opposite of hit direction)
    # Only if we can't already see the player
    if not _can_see_player and _enemy_model:
        var attacker_direction := -hit_direction.normalized()
        _enemy_model.global_rotation = attacker_direction.angle()
        # Update sprite flip
        var aiming_left := absf(_enemy_model.global_rotation) > PI / 2
        if aiming_left:
            _enemy_model.scale = Vector2(enemy_model_scale, -enemy_model_scale)
        else:
            _enemy_model.scale = Vector2(enemy_model_scale, enemy_model_scale)

        # Transition to alert/combat state
        if _current_state == AIState.IDLE:
            _in_alarm_mode = true
            # Could transition to SEARCHING or investigate the direction

    _current_health -= 1
    # ... rest of function
```

**Complexity**: Low-Medium
**Files affected**: `scripts/objects/enemy.gd` (modify `on_hit_with_bullet_info`)

### Solution 3: Tactical Sector Coverage (Multiple Approaches)

This is the most complex requirement. Here are three implementation approaches, from simplest to most sophisticated:

#### Approach 3A: Local Angle Offset (Simple)

Add angle offset based on nearby enemy positions to spread out scan targets:

```gdscript
# In _detect_passages_for_scanning() or new function
func _calculate_tactical_scan_offset() -> float:
    var nearby_enemies := _get_nearby_enemies(200.0)  # 200px radius
    if nearby_enemies.is_empty():
        return 0.0

    # Find sector not covered by others
    var covered_angles: Array[float] = []
    for enemy in nearby_enemies:
        if enemy._enemy_model:
            covered_angles.append(enemy._enemy_model.global_rotation)

    # Find largest gap in coverage
    covered_angles.sort()
    var max_gap := 0.0
    var best_angle := 0.0
    for i in range(covered_angles.size()):
        var next_i := (i + 1) % covered_angles.size()
        var gap := wrapf(covered_angles[next_i] - covered_angles[i], 0, TAU)
        if gap > max_gap:
            max_gap = gap
            best_angle = covered_angles[i] + gap / 2.0

    return best_angle
```

**Pros**: Simple, no central coordinator needed
**Cons**: May cause oscillation as enemies react to each other

#### Approach 3B: Group Coordinator (Medium)

Create a simple coordinator that assigns sectors to enemies:

```gdscript
# New class: EnemySectorCoordinator (could be in autoload or level script)
class_name EnemySectorCoordinator

var _enemy_groups: Dictionary = {}  # position_key -> Array[Enemy]

func register_enemy(enemy: Node2D) -> void:
    var key := _get_position_key(enemy.global_position)
    if key not in _enemy_groups:
        _enemy_groups[key] = []
    _enemy_groups[key].append(enemy)
    _assign_sectors(key)

func _get_position_key(pos: Vector2) -> String:
    # Group enemies within 300px radius
    return "%d_%d" % [int(pos.x / 300), int(pos.y / 300)]

func _assign_sectors(key: String) -> void:
    var enemies: Array = _enemy_groups[key]
    var sector_size := TAU / enemies.size()
    for i in range(enemies.size()):
        var base_angle := sector_size * i
        enemies[i].assigned_sector = base_angle
        enemies[i].sector_width = sector_size
```

Each enemy would then prioritize scanning within their assigned sector.

**Pros**: Fair distribution, no oscillation
**Cons**: Requires new coordinator class, needs enemy registration

#### Approach 3C: Influence Map (Advanced)

Use influence maps to determine threat directions:

```gdscript
# Based on Game AI Pro "Modular Tactical Influence Maps"
# Track player visibility from different directions
# Each enemy contributes to a shared threat direction map
# Enemies face directions with high threat and low friendly coverage

var _threat_map: Dictionary = {}  # angle_bucket -> threat_level

func update_threat_map() -> void:
    _threat_map.clear()

    # Add threat from known/suspected player positions
    if _player and _can_see_player:
        var angle := (_player.global_position - global_position).angle()
        _add_threat_at_angle(angle, 1.0)

    # Add threat from passages/openings
    for passage_angle in _idle_scan_targets:
        _add_threat_at_angle(passage_angle, 0.3)

    # Subtract coverage from nearby friendlies
    for enemy in _get_nearby_enemies(200.0):
        if enemy._enemy_model:
            _subtract_coverage_at_angle(enemy._enemy_model.global_rotation, 0.5)
```

**Pros**: Most realistic, considers multiple factors
**Cons**: Complex, performance overhead

### Recommended Implementation Order

1. **Phase 1 (Quick wins)**:
   - Fix FOV debug visualization (Solution 1)
   - Add damage response rotation (Solution 2)

2. **Phase 2 (Tactical behavior)**:
   - Start with Approach 3A (Local Angle Offset)
   - If oscillation issues arise, upgrade to Approach 3B (Group Coordinator)

3. **Phase 3 (Advanced - optional)**:
   - Consider Approach 3C (Influence Map) for more sophisticated behavior

## Existing Components That Could Help

### From This Codebase

| Component | Location | Potential Use |
|-----------|----------|---------------|
| `_idle_scan_targets` | enemy.gd:206 | Already detects passages, can be extended for sector coverage |
| `_detect_passages_for_scanning()` | enemy.gd:4070 | Raycast-based passage detection |
| `EnemyMemory` | scripts/ai/enemy_memory.gd | Could store friendly positions |
| `SoundPropagation` | scripts/autoload/sound_propagation.gd | Has listener list, could be used for enemy coordination |

### From External Libraries

| Library | Platform | Features |
|---------|----------|----------|
| [Vision Cone 2D](https://godotengine.org/asset-library/asset/1568) | Godot Asset Library | Debug visualization, raycast FOV |
| [godot-vision-cone](https://github.com/d-bucur/godot-vision-cone) | GitHub | Configurable vision cone for stealth games |
| [Modular Tactical Influence Maps](https://www.gameaipro.com) | Game AI Pro book | Sector coverage algorithms |

## Files That Would Need Changes

| File | Changes Required |
|------|-----------------|
| `scripts/objects/enemy.gd` | All three solutions |
| `scripts/autoload/game_manager.gd` | Possibly for group coordinator (Approach 3B) |
| New: `scripts/ai/enemy_sector_coordinator.gd` | Only if using Approach 3B |

## References

### Issue and Related PRs
- [Issue #332](https://github.com/Jhon-Crow/godot-topdown-MVP/issues/332) - Original feature request
- [Issue #306](https://github.com/Jhon-Crow/godot-topdown-MVP/issues/306) - FOV implementation (merged)
- [Issue #66](https://github.com/Jhon-Crow/godot-topdown-MVP/issues/66) - Original FOV request

### Online Resources
- [GDC Vault - Three States and a Plan: The AI of F.E.A.R.](https://gdcvault.com/play/1013282/Three-States-and-a-Plan)
- [Killzone's AI: dynamic procedural combat tactics](http://cse.unl.edu/~choueiry/Documents/straatman_remco_killzone_ai.pdf)
- [GameDev.net - Close Quarters Development: Realistic Combat AI](https://www.gamedev.net/tutorials/programming/artificial-intelligence/close-quarters-development-realistic-combat-ai-part-1-r5156/)
- [Shooter Tutorial - Base Enemy & Hit Reactions](https://kolosdev.com/2025/07/29/shooter-tutorial-base-enemy-hit-reactions-behavior-tree/)
- [Godot Asset Library - Vision Cone 2D](https://godotengine.org/asset-library/asset/1568)
- [GitHub - godot-vision-cone](https://github.com/d-bucur/godot-vision-cone)
- [Game AI Pro - Modular Tactical Influence Maps](https://www.gameaipro.com)

---

**Document Version**: 1.0
**Created**: 2026-01-24
**Created By**: AI Issue Solver (Claude Code)
