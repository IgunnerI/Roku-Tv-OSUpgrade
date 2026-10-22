# Performance report

## Measured results

**None.** No Roku hardware was available, so no startup time, frame time or memory figure has been measured. Nothing in this repository should be read as a performance claim.

## What the design does for performance

| Concern | Approach |
|---|---|
| Node count | Under 100 nodes total (12 tiles × 4 nodes, plus the drawer and Settings). All created once at startup and reused |
| Per-key work | One pure function call plus at most 12 boolean field writes (tile focus). No node creation, no layout rebuild, no I/O |
| Rendering cost | Opaque rectangles and system-font labels only. No images in the UI, no alpha, no animations, no MarkupGrid/RowList |
| Startup | No network at startup. The catalog is a 0.7 KB local JSON file. One registry read. The installed-app check runs in a Task after the first layout |
| Threads | Network checks and `roAppManager` calls run on Task threads. The render thread never waits on I/O |
| Idle | Zero work: no timers, no clock, no polling. The link monitor sleeps in `wait(0)` until Roku sends an event |
| Memory bounds | Recent ≤ 4, diagnostics history ≤ 4, one in-flight request. No growing arrays or caches |
| Package size | About 20 KB |

## How to measure (on the oldest available target)

1. Record the model (`Settings › System › About`), Roku OS version and UI resolution in the table below.
2. **Startup:** launch from Roku home and time it to the first frame with tiles (a stopwatch, or a phone video at 60 fps). Repeat 5 times after a TV restart and record the median.
3. **Navigation:** hold Right/Down for 30 s; look for skipped focus steps or lag. Use the SceneGraph debug console (`telnet <tv-ip> 8080`, command `chanperf`) for CPU and memory while navigating.
4. **Memory growth:** run `chanperf` and `sgnodes all` at the start and after 10 minutes of navigation and 50 Settings round-trips. Node count should stay constant.
5. **Slow network:** repeat step 3 during test N4 from `TEST_PLAN.md`.

| Device | Roku OS | UI | Startup | Held D-pad | Memory start → 10 min | Nodes start → end |
|---|---|---|---|---|---|---|
| _not yet measured_ | | | | | | |

The 16 ms per-event target can't be confirmed without on-device profiling. If a target is missed, record the figure here before changing code.
