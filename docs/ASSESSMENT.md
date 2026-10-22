# Repository and platform assessment

Date: 2026-10-22. Phase 1 of the project brief.

## Repository state at start

- Empty git repository: no commits, no files, no README, no build scripts, no tests. The remote (`IgunnerI/Roku-Tv-OSUpgrade`) had no branches.
- No target device, Roku OS version, or remote model was documented.
- Conclusion: a new project. Nothing existing was overwritten.

## How API facts were checked

`developer.roku.com` could not be reached from the build environment (DNS failure), so the live documentation was **not** read. API signatures were checked against the machine-readable copy of Roku's BrightScript/SceneGraph reference shipped inside BrighterScript 0.65.27 (`roku-types/data.json`, generated 2022-11-02 from developer.roku.com). That source is the official reference, but it is a 2022 snapshot. Anything marked "convention" below comes from general Roku development practice and was not confirmed against either source.

The code was also validated with the BrighterScript compiler (`npm run lint`), which checks BrightScript syntax, scope and SceneGraph XML against the same reference.

## Capabilities

| Capability | API | Status |
|---|---|---|
| Static SceneGraph UI (Scene, Group, Rectangle, Label, Task) | SceneGraph nodes | In reference; lint-validated |
| Key handling for D-pad, OK, Back, Options (`*`) | `onKeyEvent` | Convention: key names `up/down/left/right/OK/back/options` |
| Home button | — | **Not delivered to channels.** Always returns to Roku's home screen |
| Detect whether a channel is installed | `roAppManager.IsAppInstalled(channelID, version)` | In reference. Passing `""` as the version is an assumption |
| Open a channel's Channel Store page | `roAppManager.ShowChannelStoreSpringboard(channelID)` | In reference |
| **Launch another channel** | — | **No such API in the reference.** `ifAppManager` has no `LaunchApp` |
| Link status and connection type | `roDeviceInfo.GetLinkStatus()`, `GetConnectionType()` | In reference. Return strings `WiFiConnection` / `WiredConnection` / `""` are convention |
| Local IP, network name | `GetIPAddrs()`, `GetConnectionInfo()` | In reference. The `ssid` key is convention, so it's read defensively |
| Link-change events (no polling) | `EnableLinkStatusEvent(true)` → `roDeviceInfoEvent` | In reference (Roku OS 8+) |
| Bounded HTTP checks | `roUrlTransfer.AsyncHead()`, `AsyncCancel()`, `wait(timeout, port)` | In reference. **No timeout setter exists**; the timeout is enforced with `wait` + `AsyncCancel` |
| DNS diagnosis | — | No DNS API. Inferred from response code `-6` (convention: negative codes are negated libcurl errors) |
| Local persistence | `roRegistrySection` | In reference |
| Device and OS info | `GetModelDisplayName()`, `GetOSVersion()`, `GetUIResolution()` | In reference. `GetOSVersion` min-OS not confirmed; we assume Roku OS 11+ |

## Unsupported assumptions in the brief, and what was done instead

| Request | Reality on Roku | Closest supported alternative (implemented) |
|---|---|---|
| Replace the Roku home screen / launcher | Not possible for a channel | A channel that looks and behaves like a home screen once opened |
| Override the Home button | Not delivered to channels | Documented; Home always exits to Roku |
| Launch Netflix, YouTube, etc. from tiles | No documented in-channel launch API | Tiles open that channel's **Channel Store page**, where the user can start it. Shown as "Store page" on the tile and in a message. Never presented as a launch |
| Observe recently used apps | Not exposed | "Recent" lists tiles selected **inside this launcher**, stored locally, with a clear option |
| Change Wi-Fi or restart network services | No API | Read-only status plus guided steps in Roku's own menus |
| Make the TV telemetry-free | Roku OS and other channels are out of scope | The app itself sends nothing except the user-triggered diagnostics check |

### Rejected: ECP self-launch

Some channels launch others by sending `POST http://localhost:8060/launch/<id>` to Roku's External Control Protocol (ECP). ECP is documented for **external** devices such as phone apps. Its availability from inside a channel depends on a user network-access setting, and it's not a supported channel API. The brief forbids unsupported HTTP calls, so this was not implemented. The privacy audit fails the build on any POST.

## Application launching: per-tile classification

| Tile | Classification | Behavior |
|---|---|---|
| Netflix, YouTube, Prime Video, Disney+, Hulu | **Unsupported launch** → falls back to a Store page | Opens the Channel Store page. The tile shows "Installed" or "Not found" from `IsAppInstalled` |
| Network check, Privacy, Settings | Supported in-app navigation | Opens that Settings section |

The channel ids (`12`, `837`, `13`, `291097`, `2285`) are widely published but **unverified** for this project. If an id is wrong, the tile reads "Not found" and the Store page may show a different channel or nothing. Check them on the target TV via ECP `GET http://<tv-ip>:8060/query/apps` from a computer on the same network, then edit `data/catalog.json`.

## Remote buttons

| Button | Handled by app? |
|---|---|
| Up / Down / Left / Right / OK | Yes |
| Back | Yes in drawer and Settings. On the home screen it is left unhandled, so Roku closes the app (standard behavior) |
| `*` (Options) | Yes: opens and closes the drawer |
| Home | No: Roku system |
| Power, volume, mute, input | No: TV/system |
| Voice, app shortcut buttons (e.g. a Netflix button) | No: Roku system |
| Play/Pause, Rewind, Fast-forward, Replay | Delivered to the app (convention) but unused |

None of this was tested on a remote. Compatibility with specific remote models is unverified.

## Decisions and assumptions

- **Target:** Roku TVs on Roku OS 11 or later (assumption, since no device was specified). FHD UI coordinates (`ui_resolutions=fhd`, 1920×1080); Roku scales for HD devices.
- **No components beyond the base set:** no MarkupGrid or RowList (they animate focus), no Animation nodes, no Poster images in the UI, no fonts beyond system fonts.
