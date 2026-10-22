# Test plan and results

Status key: **Pass** = run and passed here. **Not run** = needs a Roku device or emulator; none was available.

No Roku hardware, emulator or remote was available while building this. Everything below that touches the screen, the remote, the network stack or performance is **unverified**.

## Automated (off-device): run with `npm run check`

| Check | Tool | Result (2026-10-22) |
|---|---|---|
| BrightScript syntax, scope, SceneGraph XML | BrighterScript 0.65.27 `bsc` | Pass, 0 diagnostics |
| Focus movement: every key from every grid/recent position stays in range; edges; shorter last row; up/down between sections; Left at column 0 opens the drawer; clamping after Recent is cleared | `brs` 0.45 interpreter, `tests/test_focusnav.brs` | Pass |
| Recent ordering: move-to-front, no duplicates, bounded at 4, unknown ids dropped | `tests/test_recent.brs` | Pass |
| Catalog: shipped file fully valid, unique ids, bad JSON → empty, unknown `kind` (e.g. `launch`) rejected | `tests/test_catalog.brs` | Pass |
| Diagnostics: response-code mapping, retry rules, verdicts (disconnected, no address, DNS, timeout, intercepted, unreachable, unknown, online), no verdict claims the internet is definitely down, worst-case duration ≤ 20 s | `tests/test_diagnostics.brs` | Pass |
| Settings content: every section renders, ≤ 2 buttons, no re-run while running, history shown | `tests/test_settings.brs` | Pass |
| Privacy source audit, including a negative test with a planted analytics URL and identifier call (both caught) | `scripts/privacy-audit.mjs` | Pass |
| Design tokens only | `scripts/token-audit.mjs` | Pass |

Total: 138 assertions, 0 failures. `brs` doesn't implement SceneGraph rendering, so component behavior is tested only through the pure functions it calls.

## On-device: Not run

### Functional
| # | Test | Expected |
|---|---|---|
| F1 | Cold start | Home renders black with 8 tiles; first tile has an amber ring; Recent shows its empty message |
| F2 | Focus on every tile | Each tile shows the ring; exactly one ring on screen |
| F3 | D-pad across the grid, including edges and the shorter row | Matches the unit-tested rules; focus never disappears |
| F4 | `*`, or Left at column 0 | Drawer appears instantly; tile rings hidden; Back, Right or `*` closes it with focus restored |
| F5 | Drawer → Settings → Back | Settings, then home with the same tile focused |
| F6 | Select Netflix | Channel Store page opens (or nothing, if the id is wrong); message line explains; tile added to Recent |
| F7 | Back from the Store page | Returns to the launcher with focus intact (**unknown**; record behavior) |
| F8 | Settings › Recent apps › Clear | Recent empties; focus moves to the grid if it was in Recent; survives restart |
| F9 | Back on home | App closes to Roku home |
| F10 | Unplug network while in Settings | Settings stays navigable; status updates to Offline |

### Network
| # | Test | Expected verdict |
|---|---|---|
| N1 | Ethernet unplugged or Wi-Fi off | "Not connected to a network"; header shows amber Offline |
| N2 | Reconnect | Header returns to Wi-Fi/Wired without user action (link event) |
| N3 | Router DNS pointed at a dead server | "Possible DNS problem" |
| N4 | Router blocks both test hosts (drop) | "Test destinations timed out" after ≤ 18 s; D-pad stays responsive throughout |
| N5 | Router rejects both hosts (reset) | "Local network OK, test destinations unreachable" |
| N6 | Captive-portal network | "Unexpected response" |
| N7 | Run check repeatedly | No overlap: button reads "Checking…" while busy; history keeps 4 entries |
| N8 | Clear results during a run | History empties at once; the running check still finishes and shows only its own result |

### Performance (see `PERFORMANCE.md`)
P1 startup time; P2 30 s of held D-pad; P3 10 minutes of navigation while watching memory; P4 enter/exit Settings 50 times; P5 navigation during N4.

### Privacy
| # | Test | Expected |
|---|---|---|
| R1 | Capture the TV's traffic (router mirror port, or a laptop hotspot with Wireshark) during cold start, 5 minutes idle, navigation, and Settings | No requests attributable to the app |
| R2 | Same capture while running diagnostics | Only HEAD requests to the two documented hosts; inspect headers for anything Roku adds |
| R3 | Clear all, restart the app | Recent empty, no diagnostics history |

Roku OS traffic will appear in any capture. Tell it apart by timing (it isn't triggered by app actions) and by destination (Roku domains), and compare against a capture with the app closed.
