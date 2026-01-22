# Issue 222: Root Cause Analysis - Reload Animation Not Visible

## Date: 2026-01-22

## Summary

The reload animation for the assault rifle was implemented but was not visible in the game. Investigation revealed that the animation code was added to the wrong script file.

## Problem Statement

User reported: "анимации не видно" (animation is not visible)

The reload animation was supposed to show:
1. Left hand grabs magazine from chest
2. Left hand inserts magazine into rifle
3. Pull the bolt/charging handle

## Investigation Process

### Step 1: Game Log Analysis

Downloaded and analyzed the game log file `game_log_20260122_105528.txt`.

**Key observation:** The log showed:
```
[10:55:29] [INFO] [Player] Ready! Grenades: 1/3
```

But the current code in `player.gd` should output:
```
[Player] Ready! Ammo: %d/%d, Grenades: %d/%d, Health: %d/%d
```

This format mismatch indicated the game was not using the file where the animation was implemented.

### Step 2: Code Review

Searched for the "Ready!" log message format and found:

1. **GDScript version** (`scripts/characters/player.gd` line 272):
   ```gdscript
   FileLogger.info("[Player] Ready! Ammo: %d/%d, Grenades: %d/%d, Health: %d/%d" % [...])
   ```

2. **C# version** (`Scripts/Characters/Player.cs` line 557):
   ```csharp
   LogToFile($"[Player] Ready! Grenades: {_currentGrenades}/{MaxGrenades}");
   ```

The game log matched the C# format, confirming the C# script was being used.

### Step 3: Scene Configuration Review

Found TWO Player scene files:

| Scene File | Script Used |
|------------|-------------|
| `scenes/characters/Player.tscn` | `scripts/characters/player.gd` (GDScript) |
| `scenes/characters/csharp/Player.tscn` | `Scripts/Characters/Player.cs` (C#) |

The game uses the **C# version** (`csharp/Player.tscn`), but the reload animation was only implemented in the **GDScript version** (`player.gd`).

## Root Cause

**The reload animation was implemented in the wrong file.**

- Animation code was added to: `scripts/characters/player.gd`
- Game actually uses: `Scripts/Characters/Player.cs`

The animation code in `player.gd` is never executed because the game loads the C# player scene which uses `Player.cs`.

## Evidence

### Game Log Evidence
- Log format `Ready! Grenades: 1/3` matches C# Player.cs (line 557)
- No `[Player.Reload.Anim]` log entries (which would appear if GDScript was used)
- No `Ready! Ammo:` prefix (which would appear if GDScript was used)

### File Evidence
- `Scripts/Characters/Player.cs` contains C# reload logic but NO animation code
- `scripts/characters/player.gd` contains full reload animation implementation
- `scenes/characters/csharp/Player.tscn` references `Player.cs`

## Solution

Implement the reload animation in `Scripts/Characters/Player.cs` following the same pattern:

1. Add `ReloadAnimPhase` enum
2. Add animation position/rotation constants
3. Add `_reloadAnimPhase`, `_reloadAnimTimer`, `_reloadAnimDuration` fields
4. Implement `StartReloadAnimPhase()` method
5. Implement `UpdateReloadAnimation()` method
6. Call animation methods from reload input handlers
7. Integrate with `_PhysicsProcess()`

## Timeline of Events

| Time | Event |
|------|-------|
| 2026-01-22 08:40 | Reload animation committed to `player.gd` |
| 2026-01-22 10:55 | User tested game using C# build |
| 2026-01-22 10:55:28 | Game log started (C# Player.cs used) |
| 2026-01-22 10:55:56 | Game log ended - no reload animation visible |
| 2026-01-22 07:56 | User reported issue in PR comment |

## Files Involved

### Currently Modified (Wrong File)
- `scripts/characters/player.gd` - Contains unused reload animation code

### Needs Modification (Correct File)
- `Scripts/Characters/Player.cs` - Needs reload animation implementation

### Reference
- `docs/case-studies/issue-222/logs/game_log_20260122_105528.txt` - User's game log showing issue
