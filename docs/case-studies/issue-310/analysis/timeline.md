# Issue #310 Timeline Reconstruction

## Timeline of Events

### Initial Issue Request (Issue #310)
**Date:** 2026-01-24 (before 06:26:34 UTC)

**User Request:**
- Extend debug logging specifically for grenade throwing by the player
- Record exact mouse movement and resulting throw direction
- User will then provide feedback on where they wanted to throw and with what force
- Based on the log, the AI should correct the controls

**Issue Description (Russian):**
> "расширь дебаг (логгирование) специально для отладки броска гранаты игроком - запиши точно движение мыши и следующее за ним направление броска
> затем я скажу, куда хотел бросить и с какой силой, а ты исходя из лога скорректируешь управление."

**Translation:**
> "Extend debug (logging) specifically for debugging grenade throw by player - record exact mouse movement and the throw direction that follows it.
> Then I will tell you where I wanted to throw and with what force, and you will adjust the controls based on the log."

---

### First Implementation Attempt (Session 1)
**Date:** 2026-01-24 06:26:34 - 06:35:30 UTC

**Actions Taken:**
1. AI implemented detailed F8 logging in `scripts/characters/player.gd` (GDScript)
2. Added frame-by-frame mouse tracking during grenade aiming
3. Added comprehensive throw data logging

**Commits:**
- `a8435a3` - Initial commit with task details
- `a6ba37d` - feat: add detailed grenade throw debug logging (F8 toggle)

**Problem:** The GDScript player file is **not used** in the project. The real player is `Scripts/Characters/Player.cs` (C#).

**User Feedback 1:**
**Time:** 2026-01-24 06:25:59 UTC
**File Provided:** `game_log_20260124_092318.txt`

> "проверь, правильно ли работает логгирование?"
> Translation: "Check if logging works correctly?"

**Analysis of Log 1:**
- F8 was turned ON at 09:23:24 (line 94)
- Grenade throwing occurred at 09:23:27 - 09:23:29
- **NO detailed frame-by-frame logging** during wind-up phase
- Only basic grenade throw logs were present
- **Conclusion:** F8 logging was not working because it was implemented in unused GDScript file

---

### Second Implementation Attempt (Session 2)
**Date:** 2026-01-24 06:26:34 - 06:35:30 UTC

**Actions Taken:**
1. AI discovered the real player is C# (`Scripts/Characters/Player.cs`)
2. Implemented F8 logging in C# Player:
   - Connected to `grenade_debug_logging_toggled` signal from GameManager
   - Added detailed frame-by-frame logging in `UpdateWindUpIntensity()`
   - Added comprehensive throw data logging in `ThrowGrenade()`
   - Added yellow "F8 DEBUG" visual indicator above player

**Commits:**
- `d7b7643` - Revert "Initial commit with task details"
- `2a86857` - fix: add F8 grenade debug logging to C# Player (issue #310)

**Implementation Details:**
- Line 2463 in Player.cs: `LogToFile()` called every physics frame (60 FPS) during aiming
- Each `LogToFile()` call:
  1. Calls `GD.Print(message)` → Godot console
  2. Calls `FileLogger.log_info(message)` → file_logger.gd
  3. file_logger.gd line 107-108: `_log_file.store_line()` then `_log_file.flush()` → **SYNCHRONOUS DISK I/O**

**User Feedback 2:**
**Time:** 2026-01-24 06:47:20 UTC
**File Provided:** `game_log_20260124_094610.txt`

> "проверь теперь, достаточно ли детально, не записало ли лишнего
> опиши, что я сделал на записи"
> Translation: "Check now if it's detailed enough, if it didn't log too much.
> Describe what I did in the recording"

**Analysis of Log 2:**
- F8 was turned ON at 09:46:12
- Grenade aiming started at 09:46:14
- **49 frames of detailed logging** from Frame 1 to Frame 49 (lines 111-159)
- At 60 FPS: 49 frames = ~0.817 seconds of aiming
- Each frame logged: mouse position, delta, velocity, swing distance
- Throw executed at 09:46:15
- **Conclusion:** F8 logging NOW WORKS CORRECTLY

**AI Response:** Detailed analysis of user's actions showing the logging is working perfectly.

---

### Critical Bug Discovery
**Time:** 2026-01-24 06:52:41 UTC

**User Report (Russian):**
> "с включенным дебагом граната замирает на месте после отпускания броска, невозможно понять, туда ли летит"

**Translation:**
> "With debug enabled, the grenade freezes in place after releasing the throw, impossible to understand where it flies"

**Additional Request:**
> "Please download all logs and data related about the issue to this repository, make sure we compile that data to `./docs/case-studies/issue-{id}` folder, and use it to do deep case study analysis (also make sure to search online for additional facts and data), in which we will reconstruct timeline/sequence of events, find root causes of the problem, and propose possible solutions."

**Current Status:** Bug under investigation (this document).

---

## Session Summary

| Session | Time (UTC) | Implementation | Result | Issue |
|---------|-----------|----------------|--------|-------|
| 1 | 06:26:34 - 06:35:30 | F8 logging in GDScript player | ❌ Not working | Wrong file (unused) |
| 2 | 06:48:00 - 06:49:42 | F8 logging in C# Player | ⚠️ Working but freezes game | Synchronous file I/O every frame |
| 3 | 06:53:20 - present | Bug investigation & fix | 🔄 In progress | Current session |

---

## Key Metrics

### Logging Performance Impact
- **Frames logged per second:** 60 (physics FPS)
- **File I/O operations per second:** 60 (each with `flush()`)
- **Duration of typical grenade aim:** ~0.8-1.0 seconds
- **Total file I/O operations per throw:** ~48-60 synchronous disk writes

### File Operations
1. `Player.cs:2463` → `LogToFile()`
2. `Player.cs:2682` → `GD.Print()`
3. `Player.cs:2688` → `fileLogger.Call("log_info")`
4. `file_logger.gd:107` → `_log_file.store_line()`
5. `file_logger.gd:108` → `_log_file.flush()` ← **BLOCKING OPERATION**

---

## References

- Issue: https://github.com/Jhon-Crow/godot-topdown-MVP/issues/310
- Pull Request: https://github.com/Jhon-Crow/godot-topdown-MVP/pull/311
- Branch: `issue-310-245e3e4ca1f3`
