# Case Study: Issue #243 - Shotgun Reload Bug

## Issue Summary

**Title:** fix зарядка дробовика (fix shotgun charging)
**Issue URL:** https://github.com/Jhon-Crow/godot-topdown-MVP/issues/243
**Pull Request:** https://github.com/Jhon-Crow/godot-topdown-MVP/pull/244

### Problem Description

After opening the bolt (RMB drag UP), when holding MMB and performing RMB drag DOWN, the bolt closes instead of loading a shell.

**Original Report (Russian):**
> после первого открытия затвора:
> при зажатом MMB и драгндропе ПКМ вниз - затвор закрывается, вместо того чтобы зарядить заряд.
> добавь проверку на зажатое MMB, которая не позволит закрыть затвор, но позволит зарядить заряд.

**Translation:**
> After first opening the bolt:
> when MMB is held and RMB drag-n-drop down - bolt closes instead of loading a shell.
> Add a check for held MMB that will NOT allow closing the bolt, but WILL allow loading a shell.

---

## Solution: New Control Scheme (2026-01-22)

After initial fix attempts, the user requested a simpler control scheme. The original "MMB hold + RMB drag" was replaced with "MMB drag down" for shell loading.

### Old Control Scheme (Deprecated)
```
RMB drag UP (open bolt) → [MMB + RMB drag DOWN]×N (load shells) → RMB drag DOWN (close bolt)
```

### New Control Scheme
```
RMB drag UP (open bolt) → [MMB drag DOWN]×N (load shells) → RMB drag DOWN (close bolt)
```

**Key Changes:**
1. Shell loading is now done with **MMB drag DOWN** (middle mouse button drag alone)
2. RMB drag DOWN in Loading state now **always closes the bolt**
3. The two input gestures (MMB for loading, RMB for bolt) are completely separate

### Tutorial Text Update
- Old: `[ПКМ↑ открыть] [СКМ+ПКМ↓ x8] [ПКМ↓ закрыть]`
- New: `[ПКМ↑ открыть] [СКМ↓ x8] [ПКМ↓ закрыть]`

---

## Technical Analysis

### Code Structure

The shotgun reload mechanic is implemented in `Scripts/Weapons/Shotgun.cs`. Key components:

1. **State Machine:**
   - `ShotgunReloadState`: NotReloading, WaitingToOpen, Loading, WaitingToClose
   - `ShotgunActionState`: Ready, NeedsPumpUp, NeedsPumpDown

2. **Input Handling Methods:**
   - `HandleDragGestures()`: Handles RMB drag gestures (bolt open/close, pump action)
   - `HandleMiddleMouseDrag()`: Handles MMB drag gestures (shell loading)
   - `TryProcessMidDragGesture()`: Processes gestures while RMB is still held
   - `ProcessDragGesture()`: Processes gestures when RMB is released
   - `ProcessReloadGesture()`: Handles reload-specific logic

3. **MMB Tracking Variables (New):**
   - `_isMiddleMouseHeld`: Current MMB state
   - `_isMiddleMouseDragging`: Whether MMB drag is active
   - `_mmbDragStartPosition`: Start position of MMB drag

### Implementation Details

The new `HandleMiddleMouseDrag()` function:
- Tracks MMB press/release separately from RMB
- When in Loading state, detects vertical drag DOWN
- Loads a shell when drag threshold is reached
- Supports continuous loading by resetting drag start after each shell

---

## Timeline of Events

| Timestamp | Event |
|-----------|-------|
| 2026-01-22 11:16:29 | Issue #243 created |
| 2026-01-22 11:17:08 | Initial commit with task details |
| 2026-01-22 11:23:58 | Fix committed: prevent bolt closing when MMB is held |
| 2026-01-22 11:26:03 | Reverted task details commit (cleanup) |
| 2026-01-22 11:26:06 | CI build completed successfully |
| 2026-01-22 14:29:19 | User reports "nothing changed" with log file |
| 2026-01-22 14:41:36 | User tested new build, issue persists |
| 2026-01-22 14:46:31 | User requests new control scheme: MMB drag down |
| 2026-01-22 ~14:48 | New control scheme implemented |

---

## Artifacts

### Logs
- `logs/game_log_20260122_142919.txt` - User's first game log
- `logs/game_log_20260122_144136.txt` - User's second test log
- `logs/game_log_20260122_144154.txt` - User's third test log
- `logs/game_log_20260122_144226.txt` - User's fourth test log
- `logs/solution-draft-log.txt` - AI solver's detailed analysis log

### Code Snapshots
The fix is on branch `issue-243-b3e05cb772c2`.

---

## Verification Steps

To verify the fix is working:

1. **Download the latest CI build** from: https://github.com/konard/Jhon-Crow-godot-topdown-MVP/actions?query=branch%3Aissue-243-b3e05cb772c2

2. **Test the new reload sequence:**
   - RMB drag UP (bolt opens)
   - Release RMB
   - MMB drag DOWN (shell loads, repeat for more shells)
   - RMB drag DOWN (bolt closes)
   - **Expected:** Shells load with each MMB drag DOWN, bolt closes with RMB drag DOWN

3. **Check log file for diagnostic messages:**
   - Look for `[Shotgun.MMB]` entries for MMB drag tracking
   - Look for `[Shotgun] MMB drag DOWN - loading shell` messages

---

## Key Design Decision

The user requested simpler controls after the original fix didn't work as expected. The new design separates the two gestures completely:

- **MMB drag** = shell loading (only works in Loading state)
- **RMB drag** = bolt operations (open/close) and pump action

This eliminates any timing/race condition issues between the two buttons since they are now handled independently.
