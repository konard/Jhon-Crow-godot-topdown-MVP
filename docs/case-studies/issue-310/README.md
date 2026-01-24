# Case Study: Issue #310 - Grenade Freezing with F8 Debug Logging

## Overview

This case study documents the investigation and resolution of a critical bug where enabling F8 grenade debug logging caused grenades to freeze in place after being thrown, making the debug feature unusable for its intended purpose.

## Quick Summary

**Problem:** Grenade freezes when F8 debug logging is enabled
**Root Cause:** Synchronous disk I/O (flush) executing 60 times per second on main thread
**Solution:** Removed automatic flush() from regular log writes, added flush only for critical events
**Impact:** Eliminated game freezing while preserving complete debug logging capability

## Documents

### [Timeline Reconstruction](analysis/timeline.md)
Complete chronological sequence of events from initial issue report through bug discovery and analysis.

### [Root Cause Analysis](analysis/root-cause-analysis.md)
Deep technical analysis of the bug, including:
- Call stack and code flow
- Performance impact measurements
- External research on file I/O performance
- Proposed solutions with trade-off analysis
- Recommended fix implementation

## Log Files

All user-provided game logs and AI solution draft logs are preserved in the `logs/` directory:

- `game_log_20260124_092318.txt` - First test (F8 not working)
- `game_log_20260124_094610.txt` - Second test (F8 working but freezing game)
- `solution-draft-log-session1.txt` - First implementation attempt (GDScript)
- `solution-draft-log-session2.txt` - Second implementation attempt (C#)

## Key Findings

### Performance Impact

| Metric | Value |
|--------|-------|
| Physics FPS | 60 frames/second |
| Disk flush operations during one grenade aim | 48-60 |
| Frame budget at 60 FPS | 16.67 ms |
| Typical flush time (HDD) | 10-200+ ms |
| **Result** | Game completely freezes |

### Code Changes

**Primary Fix:**
- `scripts/autoload/file_logger.gd:108` - Removed automatic `flush()` from regular logging
- Added manual `flush()` method for critical events

**Secondary Improvements:**
- `scripts/autoload/file_logger.gd:131` - Auto-flush after error logs
- `scripts/autoload/file_logger.gd:93` - Flush on game shutdown
- `scripts/autoload/game_manager.gd:168` - Flush when F8 is toggled OFF

## Lessons Learned

1. **I/O Performance Matters:** File operations are orders of magnitude slower than memory operations
2. **Never Flush Every Write:** Standard practice is to batch and buffer writes
3. **Test in Production Environment:** Fast SSDs mask I/O performance issues
4. **Profile Performance-Critical Code:** Use profiler for code running in physics loop
5. **Debug Features Should Degrade Gracefully:** Don't let debug code break production functionality

## References

- **Issue:** https://github.com/Jhon-Crow/godot-topdown-MVP/issues/310
- **Pull Request:** https://github.com/Jhon-Crow/godot-topdown-MVP/pull/311
- **Branch:** `issue-310-245e3e4ca1f3`

## Related Research

- [fsync() on a different thread: apparently a useless trick](http://oldblog.antirez.com/post/fsync-different-thread-useless.html)
- [Synchronous and Asynchronous I/O - Microsoft Learn](https://learn.microsoft.com/en-us/windows/win32/fileio/synchronous-and-asynchronous-i-o)
- [Don't fear the fsync! - Theodore Ts'o](https://thunk.org/tytso/blog/2009/03/15/dont-fear-the-fsync/)
