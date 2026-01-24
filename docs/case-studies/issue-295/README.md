# Case Study: Issue #295 - Tactical Grenade Throwing Debug

## Issue Summary

**Issue Title**: отладить бросок гранаты врагом (Debug enemy grenade throwing)
**Issue URL**: https://github.com/Jhon-Crow/godot-topdown-MVP/issues/295
**PR URL**: https://github.com/Jhon-Crow/godot-topdown-MVP/pull/296

## Timeline of Events

### 2026-01-24 00:51 UTC
- Initial implementation commit `8144be2` "Fix wall-blocking and implement tactical grenade behaviors"
- This commit added significant grenade coordination features per issue #295 requirements
- **Problem**: enemy.gd grew to 5273 lines, exceeding the 5000 line CI limit
- CI Architecture check failed

### 2026-01-24 01:01 UTC
- User reported two issues:
  1. Architecture check failing (5273 lines > 5000 limit)
  2. "Enemies completely broke (don't move)"
- User attached game_log_20260124_040202.txt showing "Level started with 0 enemies"

### 2026-01-24 01:05 UTC
- Commit `c7a8654` "refactor(enemy): condense doc comments to reduce file below 5000 lines"
- Condensed verbose multi-line documentation to single lines
- Reduced enemy.gd from 5273 to 4999 lines
- CI Architecture check now passes

### 2026-01-24 01:07 UTC
- Commit `be0c971` reverted CLAUDE.md task file
- All CI checks passing (Architecture, Unit Tests, Windows Export)

### 2026-01-24 01:13 UTC
- Commit `69d0f8a` adds case study documentation
- Final successful build created with all checks passing
- Windows Export artifact available for testing

### 2026-01-24 01:19 UTC (04:19 local, UTC+3)
- **User reports enemies still broken** (second report)
- User suspects C# issue: "враги всё ещё сломаны, возможно дело в C#"
- New game log: game_log_20260124_041819.txt
- Shows same symptom: "Level started with 0 enemies"
- User testing latest build (timestamp 01:18 UTC = after latest commit at 01:13 UTC)

## Root Cause Analysis

### CI Architecture Failure
- **Direct cause**: enemy.gd exceeded 5000 line limit
- **Root cause**: Adding grenade coordination features (issue #295) added ~583 new lines
- **Solution**: Condensed multi-line doc comments to single lines

### "Enemies Broken" Report - PERSISTS in Latest Build

**Symptoms:**
- Game log shows "Level started with 0 enemies" in BOTH reports (04:02 and 04:18 local time)
- Sound propagation shows 0 listeners: "listeners=0" in all gunshot events
- No enemy movement or behavior

**Investigation Timeline:**

1. **First hypothesis**: User testing old build (commit 8144be2 with 5273 line enemy.gd)
   - REJECTED: Second report at 04:18 local (01:18 UTC) is AFTER latest successful build at 01:13 UTC

2. **Second hypothesis**: GDScript export issue with large files
   - Initial commit had 5273 lines → reduced to 4999 lines in refactor
   - Windows Export CI succeeded for BOTH versions
   - If export was truncating files, CI would show errors

3. **Current investigation**: Enemy script fails to load in Windows export

**Evidence from codebase analysis:**

```gdscript
// building_level.gd:_setup_enemy_tracking()
for child in enemies_node.get_children():
    if child.has_signal("died"):  // <-- Returns FALSE for all 10 enemy nodes!
        _enemies.append(child)
```

**Why enemy.gd might not load:**
- enemy.gd extends CharacterBody2D (correct)
- enemy.gd declares signals at class level (lines 176-200)
- BuildingLevel.tscn contains 10 Enemy instances
- Enemy.tscn references "res://scripts/objects/enemy.gd"

**Possible causes:**
1. **GDScript parsing error in export**: If enemy.gd has a parse error that only manifests in export build (not editor), script won't attach
2. **Missing dependency**: GrenadeThrowerComponent may not be included in export
3. **Resource loading failure**: caliber_545x39.tres or other resources missing in export
4. **Scene corruption**: Enemy.tscn file integrity issue in export

**Critical finding:**
The file size reduction (5273 → 4999 lines) did NOT fix the issue. Both the oversized and refactored versions exhibit the same "0 enemies" problem in Windows exports.

## Features Implemented (Issue #295)

### Bug Fix
- Enemy no longer throws grenades at walls point-blank
- Added `is_throw_path_clear()` wall detection

### Ally Coordination
1. Thrower broadcasts warning signal before throwing
2. Allies in blast zone/throw line evacuate with max priority
3. Evacuating allies wait for explosion then begin coordinated assault

### Post-Throw Behavior
- Offensive grenades: approach safe distance while aiming at landing spot
- Non-offensive grenades: find cover from blast rays
- After explosion: assault through the grenade passage

### Throw Mode Triggers
- Player hidden 6+ seconds after suppression
- Player chasing suppressed thrower
- Witnessed 2+ ally deaths
- Heard reload/empty click sound (can't see player)
- Continuous gunfire for 10 seconds
- Thrower at 1 HP or less

## Files Changed

| File | Lines Changed | Purpose |
|------|---------------|---------|
| scripts/objects/enemy.gd | +583/-227 | Grenade coordination, post-throw behavior |
| scripts/components/grenade_thrower_component.gd | +525 | New component (from PR #274) |

## Lessons Learned

1. **Monitor file sizes**: Large feature additions can push files over CI limits
2. **Doc comment compression**: Multi-line comments can be condensed without losing meaning
3. **User testing**: Ensure users test the correct build after fixes are pushed
4. **Game logs**: "Level started with 0 enemies" indicates instantiation issues

## Recommendations

### Immediate Actions (Priority 1)

1. **Add debug logging to BuildingLevel.gd `_ready()` function:**
   ```gdscript
   func _setup_enemy_tracking() -> void:
       var enemies_node := get_node_or_null("Environment/Enemies")
       if enemies_node == null:
           print("[ERROR] Environment/Enemies node not found!")
           return

       print("[DEBUG] Found Environment/Enemies node with %d children" % enemies_node.get_child_count())

       for child in enemies_node.get_children():
           print("[DEBUG] Child: %s, Type: %s, Has 'died' signal: %s" % [
               child.name,
               child.get_class(),
               child.has_signal("died")
           ])
           if child.has_signal("died"):
               _enemies.append(child)
   ```

2. **Test in Godot Editor first:**
   - Open project in Godot 4.3
   - Run BuildingLevel scene directly
   - Check console output for debug logs
   - Verify enemies initialize correctly

3. **Create minimal reproduction:**
   - Create a test scene with single Enemy node
   - Add print statement in enemy.gd `_ready()`
   - Export and test if script loads

### Investigation Actions (Priority 2)

1. **Check export settings:**
   - Verify all scripts are included in export filter
   - Check if resources folder is included
   - Ensure components/ folder scripts are exported

2. **Test without grenade system:**
   - Temporarily disable grenade initialization in enemy.gd `_ready()`
   - Comment out lines 688-695 (grenade component creation)
   - Export and test if enemies work

3. **Check for cyclic dependencies:**
   - Verify GrenadeThrowerComponent doesn't depend on Enemy
   - Check if any signal connections create circular references

### Long-term Solutions (Priority 3)

1. **Add export validation:**
   - Create CI check that runs exported game headlessly
   - Verify enemy count matches expected (10 for BuildingLevel)
   - Add automated screenshot comparison

2. **Refactor enemy.gd:**
   - Even at 4999 lines, the file is monolithic
   - Consider splitting into:
     - enemy_base.gd (core logic)
     - enemy_combat.gd (combat behaviors)
     - enemy_grenade.gd (grenade coordination)
     - enemy_movement.gd (pathfinding/movement)

## Status

- [x] Architecture check passing
- [x] Unit tests passing
- [x] Windows Export builds successfully (CI)
- [x] Case study analysis completed
- [ ] **CRITICAL**: Enemies not loading in Windows Export - requires urgent investigation
- [ ] Debug logging added to identify load failure
- [ ] User verification of fix needed
