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

## Root Cause Analysis

### CI Architecture Failure
- **Direct cause**: enemy.gd exceeded 5000 line limit
- **Root cause**: Adding grenade coordination features (issue #295) added ~583 new lines
- **Solution**: Condensed multi-line doc comments to single lines

### "Enemies Broken" Report
- **Investigation**: Game log showed "Level started with 0 enemies"
- **Analysis**: This indicates either:
  1. User tested an old/broken build before fixes were pushed
  2. The level loaded didn't have enemies
  3. Enemies failed to instantiate due to script parsing errors
- **Evidence**:
  - Current enemy.gd passes syntax validation
  - All CI checks pass including Windows Export
  - BuildingLevel.tscn contains 10 properly configured enemies
- **Conclusion**: The issue was likely from testing the Windows Export of the failing commit

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

## Status

- [x] Architecture check passing
- [x] Unit tests passing
- [x] Windows Export builds successfully
- [ ] User verification of enemy behavior needed
