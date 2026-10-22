# Known limitations and next steps

## Platform limits (cannot be fixed in a Roku channel)

1. **Not the system home screen.** The user opens Amber like any channel. Roku's home screen still appears at power-on and whenever Home is pressed.
2. **Cannot launch other channels.** Store tiles open the Channel Store page, so starting an app takes one extra step.
3. **Recent only knows about this launcher.** Usage inside other channels isn't visible.
4. **No network control.** Status and guidance only; changes happen in Roku Settings.
5. **Device-wide telemetry is out of scope.** Only this app's own traffic is controlled.

## Unverified (needs a device)

- Every on-device test in `TEST_PLAN.md`, all performance figures, and remote-model compatibility.
- Channel ids in `data/catalog.json`, and `IsAppInstalled(id, "")` with an empty version.
- Whether `ShowChannelStoreSpringboard` works from a Task thread (assumed) and what happens on Back from the Store.
- Return values assumed by convention: connection-type strings, the `ssid` key, negative curl response codes, and that `GetOSVersion` values support `ToStr()`.
- Font sizes and text fit (long Settings text may truncate), and HD-device scaling.

## Next steps, in order

1. Sideload on the oldest available Roku TV. Run F1–F10, N1–N8 and R1–R3, and fill in `PERFORMANCE.md`.
2. Verify channel ids with ECP `query/apps` and update the catalog. Add tiles only for verified ids.
3. Fix anything the device run finds before adding features.
4. Optional, small: let the user reorder or hide tiles (stored locally).
5. Phase 7 decision. Requirement 9 ("complete launcher control") is now **confirmed impossible** on Roku by the platform limits above. If that control is essential, the next step is the separate Linux feasibility report. It should evaluate a specific device against the brief's checklist (DRM/Widevine level and actual service certification, 1080p playback per service, hardware decode, remote model and connection method, HDMI-CEC, kiosk boot, OS telemetry, cost, power). It was not written now because it needs real device candidates and the Roku prototype's on-device results to compare against. Recommending hardware without them would be guesswork.
