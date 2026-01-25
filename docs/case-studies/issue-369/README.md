# Case Study: Issue #369 - Update Enemy Search State with Player Position Prediction

## Issue Summary

**Issue Title:** update состояние поиска врагов (update enemy search state)

**Issue Description (translated from Russian):**
> After one observation cycle, enemies should predict where the player is located and conduct a search around that place (each enemy makes their own prediction).

**Related Issues:**
- Issue #322: Add SEARCHING state for methodical enemy search (CLOSED, merged)
- Issue #330: Enemies never return to IDLE after engaging - search infinitely (CLOSED, merged)
- Issue #334: Enemies in SEARCHING state should look into gaps between walls (OPEN)
- Issue #298: Add ability for AI to predict player actions (OPEN)
- Issue #354: Stuck detection for SEARCHING state (CLOSED, merged)

## Current Implementation Analysis

### 1. Enemy AI Architecture

The game uses a hybrid AI system combining:

1. **Finite State Machine (FSM)** - Primary state management via `AIState` enum:
   - `IDLE` - Default patrol or guard behavior
   - `COMBAT` - Actively engaging the player
   - `SEEKING_COVER` - Moving to cover position
   - `IN_COVER` - Taking cover from player fire
   - `FLANKING` - Attempting to flank the player
   - `SUPPRESSED` - Under fire, staying in cover
   - `RETREATING` - Retreating while possibly shooting
   - `PURSUING` - Moving cover-to-cover toward player
   - `ASSAULT` - Coordinated multi-enemy assault (disabled)
   - `SEARCHING` - Methodically searching area where player was last seen

2. **Goal-Oriented Action Planning (GOAP)** - For tactical decision making:
   - Located in `scripts/ai/goap_planner.gd` and `scripts/ai/goap_action.gd`
   - Actions defined in `scripts/ai/enemy_actions.gd`
   - Uses A* search for optimal action sequences
   - Includes memory-based actions: `InvestigateHighConfidenceAction`, `InvestigateMediumConfidenceAction`, `SearchLowConfidenceAction`

3. **Enemy Memory System** - Tracks player position with confidence:
   - Located in `scripts/ai/enemy_memory.gd`
   - Confidence levels: HIGH (>0.8), MEDIUM (0.5-0.8), LOW (0.3-0.5), LOST (<0.05)
   - Sources: Visual (1.0), Gunshot (0.7), Reload/Empty click (0.6)
   - Intel sharing between enemies with 0.9 confidence degradation factor

### 2. Current SEARCHING State Implementation

The SEARCHING state (Issue #322) implements:

```gdscript
# Search State variables (from enemy.gd lines 425-450)
var _search_center: Vector2 = Vector2.ZERO  # Center position for search pattern
var _search_radius: float = 100.0  # Current search radius (expands over time)
const SEARCH_INITIAL_RADIUS: float = 100.0
const SEARCH_RADIUS_EXPANSION: float = 75.0
const SEARCH_MAX_RADIUS: float = 400.0
var _search_waypoints: Array[Vector2] = []  # Waypoints to visit during search
```

**Current Search Pattern:**
- Uses an **expanding square spiral pattern** starting from a fixed center
- Enemies move to waypoints and scan (rotate) at each point
- Zone tracking prevents revisiting same areas
- Expands radius when all waypoints visited
- Maximum 30 seconds search time (unless engaged enemy, then infinite)

**Limitations of Current Implementation:**
1. Search center is fixed (last known position or enemy's current position)
2. Each enemy searches the same area - no individual prediction
3. No consideration of player movement speed/time passed
4. No prediction based on environment (covers, choke points, flank routes)
5. All enemies share the same search pattern

## Problem Statement

The issue requests that enemies should:
1. **Predict** where the player might be after one observation cycle
2. Each enemy should make their **own prediction** (individual, not shared)
3. Conduct search **around the predicted position** rather than the last known position

## Research: Industry Solutions and Patterns

### 1. Occupancy Maps (Third Eye Crime Approach)

**Source:** [Third Eye Crime: Building a Stealth Game Around Occupancy Maps](https://ojs.aaai.org/index.php/AIIDE/article/view/12663) by Damián Isla

**How it works:**
- Uses probability diffusion to represent likelihood of player being in each area
- After line-of-sight breaks, probability spreads to nearby locations
- Probability updates when:
  - Enemy looks at area and doesn't see player (set to 0, rescale rest)
  - Time elapses (distribution becomes more diffuse)
  - Player is spotted (accumulate whole probability at that spot)
- Enemies move to highest probability point

**Applicability:** This is the most sophisticated solution but requires significant implementation effort. Could be simplified for this project.

### 2. Probabilistic Hypothesis System (Issue #298 proposal)

The repo already has a proposed system in Issue #298:
```gdscript
var hypotheses = {
    "flank_left": {"pos": Vector2, "probability": 0.3},
    "flank_right": {"pos": Vector2, "probability": 0.3},
    "cover": {"pos": Vector2, "probability": 0.4}
}
```

This aligns well with the current request.

### 3. Last Known Position + Prediction Radius

**Traditional approach:**
- Store last known position
- Calculate maximum distance player could have traveled: `max_distance = PLAYER_SPEED * time_passed`
- Generate prediction points within this radius based on:
  - Nearby cover positions
  - Escape routes
  - Flank positions

### 4. FEAR-Style GOAP Search Behavior

**Source:** [Building the AI of F.E.A.R. with Goal Oriented Action Planning](https://www.gamedeveloper.com/design/building-the-ai-of-f-e-a-r-with-goal-oriented-action-planning)

F.E.A.R. used GOAP for dynamic planning where:
- Enemies could predict player behavior based on context
- Each enemy independently plans their search route
- Coordination happens through shared world state, not shared plans

### 5. Adaptive Search with Player Behavior Analysis (Metal Gear Solid V)

**Source:** [The Predictable Problem: Why Stealth Game AI Needs an Overhaul](https://www.wayline.io/blog/predictable-problem-stealth-game-ai-overhaul)

- Track player's previous behaviors
- If player frequently flanks, increase probability of checking flanks
- Morale systems affect search aggression

## Proposed Solutions

### Solution 1: Simple Position Prediction (Recommended - Low Complexity)

Add individual position prediction to each enemy:

```gdscript
## Predicted player position (each enemy makes their own prediction)
var _predicted_player_position: Vector2 = Vector2.ZERO
var _prediction_confidence: float = 0.0

## Prediction factors based on environment analysis
func _generate_position_prediction(last_known_pos: Vector2, time_passed: float) -> Vector2:
    var max_distance = PLAYER_SPEED * time_passed

    # Get nearby cover positions
    var covers = _find_nearby_covers(last_known_pos, max_distance)

    # Get flank positions relative to this enemy
    var my_pos = global_position
    var flank_positions = _get_flank_positions(last_known_pos, my_pos)

    # Weight positions by probability
    var candidates = []

    # Covers get higher weight (player likely to use cover)
    for cover in covers:
        candidates.append({
            "pos": cover,
            "weight": 0.4 + randf() * 0.2  # 0.4-0.6 base weight with variance
        })

    # Add flank positions
    for flank in flank_positions:
        if flank.distance_to(last_known_pos) <= max_distance:
            candidates.append({
                "pos": flank,
                "weight": 0.2 + randf() * 0.2  # 0.2-0.4 weight
            })

    # Add last known position (player might stay)
    candidates.append({
        "pos": last_known_pos,
        "weight": 0.1 + randf() * 0.1
    })

    # Select weighted random position (each enemy gets different result)
    return _weighted_random_select(candidates)
```

**Pros:**
- Simple to implement
- Uses existing navigation/cover detection systems
- Each enemy naturally gets different predictions due to randomness and different relative positions

**Cons:**
- No learning from player behavior
- Less sophisticated than occupancy maps

### Solution 2: Probability Hypothesis System (Medium Complexity)

Implement the system proposed in Issue #298:

```gdscript
class_name PlayerHypothesis
extends RefCounted

var hypotheses: Dictionary = {}

func generate_hypotheses(last_known_pos: Vector2, enemy_pos: Vector2, time_passed: float) -> void:
    hypotheses.clear()
    var max_dist = PLAYER_SPEED * time_passed

    # Find nearby covers
    var covers = _find_covers_in_radius(last_known_pos, max_dist)
    var best_cover = _get_best_cover(covers, enemy_pos)
    if best_cover:
        hypotheses["cover"] = {"pos": best_cover, "probability": 0.4}

    # Calculate flank positions
    var left_flank = _calculate_flank(last_known_pos, enemy_pos, -1)
    var right_flank = _calculate_flank(last_known_pos, enemy_pos, 1)

    if _is_reachable(last_known_pos, left_flank, max_dist):
        hypotheses["flank_left"] = {"pos": left_flank, "probability": 0.25}
    if _is_reachable(last_known_pos, right_flank, max_dist):
        hypotheses["flank_right"] = {"pos": right_flank, "probability": 0.25}

    # Stayed in place
    hypotheses["stayed"] = {"pos": last_known_pos, "probability": 0.1}

    # Normalize probabilities
    _normalize_probabilities()

func get_most_probable() -> Dictionary:
    var best = {"pos": Vector2.ZERO, "probability": 0.0}
    for key in hypotheses:
        if hypotheses[key].probability > best.probability:
            best = hypotheses[key]
    return best

func get_random_weighted() -> Dictionary:
    # Returns random hypothesis weighted by probability
    # Ensures each enemy can get different result
    pass
```

**Pros:**
- Structured approach matching Issue #298 proposal
- Extensible for future improvements
- Good balance of complexity and effectiveness

**Cons:**
- Requires new class/file
- More complex than Solution 1

### Solution 3: Simplified Occupancy Map (High Complexity)

Implement a grid-based probability map:

```gdscript
class_name SimpleOccupancyMap
extends RefCounted

var grid_size: float = 50.0
var grid: Dictionary = {}  # key = "x,y", value = probability

func update_from_last_seen(pos: Vector2, confidence: float) -> void:
    _place_probability(pos, confidence)

func diffuse(delta: float, diffusion_rate: float = 0.1) -> void:
    # Spread probability to adjacent cells
    # Decay probability over time
    pass

func update_from_observation(pos: Vector2, can_see: bool) -> void:
    if can_see:
        # Not there - set to 0
        _set_probability(pos, 0.0)
        _renormalize()
    else:
        # Still possible - no change
        pass

func get_highest_probability_position() -> Vector2:
    pass
```

**Pros:**
- Industry-proven technique (Third Eye Crime)
- Most realistic player prediction
- Natural probability decay and diffusion

**Cons:**
- Significant implementation effort
- Memory overhead for grid
- May be overkill for current game scope

## Recommended Implementation

Based on the current codebase architecture and the specific request in Issue #369, I recommend **Solution 1 (Simple Position Prediction)** with elements from **Solution 2 (Hypothesis System)** as a follow-up.

### Implementation Steps:

1. **Add prediction variables to enemy.gd:**
   ```gdscript
   var _predicted_search_center: Vector2 = Vector2.ZERO
   var _prediction_made: bool = false
   ```

2. **Modify `_transition_to_searching()` to use prediction:**
   - Calculate predicted position before starting search
   - Use predicted position as search center instead of last known position

3. **Add prediction function:**
   - Use time since last visual contact
   - Consider nearby covers
   - Consider flank positions relative to this enemy
   - Add randomness for individual predictions

4. **Update `_generate_search_waypoints()` to start from predicted center:**
   - Already uses `_search_center`, just need to set it to predicted position

### Key Files to Modify:
- `scripts/objects/enemy.gd` - Add prediction logic
- `scripts/ai/enemy_memory.gd` - Add last visual contact timestamp

## References

### Academic and Industry Sources:
- [Third Eye Crime: Building a Stealth Game Around Occupancy Maps](https://ojs.aaai.org/index.php/AIIDE/article/view/12663) - AAAI
- [Building the AI of F.E.A.R. with Goal Oriented Action Planning](https://www.gamedeveloper.com/design/building-the-ai-of-f-e-a-r-with-goal-oriented-action-planning) - Game Developer
- [Dynamic Guard Patrol in Stealth Games](https://ojs.aaai.org/index.php/AIIDE/article/download/7425/7308/10903) - AAAI
- [Probabilistic Target-Tracking and Search Using Occupancy Maps](https://www.gameaipro.com/) - AI Game Programming Wisdom 3, 2005
- [Stealthy path planning against dynamic observers](https://dl.acm.org/doi/10.1145/3561975.3562948) - ACM SIGGRAPH
- [The Predictable Problem: Why Stealth Game AI Needs an Overhaul](https://www.wayline.io/blog/predictable-problem-stealth-game-ai-overhaul) - Wayline

### Godot Resources:
- [Enemy AI in Unity](https://gamedevbeginner.com/enemy-ai-in-unity/) - Last known position patterns
- [Godot State Machine Complete Tutorial](https://generalistprogrammer.com/tutorials/godot-state-machine-complete-tutorial-game-ai)
- [Implementing a simple AI for games in Godot](https://robbert.rocks/implementing-a-simple-ai-for-games-in-godot)
- [Making enemies that don't feel completely stupid in Godot](https://toxigon.com/godot-enemy-ai)

### Existing Libraries/Assets:
- [GPGOAP](https://github.com/stolk/GPGOAP) - General Purpose Goal Oriented Action Planning
- [cppGOAP](https://github.com/cpowell/cppGOAP) - C++ GOAP implementation
- [go-goap](https://github.com/jamiecollinson/go-goap) - Go GOAP implementation

## Appendix: Current Codebase Reference

### Key Files:
- `scripts/objects/enemy.gd` - Main enemy AI (large file, ~4600 lines)
- `scripts/ai/enemy_memory.gd` - Memory system with confidence tracking
- `scripts/ai/enemy_actions.gd` - GOAP actions including search-related
- `scripts/ai/goap_planner.gd` - GOAP planning with A* search
- `scripts/ai/states/enemy_state.gd` - Base state class
- `scripts/ai/states/pursuing_state.gd` - Pursuing state implementation
- `scripts/ai/states/idle_state.gd` - Idle state implementation
- `scripts/components/vision_component.gd` - Vision detection system

### Relevant Constants (enemy.gd):
```gdscript
const SEARCH_INITIAL_RADIUS: float = 100.0
const SEARCH_RADIUS_EXPANSION: float = 75.0
const SEARCH_MAX_RADIUS: float = 400.0
const SEARCH_SCAN_DURATION: float = 1.0
const SEARCH_MAX_DURATION: float = 30.0
const SEARCH_WAYPOINT_SPACING: float = 75.0
const SEARCH_ZONE_SNAP_SIZE: float = 50.0
```

### Related Signals:
```gdscript
signal state_changed(new_state: AIState)
```

## Conclusion

Issue #369 requests a significant improvement to the enemy AI search behavior. The current implementation uses a fixed expanding spiral pattern from the last known position. The requested feature would make enemies more intelligent by:

1. Predicting where the player might have moved
2. Having each enemy make independent predictions
3. Searching around predicted positions rather than just the last known position

The recommended approach is to implement Solution 1 (Simple Position Prediction) as it balances implementation complexity with the desired behavior improvement. This can later be enhanced with the full hypothesis system (Solution 2) as described in Issue #298.
