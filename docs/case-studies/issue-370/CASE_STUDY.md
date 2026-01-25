# Case Study: Issue #370 - Blood Puddles Should Be Unlimited

## Issue Summary

**Issue URL:** https://github.com/Jhon-Crow/godot-topdown-MVP/issues/370

**Problem Description (Russian):**
> сейчас при добавлении новых луж исчезают старые, такого быть не должно

**English Translation:**
> Currently when adding new blood puddles, old ones disappear, this should not happen.

**Issue Title (Russian):**
> количество луж крови должно быть неограниченно

**English Translation:**
> The number of blood puddles should be unlimited.

## Timeline of Events

### Initial Implementation (Issue #149)
**Commit:** 736d21c - "Improve visual impact effects realism and add blood decals"
- Blood decals system first introduced
- Initial implementation with `MAX_BLOOD_DECALS` limit

### Issue #257 - Blood Splatters Enhancement
**Commit:** f7e837e - "Add blood splatters on floor and walls when hit (issue #257)"
- Enhanced blood effects with wall splatters
- Still maintained the `MAX_BLOOD_DECALS` limit

### Issue #293 - Round 3: Unlimited Decals Feature
**Commit:** e370e52 (2026-01-XX) - "Round 3 blood effect improvements: edge scaling, no overlap, matte drops, unlimited decals"

**Key Changes:**
```gdscript
// Changed from:
const MAX_BLOOD_DECALS: int = 500

// To:
## Maximum number of blood decals before oldest ones are removed.
## Set to 0 for unlimited decals (puddles should never disappear per issue #293).
const MAX_BLOOD_DECALS: int = 0
```

**Cleanup Logic Modified:**
```gdscript
// Before:
while _blood_decals.size() > MAX_BLOOD_DECALS:
    var oldest := _blood_decals.pop_front() as Node2D
    if oldest and is_instance_valid(oldest):
        oldest.queue_free()

// After:
# Remove oldest decals if limit exceeded (0 = unlimited, no cleanup)
if MAX_BLOOD_DECALS > 0:
    while _blood_decals.size() > MAX_BLOOD_DECALS:
        var oldest := _blood_decals.pop_front() as Node2D
        if oldest and is_instance_valid(oldest):
            oldest.queue_free()
```

**Test Added:**
```gdscript
func test_max_blood_decals_is_unlimited() -> void:
    # MAX_BLOOD_DECALS should be 0 for unlimited decals (per issue #293 Round 3)
    # Puddles should never disappear
    assert_eq(impact_manager.MAX_BLOOD_DECALS, 0,
        "MAX_BLOOD_DECALS should be 0 for unlimited decals")
```

**Status:** Feature successfully implemented - blood puddles set to unlimited.

### Issue #360 - Bloody Footprints Feature (REGRESSION INTRODUCED)
**Commit:** 2797dc1 (2026-01-25 02:35:20) - "feat: add bloody footprints feature (Issue #360)"

**Problem:** While implementing bloody footprints (which needed to be unlimited), the commit inadvertently **reverted** the blood puddles limit back to 100:

```gdscript
// Accidentally changed from:
const MAX_BLOOD_DECALS: int = 0  // unlimited

// Back to:
const MAX_BLOOD_DECALS: int = 100  // limited!
```

**Why This Happened:**
The commit message for Issue #360 states: "Footprints have no maximum limit (per requirements)" referring to footprints, but the developer forgot that blood puddles were ALSO supposed to be unlimited (from Issue #293). The change to `MAX_BLOOD_DECALS = 100` was likely copied from an older version of the file or based on an outdated template.

**Impact:**
- Blood puddles now disappear after 100 decals are spawned
- The cleanup logic still has the conditional check (`if MAX_BLOOD_DECALS > 0`), but now it's activated again
- The unit test `test_max_blood_decals_is_unlimited()` from Issue #293 would now fail

### Issue #370 - Current Issue (Regression Detected)
**Reported:** 2026-01-25

User reports that old blood puddles disappear when new ones are added - exactly the regression introduced by commit 2797dc1.

## Root Cause Analysis

### Primary Root Cause
**Accidental Reversion in Commit 2797dc1**

The bloody footprints feature (Issue #360) unintentionally reverted `MAX_BLOOD_DECALS` from `0` (unlimited) back to `100` (limited). This was a **regression** that broke previously working functionality.

### Contributing Factors

1. **Missing Test Execution:**
   - The unit test `test_max_blood_decals_is_unlimited()` was added in commit e370e52
   - If this test was run before merging commit 2797dc1, it would have caught the regression
   - Either the test wasn't run, or it was removed, or test failures were ignored

2. **Similar Variable Names:**
   - Both blood puddles and footprints use similar concepts (unlimited decals)
   - The `MAX_BLOOD_DECALS` constant affects both blood puddles AND footprints
   - Developer may have assumed they needed to set a limit, not realizing it was already unlimited

3. **Lack of Code Comments Highlighting Critical Behavior:**
   - While the code had a comment about Issue #293, it wasn't prominent enough
   - A more visible warning (e.g., "// CRITICAL: Must stay 0 for unlimited decals per Issue #293") might have prevented the change

4. **No Automated Regression Testing:**
   - The unit test exists but may not be running in CI/CD
   - Without automated tests blocking merges, regressions can slip through

### Current Code State

**File:** `scripts/autoload/impact_effects_manager.gd`

**Line 29:**
```gdscript
const MAX_BLOOD_DECALS: int = 100
```

**Lines 462-466 (cleanup in `_schedule_delayed_decal`):**
```gdscript
# Remove oldest decals if limit exceeded
while _blood_decals.size() > MAX_BLOOD_DECALS:
    var oldest := _blood_decals.pop_front() as Node2D
    if oldest and is_instance_valid(oldest):
        oldest.queue_free()
```

**Issue:** The conditional check `if MAX_BLOOD_DECALS > 0` that was added in commit e370e52 is MISSING in the current code! This means the cleanup always runs regardless of the value.

## Technical Research

### Godot Performance Limits for 2D Sprites

Based on research into Godot Engine performance characteristics:

**Hard Limits:**
- There's a bug where `get_children()` on a Node2D with 1041+ children returns null
- However, children can still be accessed individually via `get_child(i)`
- No documented hard limit on total child count from an architectural standpoint

**Performance Benchmarks:**
- FPS drops start appearing around 500 nodes with multiple sprites (16x16 textures, 2-frame animations)
- Adding/removing 10,000 sprites takes ~1 second when split across ticks
- Performance is hardware-dependent rather than engine-imposed

**Best Practices:**
- Object pooling recommended for high-frequency, short-lived objects
- Texture atlases reduce draw calls
- Batching similar draw calls improves GPU efficiency
- Profile before optimizing - use Godot's built-in profiler

**Conclusion for Blood Puddles:**
- Unlimited blood puddles are technically feasible
- Performance impact depends on:
  - Total number of puddles spawned
  - Puddle texture size (currently 8x8 pixels - very small)
  - Hardware capabilities
  - Scene complexity
- Small 8x8 pixel puddles should allow for thousands before performance degrades
- Current limit of 100 is unnecessarily restrictive

**Sources:**
- [Godot Forum: Node2D children limit issue](https://github.com/godotengine/godot/issues/81271)
- [Godot Forum: Performance with many 2D sprites](https://forum.godotengine.org/t/performance-problems-when-rendering-many-2d-sprites/85055)
- [Godot Official Docs: General optimization tips](https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html)
- [Object Pooling Guide for Godot](https://uhiyama-lab.com/en/notes/godot/godot-object-pooling-basics/)

## Proposed Solutions

### Solution 1: Restore Unlimited Blood Puddles (Recommended)

**Approach:** Revert to the unlimited decals behavior from Issue #293.

**Implementation:**
```gdscript
// In scripts/autoload/impact_effects_manager.gd

// Line 29 - Change from:
const MAX_BLOOD_DECALS: int = 100

// To:
## Maximum number of blood decals before oldest ones are removed.
## Set to 0 for unlimited decals (puddles should never disappear per issue #293, #370).
## CRITICAL: Must remain 0 - do not change without explicit user approval.
const MAX_BLOOD_DECALS: int = 0
```

**Also restore the conditional check in cleanup code (lines 462-466, 559-563):**
```gdscript
// Change from:
while _blood_decals.size() > MAX_BLOOD_DECALS:
    var oldest := _blood_decals.pop_front() as Node2D
    if oldest and is_instance_valid(oldest):
        oldest.queue_free()

// To:
# Remove oldest decals if limit exceeded (0 = unlimited, no cleanup)
if MAX_BLOOD_DECALS > 0:
    while _blood_decals.size() > MAX_BLOOD_DECALS:
        var oldest := _blood_decals.pop_front() as Node2D
        if oldest and is_instance_valid(oldest):
            oldest.queue_free()
```

**Pros:**
- Restores user-requested feature from Issue #293
- Fixes current Issue #370
- Aligns with user expectations ("puddles should never disappear")
- Small 8x8 pixel textures make performance impact minimal
- Simple one-line change

**Cons:**
- Theoretically unbounded memory usage in very long play sessions
- Could impact performance on low-end hardware after thousands of puddles

**Risk Mitigation:**
- Scene transitions already clear all decals (`clear_blood_decals()` called in `_on_tree_changed()`)
- Players typically don't play single sessions long enough to spawn thousands of puddles
- If issues arise, can add optional scene-based cleanup or configurable limit

### Solution 2: High Configurable Limit

**Approach:** Set a very high limit (e.g., 1000 or 5000) instead of unlimited.

**Pros:**
- Guarantees bounded memory usage
- Still provides "feels unlimited" experience for normal gameplay

**Cons:**
- Doesn't fulfill the stated requirement ("unlimited")
- Still has the old puddles disappearing problem, just less frequently
- Not what users requested in Issues #293 and #370

**Verdict:** Not recommended. Users explicitly want unlimited puddles.

### Solution 3: Implement Object Pooling

**Approach:** Create a pool of reusable blood decal objects.

**Pros:**
- Reduces garbage collection pressure
- More memory efficient

**Cons:**
- Significantly more complex implementation
- Doesn't address the core issue (puddles disappearing)
- Over-engineering for the current problem
- Blood decals are static sprites with minimal performance impact

**Verdict:** Not needed at this time. Profile first to confirm if pooling is necessary.

## Recommended Solution

**Implement Solution 1: Restore Unlimited Blood Puddles**

This is the simplest, most direct solution that:
1. Fixes the reported regression
2. Restores previously implemented and tested functionality
3. Aligns with explicit user requirements from Issues #293 and #370
4. Requires minimal code changes (one constant + three conditional blocks)
5. Has acceptable performance characteristics for the use case

## Implementation Plan

1. Change `MAX_BLOOD_DECALS` from `100` to `0` in `scripts/autoload/impact_effects_manager.gd:29`
2. Restore conditional check in three locations:
   - Line ~462-466 (`_schedule_delayed_decal` method)
   - Line ~559-563 (`_spawn_wall_blood_splatter` method)
   - Any other cleanup locations
3. Update or restore the unit test `test_max_blood_decals_is_unlimited()` if missing
4. Verify that scene transitions still clear decals properly
5. Test in-game to confirm old puddles no longer disappear

## Testing Recommendations

1. **Unit Test:** Verify `MAX_BLOOD_DECALS == 0`
2. **Integration Test:** Spawn 200+ blood puddles and verify none disappear
3. **Performance Test:** Monitor FPS with 500+ blood puddles on typical hardware
4. **Memory Test:** Monitor memory usage during extended play session
5. **Scene Transition Test:** Verify decals are cleared on scene change

## Prevention Strategies

To prevent similar regressions in the future:

1. **CI/CD Integration:** Run unit tests automatically on all pull requests
2. **Test Naming:** Make test names more explicit (e.g., `test_blood_decals_unlimited_CRITICAL_DO_NOT_BREAK`)
3. **Code Comments:** Add prominent warnings on critical constants
4. **Documentation:** Document design decisions in case studies (like this one)
5. **Code Review:** Ensure reviewers check for regressions in related functionality
6. **Regression Test Suite:** Tag critical tests as regression tests that block merges

## Conclusion

Issue #370 is a regression introduced by commit 2797dc1 when implementing the bloody footprints feature. The fix is straightforward: restore `MAX_BLOOD_DECALS` to `0` and re-add the conditional cleanup checks. This will restore the unlimited blood puddles behavior that was working correctly after Issue #293 and fulfill the user's requirements.
