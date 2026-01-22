# Case Study: Issue #210 - Shotgun Interaction Update

## Issue Summary

**Title**: update взаимодействие с дробовиком (Update shotgun interaction)
**Issue URL**: https://github.com/Jhon-Crow/godot-topdown-MVP/issues/210
**Date Opened**: 2026-01-22

### Requirements (Translated from Russian)

1. **Building level should give 20 shotgun charges** - Currently gives too many shells
2. **Add continuous drag-and-drop reload mechanism**:
   - Hold RMB, then drag up (opens bolt)
   - Without releasing RMB, drag down (closes bolt)
   - All in one continuous movement
3. **Keep old mechanism working** - Individual RMB gestures should still work

## Technical Analysis

### Current Shotgun Implementation

**Files involved:**
- `Scripts/Weapons/Shotgun.cs` - Main shotgun weapon class
- `resources/weapons/ShotgunData.tres` - Weapon data configuration
- `scripts/levels/building_level.gd` - Building level script
- `Scripts/AbstractClasses/BaseWeapon.cs` - Base weapon class

### Current Behavior

#### Ammo System
- `TubeMagazineCapacity = 8` - Shells that can be loaded in the tube
- `MaxReserveAmmo = 24` - Reserve shells (in ShotgunData.tres)
- Total shells: 8 (tube) + 24 (reserve) = 32 shells

#### Current Reload Mechanism
The shotgun uses a state machine for reload:

```
ShotgunReloadState:
- NotReloading    → Ready for action
- WaitingToOpen   → Waiting for RMB drag UP
- Loading         → Bolt open, MMB + RMB drag DOWN to load
- WaitingToClose  → Waiting for RMB drag DOWN to close
```

**Current reload flow:**
1. RMB drag UP → Opens bolt (transitions to Loading state)
2. MMB + RMB drag DOWN → Loads a shell (stays in Loading state)
3. RMB drag DOWN (without MMB) → Closes bolt

**Issue:** Each RMB gesture requires releasing and re-pressing RMB.

### Proposed Changes

#### 1. Reduce Reserve Ammo to 20 Shells Total

The user wants 20 total shells on building level:
- Tube starts full (8 shells)
- Reserve should be 12 shells (8 + 12 = 20 total)

**Option A:** Change `MaxReserveAmmo` in ShotgunData.tres from 24 to 12
- This affects ALL levels globally

**Option B:** Configure per-level starting ammo in building_level.gd
- More flexible, different levels can have different ammo

**Recommendation:** Option A is simpler and matches the request directly.

#### 2. Continuous Drag-and-Drop Reload

The new mechanism allows:
- Hold RMB continuously
- Drag UP → Opens bolt
- (Still holding RMB) Drag DOWN → Closes bolt

**Implementation approach:**
- Track drag gestures during a single continuous RMB hold
- Process intermediate drags, not just on RMB release
- Track the current drag position relative to the last "gesture boundary"

**Key insight from code analysis:**
```csharp
// Current code in HandleDragGestures():
if (Input.IsMouseButtonPressed(MouseButton.Right))
{
    if (!_isDragging)
    {
        _dragStartPosition = GetGlobalMousePosition();
        _isDragging = true;
    }
}
else if (_isDragging)
{
    // Only processes gesture on RMB RELEASE
    Vector2 dragEnd = GetGlobalMousePosition();
    ProcessDragGesture(dragVector);
}
```

**Solution:** Add mid-drag gesture detection that:
1. Tracks when a significant UP or DOWN drag occurs during continuous RMB hold
2. Processes the gesture immediately
3. Resets the drag start position for the next gesture
4. Maintains backward compatibility with release-based gestures

## Timeline

| Event | Timestamp | Description |
|-------|-----------|-------------|
| Issue Created | 2026-01-22 | User reports need for shotgun improvements |
| Analysis Started | 2026-01-22 05:51 | Code review of shotgun mechanics |
| Initial Implementation | 2026-01-22 05:51 | Add continuous reload + reduce shells to 20 |
| User Feedback #1 | 2026-01-22 05:57 | Shell loading should use old behavior, bolt open/close is correct |
| Fix Shell Loading | 2026-01-22 06:02 | Preserve original shell loading behavior (require RMB release) |
| User Feedback #2 | 2026-01-22 06:01 | Sometimes bolt accidentally opens after closing |
| Add Cooldown 250ms | 2026-01-22 06:07 | Add cooldown protection to prevent accidental bolt reopening |
| User Feedback #3 | 2026-01-22 06:15 | Bolt still opens accidentally during pump-action chambering |
| Increase Cooldown | 2026-01-22 06:18 | Increase cooldown from 250ms to 400ms |

## Related Pull Requests

- **PR #214**: Fix shotgun reload input timing (recently merged)
- **PR #209**: Fix shotgun reload UI - update ammo counter immediately
- **PR #215**: This PR - Update shotgun interaction

## Files Modified

1. `resources/weapons/ShotgunData.tres` - Reduce MaxReserveAmmo to 12
2. `Scripts/Weapons/Shotgun.cs` - Add continuous drag gesture support

## Test Plan

1. Verify building level starts with exactly 20 shells total (8 in tube + 12 reserve)
2. Test continuous reload:
   - Hold RMB, drag up → bolt opens
   - Without releasing RMB, drag down → bolt closes
3. Test old reload mechanism still works:
   - RMB drag up (release) → bolt opens
   - RMB drag down (release) → bolt closes
4. Test shell loading during reload (MMB + RMB drag down)

## User Feedback and Resolution

### Feedback from @Jhon-Crow (2026-01-22)

> "новое поведение при заряде снарядов не нужно (оставь старый), новое открывание/закрывание затвора работает правильно."

**Translation:**
- "New shell loading behavior is not needed (keep the old one)"
- "New bolt open/close works correctly"

### Root Cause Analysis

The initial implementation added continuous mid-drag support for all shotgun gestures:
1. Pump-action cycling (up to eject shell, down to chamber) ✓
2. Bolt open/close (up to open, down to close) ✓
3. **Shell loading (MMB + down while in Loading state)** ← User didn't want this

The user expected shell loading to remain as a distinct, deliberate action requiring RMB release,
while the bolt open/close should support the new continuous gesture.

### Resolution

Modified `TryProcessMidDragGesture()` to:
- Keep continuous gesture support for bolt opening (drag UP in WaitingToOpen state)
- Keep continuous gesture support for bolt closing (drag DOWN in Loading state **without** MMB)
- **Preserve original shell loading behavior**: When MMB is held during drag DOWN in Loading state,
  the mid-drag gesture is not processed (returns false), requiring the user to release RMB
  to trigger shell loading via the original `ProcessReloadGesture()` path

### Code Change for Shell Loading

```csharp
// In TryProcessMidDragGesture(), Loading state handling:
if (shouldLoadShell)
{
    // MMB held - don't process mid-drag, let user release RMB to load shell
    // This preserves the old shell loading behavior while allowing
    // continuous bolt open/close gestures
    return false;
}
else
{
    CompleteReload();
}
```

---

### Feedback #2 from @Jhon-Crow (2026-01-22 06:01)

> "сейчас иногда после закрывания затвора он случайно открывается (добавь защиту)."

**Translation:**
- "Now sometimes after closing the bolt it accidentally opens (add protection)"

### Root Cause Analysis

When performing continuous gestures (hold RMB, drag UP, then DOWN), after the bolt closes the drag start position resets. If the user continues moving the mouse slightly upward (even while releasing), this can trigger another bolt open gesture.

### Resolution

Added a 250ms cooldown period after closing the bolt. During this cooldown, any drag UP gesture that would open the bolt is ignored.

---

### Feedback #3 from @Jhon-Crow (2026-01-22 06:15)

> "поведение с MMB работает правильно, но затвор всё ещё можно случайно открыть при досылании (после выстрела) патрона (сразу после закрытия затвора)."

**Translation:**
- "MMB behavior works correctly, but the bolt can still accidentally open during chambering (after firing) a round (right after closing the bolt)"

### Root Cause Analysis

During fast pump-action sequences (fire → pump UP → pump DOWN), the 250ms cooldown was not sufficient protection. The user's continued mouse movement after completing the pump-down could still trigger an accidental bolt open within the cooldown window.

### Resolution

Increased the bolt close cooldown from **250ms to 400ms** to provide more robust protection against fast pump-action sequences. Added verbose logging capability (can be enabled via `VerboseInputLogging`) for future debugging if issues persist.

### Code Change for Cooldown Protection

```csharp
// Bolt close cooldown to prevent accidental reopening
private const float BoltCloseCooldownSeconds = 0.4f; // 400ms
private double _lastBoltCloseTime = 0.0;

private bool IsInBoltCloseCooldown()
{
    double currentTime = Time.GetTicksMsec() / 1000.0;
    double elapsedSinceClose = currentTime - _lastBoltCloseTime;
    bool inCooldown = elapsedSinceClose < BoltCloseCooldownSeconds;

    if (inCooldown && VerboseInputLogging)
    {
        GD.Print($"[Shotgun.Input] Bolt open blocked by cooldown: {elapsedSinceClose:F3}s < {BoltCloseCooldownSeconds}s");
    }

    return inCooldown;
}
```

The cooldown is set after:
- `CompleteReload()` - When bolt is closed to complete reload
- Pump-action down gestures - Both mid-drag and release-based

## Logs

- `logs/game_log_20260122_085458.txt` - User testing log (Feedback #1)
- `logs/game_log_20260122_091126.txt` - User testing log (Feedback #3)
- `logs/game_log_20260122_091335.txt` - User testing log (Feedback #3)
- `logs/solution-draft-log-pr-1769061104361.txt` - AI solution draft log

## Summary of Changes

| Commit | Description |
|--------|-------------|
| `17f1310` | Add continuous shotgun reload and reduce shells to 20 total |
| `008f283` | Preserve original shell loading behavior in mid-drag gestures |
| `afcbcba` | Add cooldown protection to prevent accidental bolt reopening |
| `31acef1` | Increase bolt close cooldown from 250ms to 400ms |
