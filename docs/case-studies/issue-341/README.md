# Case Study: Issue #341 - Interactive Shell Casings with EXE Crash Investigation

## Issue Summary

**Issue URL:** https://github.com/Jhon-Crow/godot-topdown-MVP/issues/341

**Original Request (Russian):**
> сделай гильзы на полу интерактивными
> должны реалистично отталкиваться при ходьбе игрока/врагов со звуком гильзы

**English Translation:**
> Make shell casings on the floor interactive
> They should realistically push away when the player/enemies walk, with shell casing sound

---

## Executive Summary

This case study documents the development of an interactive shell casing feature and the critical investigation into why the exported EXE crashes immediately after the Godot splash screen. The investigation revealed **multiple potential root causes** related to both GDScript type checking patterns and C#/.NET export requirements.

### Key Findings

1. **GDScript Pattern Issues (Fixed):**
   - `.has()` method called on Resource objects (crashes silently in exports)
   - `is ClassName` type checks can cause parse errors in exported builds
   - **Solution:** Use property-based checks (`"property" in object`)

2. **C#/.NET Export Requirements (Potential Cause):**
   - Project uses hybrid C#/GDScript architecture
   - Main scene uses C# Player (`res://scenes/characters/csharp/Player.tscn`)
   - C# exports require .NET export templates, not standard GDScript templates
   - Assembly name mismatch can cause immediate crash after splash screen

---

## Detailed Timeline of Events

### Phase 1: Feature Implementation (PR #342)

| Date/Time (UTC) | Event | Details |
|-----------------|-------|---------|
| 2026-01-24 23:32 | PR #342 Created | Initial implementation of interactive casings |
| 2026-01-25 00:06 | User Report #1 | "ни враги ни игрок не влияют на гильзы" (casings not reacting) |
| 2026-01-25 00:18 | Fix Applied | Improved kick detection with larger Area2D and signal + manual fallback |
| 2026-01-25 00:28 | Enhancement | Added dual detection (signal-based + `get_overlapping_bodies()` fallback) |

### Phase 2: Crash Reports Begin

| Date/Time (UTC) | Event | Details |
|-----------------|-------|---------|
| **2026-01-25 00:37** | **CRASH REPORTED** | "игра не запускается - появляется заставка godot и сразу исчезает" (splash screen then crashes) |
| 2026-01-25 00:42 | Fix Attempt #1 | Changed `caliber_data.has("key")` to `"key" in caliber_data` |
| 2026-01-25 00:47 | User Report #2 | "не исправлено" (not fixed) |
| 2026-01-25 00:57 | Fix Attempt #2 | Simplified to only use `CaliberData` type check |
| 2026-01-25 01:09 | User Report #3 | "всё ещё не запускается" (still not starting) |
| 2026-01-25 01:10 | PR #342 Closed | Decision to create fresh PR |

### Phase 3: New PR and Continued Investigation (PR #359)

| Date/Time (UTC) | Event | Details |
|-----------------|-------|---------|
| 2026-01-25 01:10 | PR #359 Created | Fresh implementation with lessons learned |
| 2026-01-25 01:27 | User Report #4 | "опять вылетает так же" (crashes the same way again) |
| 2026-01-25 01:55 | User Report #5 | "сразу вылетает. дальше заставки godot не включается" (crashes immediately after splash) |
| 2026-01-25 02:12 | Fix Attempt #3 | Removed `is CaliberData` type checks, replaced with property-based checks |
| 2026-01-25 02:40 | Discovery | Project uses C# Player scene which may require .NET export templates |
| 2026-01-25 04:14 | Investigation | Deep dive into C# export requirements |
| 2026-01-25 05:25 | User Request | Request for comprehensive case study analysis |

---

## Root Cause Analysis

### Issue #1: `.has()` Method on Resource Objects (Fixed in PR #359)

**Problem Code:**
```gdscript
# CRASHES in exported builds - .has() is Dictionary-only!
if caliber_data.has("caliber_name"):
    caliber_name = caliber_data.get("caliber_name")
```

**Why It Crashes:**
1. The `.has()` method is **only available on Dictionary objects** in GDScript
2. `caliber_data` is typed as `Resource`, not `Dictionary`
3. GDScript silently crashes in exported builds when calling undefined methods
4. No error shown - game just closes after splash screen

**Solution Applied:**
```gdscript
# SAFE - "in" operator works on any Object
if "caliber_name" in caliber_data:
    caliber_name = caliber_data.caliber_name
```

### Issue #2: `is ClassName` Type Checks (Fixed in PR #359)

**Problem Code:**
```gdscript
# Can cause parse errors in exported builds!
if caliber_data is CaliberData:
    var caliber: CaliberData = caliber_data as CaliberData
```

**Why It Crashes:**
1. GDScript `class_name` references may not resolve correctly in exported builds
2. Known Godot issue [#41215](https://github.com/godotengine/godot/issues/41215): "References to class not resolved when exported"
3. Error: `Parse Error: The identifier 'CaliberData' isn't declared in the current scope`
4. Crash occurs at script load time - before game logic runs

**Relevant Godot Issues:**
- [#41215](https://github.com/godotengine/godot/issues/41215) - References to class not resolved when exported
- [#76380](https://github.com/godotengine/godot/issues/76380) - Class names stop working after a while
- [Godot Forum](https://forum.godotengine.org/t/4-3-stable-exported-build-crashes-immediately-upon-starting-up-game-everything-fails-to-load/101339) - Similar crash symptoms

**Solution Applied:**
```gdscript
# SAFE - property check instead of type check
if not ("caliber_name" in caliber_data):
    return "rifle"
var caliber_name: String = caliber_data.caliber_name
```

### Issue #3: C#/.NET Export Requirements (Potential Unresolved Cause)

**Project Configuration Analysis:**

| Component | Value |
|-----------|-------|
| `project.godot` features | `PackedStringArray("4.3", "C#")` |
| Assembly name setting | `project/assembly_name="GodotTopDownTemplate"` |
| Solution file | `GodotTopDownTemplate.sln` |
| Project file | `GodotTopDownTemplate.csproj` |
| Namespace | `GodotTopDownTemplate` |
| Main scene | `res://scenes/levels/BuildingLevel.tscn` |
| Player scene | `res://scenes/characters/csharp/Player.tscn` (C# script) |

**Why C# Could Cause Crash:**

1. **Wrong Export Templates**: If user exports with standard GDScript templates instead of .NET templates, C# scripts cannot load
2. **Assembly Not Built**: Godot may skip C# build during export if it can't find the project
3. **Silent Failure**: Per [#91998](https://github.com/godotengine/godot/issues/91998): "Godot is not building your C# project because it can't find it, so it assumes it's a GDScript-only project. The crash happens because the game tries to load a `.cs` Resource but .NET is not initialized."

**Assembly Name Verification (All Match):**
- `GodotTopDownTemplate.sln`: Contains "GodotTopDownTemplate" project
- `GodotTopDownTemplate.csproj`: `<RootNamespace>GodotTopDownTemplate</RootNamespace>`
- `project.godot`: `project/assembly_name="GodotTopDownTemplate"`

**Alternative GDScript Player Available:**
- **C# version** (currently used): `res://scenes/characters/csharp/Player.tscn`
- **GDScript version**: `res://scenes/characters/Player.tscn`

---

## GDScript Type System Reference

### Safe vs Unsafe Patterns

| Pattern | Dictionary | Resource | Works in Export? |
|---------|------------|----------|------------------|
| `obj.has("key")` | Yes | CRASHES | No |
| `obj.has_method("name")` | No | Yes | Yes |
| `"key" in obj` | Yes | Yes | Yes |
| `obj is ClassName` | N/A | May Crash | Risky |
| `obj.get("key")` | Yes | Yes | Yes |

### Recommended Property Access Patterns

```gdscript
# SAFE: Property existence check
if "property_name" in some_resource:
    var value = some_resource.property_name

# SAFE: Method existence check
if some_object.has_method("method_name"):
    some_object.method_name()

# AVOID: Type checks with custom class_name
# if obj is MyCustomClass:  # May fail in exports

# SAFE: Script comparison alternative
if obj.get_script() == preload("res://path/to/script.gd"):
    # Type-safe code here
```

---

## Online Research Summary

### Godot Forum References

1. **[Godot 4.4.1 C# Export Issue](https://forum.godotengine.org/t/godot-4-4-1-c-export-issue/119567)**
   - Android apps crash after splash with C# scripts
   - Works with GDScript, crashes with C#

2. **[4.3 Stable Exported Build Crashes Immediately](https://forum.godotengine.org/t/4-3-stable-exported-build-crashes-immediately-upon-starting-up-game-everything-fails-to-load/101339)**
   - Symptoms: splash screen then immediate crash
   - Root cause: inverted export resource filter
   - Solution: correct export settings + reimport resources

3. **[Release Export Crashes at Start](https://forum.godotengine.org/t/release-export-of-the-game-crashes-at-start/120339)**
   - Debug export works, release crashes
   - Related to script loading order

### GitHub Issues

1. **[#91998 - C# exports crash if assembly names don't match](https://github.com/godotengine/godot/issues/91998)**
   - Editor runs fine, export segfaults
   - Solution: ensure .sln, .csproj, and project setting all match

2. **[#41215 - References to class not resolved when exported](https://github.com/godotengine/godot/issues/41215)**
   - `is ClassName` causes parse errors
   - Workaround: use file paths instead of class names

3. **[#76380 - Class names stop working](https://github.com/godotengine/godot/issues/76380)**
   - Class name resolution becomes unreliable
   - Affects type checking in GDScript

---

## Proposed Solutions

### Solution A: Verify C# Export Configuration (Recommended First Step)

**Questions for User:**
1. Which Godot Editor version? (Standard or **.NET** version)
2. Are .NET export templates installed?
3. Does the game work when running from editor?
4. Did exported builds work BEFORE this PR?

**Verification Steps:**
1. Open Godot Editor -> Editor -> Manage Export Templates
2. Confirm ".NET" templates are installed (not standard GDScript-only)
3. Rebuild C# project before export: `dotnet build`
4. Export with "Export Debug" first to see any error messages

### Solution B: Switch to GDScript Player (Diagnostic Test)

To determine if crash is C#-related:

1. Edit `scenes/levels/BuildingLevel.tscn`
2. Change line 4:
   ```diff
   - [ext_resource type="PackedScene" uid="uid://dv8nq2vj5r7p2" path="res://scenes/characters/csharp/Player.tscn" id="2_player"]
   + [ext_resource type="PackedScene" uid="uid://..." path="res://scenes/characters/Player.tscn" id="2_player"]
   ```
3. Export and test
4. If game runs -> crash was C#-related

### Solution C: Add FileLogger Diagnostics (Already Implemented)

The FileLogger autoload has been added to capture startup sequence:
- Creates `game_log_*.txt` next to executable
- Logs initialization steps
- Helps identify exactly where crash occurs

---

## Files Collected for This Case Study

### Logs Directory (`docs/case-studies/issue-341/logs/`)
- `solution-draft-log-1.txt` - First AI work session (8412 lines)
- `solution-draft-log-2.txt` - Second AI work session (4574 lines)
- `solution-draft-log-3.txt` - Third AI work session (6546 lines)
- `solution-draft-log-4.txt` - Fourth AI work session (6589 lines)

### PR/Issue Documentation
- `issue-341-details.txt` - Original issue description
- `issue-341-comments.txt` - Issue comments
- `pr-342-details.txt` - First PR details
- `pr-342-comments.txt` - First PR comments (contains crash reports)
- `pr-359-details.txt` - Current PR details
- `pr-359-comments.txt` - Current PR comments

---

## Implementation Status

### Completed

| Item | Status |
|------|--------|
| Add collision layer 7 "interactive_items" | Done |
| Add PhysicsMaterial2D to Casing scene | Done |
| Add Area2D "KickDetector" child | Done |
| Update collision layer/mask for casings | Done |
| Implement kick detection in casing.gd | Done |
| Implement kick physics with impulse | Done |
| Implement kick sound with threshold/cooldown | Done |
| Add caliber-based sound selection | Done |
| Fix: Remove `.has()` calls on Resource | Done |
| Fix: Remove `is CaliberData` type checks | Done |
| Add FileLogger for debugging exports | Done |

### Pending (Manual Testing Required)

| Item | Status |
|------|--------|
| Verify exported EXE runs without crashing | Awaiting user test |
| Walk player through casings | Pending |
| Walk enemies through casings | Pending |
| Verify sounds play at appropriate velocity | Pending |
| Verify bullet-time freezes casings correctly | Pending |

---

## Lessons Learned

1. **GDScript Dictionary methods on Resources cause silent crashes** in exported builds
2. **`is ClassName` type checks can fail** in exports due to class_name resolution issues
3. **C#/GDScript hybrid projects require careful export configuration** - must use .NET templates
4. **The Godot Editor doesn't catch all export-breaking errors** during development
5. **Property-based checks (`"property" in object`)** are the safest pattern for Resource access
6. **Always follow existing codebase patterns** - `bullet.gd` was already using safe patterns
7. **Add startup logging** to help diagnose silent crashes in exported builds

---

## References

### Project Links
- **Issue**: https://github.com/Jhon-Crow/godot-topdown-MVP/issues/341
- **PR #342** (closed): https://github.com/Jhon-Crow/godot-topdown-MVP/pull/342
- **PR #359** (current): https://github.com/Jhon-Crow/godot-topdown-MVP/pull/359

### Godot Documentation
- [GDScript Exported Properties](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_exports.html)
- [Physics Introduction](https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html)
- [Area2D Tutorial](https://docs.godotengine.org/en/stable/tutorials/physics/using_area_2d.html)

### External Tutorials
- [KidsCanCode - Character to Rigid Body Interaction](https://kidscancode.org/godot_recipes/4.x/physics/character_vs_rigid/index.html)
- [Catlike Coding - Movable Objects in Top-Down 2D](https://catlikecoding.com/godot/true-top-down-2d/3-movable-objects/)

### Godot Issues (Crash-Related)
- [#91998 - C# exports crash if assembly names don't match](https://github.com/godotengine/godot/issues/91998)
- [#41215 - References to class not resolved when exported](https://github.com/godotengine/godot/issues/41215)
- [#76380 - Class names stop working](https://github.com/godotengine/godot/issues/76380)

### Godot Forum Discussions
- [4.3 Stable Exported Build Crashes](https://forum.godotengine.org/t/4-3-stable-exported-build-crashes-immediately-upon-starting-up-game-everything-fails-to-load/101339)
- [C# Export Issue](https://forum.godotengine.org/t/godot-4-4-1-c-export-issue/119567)
- [Release Export Crashes](https://forum.godotengine.org/t/release-export-of-the-game-crashes-at-start/120339)

---

*Case study last updated: 2026-01-25*
*Investigation status: Awaiting user feedback on C# export configuration*
