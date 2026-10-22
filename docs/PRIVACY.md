# Privacy

## What the app sends

| When | Destination | Request | Why |
|---|---|---|---|
| Only when the user selects **Run check** in Diagnostics | `http://connectivitycheck.gstatic.com/generate_204` (Google) | HEAD, no body, no identifiers added by the app | Connectivity test; expects HTTP 204 |
| Only if the first fails | `http://www.msftconnecttest.com/connecttest.txt` (Microsoft) | HEAD | Second, independent test; expects HTTP 200 |

At most 2 attempts per destination. Nothing is sent at startup, while idle, or during navigation.

Plain HTTP is deliberate: it's the only way to detect a hotel or guest-Wi-Fi sign-in page. Both operators can see the TV's public IP address and Roku's default `User-Agent` (which names the platform). Roku OS may add its own headers to requests; confirm with a traffic capture (see `TEST_PLAN.md`).

## What the platform does on the app's behalf

- `ShowChannelStoreSpringboard` opens Roku's Channel Store, which talks to Roku's servers. That is Roku OS traffic, triggered only when the user selects a store tile.
- `IsAppInstalled` is a local query (assumed; not traffic-verified).

## What is stored

| Data | Where | Lifetime | How to clear |
|---|---|---|---|
| Recent tiles (up to 4 ids from `data/catalog.json`) | Roku registry, section `launcher` | Until cleared or the app is removed | Settings › Recent apps › Clear, or Settings › Privacy › Clear all |
| Diagnostics results (last 4 verdicts) | Memory only | Until the app closes | Settings › Diagnostics › Clear results, or Privacy › Clear all |

Network name and IP address are shown on screen in Settings › Network but are never stored, logged or sent. The app has no `print` logging.

## What is not included

No analytics, ad, or crash-reporting SDKs; no Roku Advertising Framework; no component libraries; no device or advertising identifiers; no sockets; no POST requests; no update checks. `npm run audit:privacy` checks for all of these and fails the build if found.

## Scope

This covers this app only. Roku OS, the Channel Store and other channels collect their own data, which this app cannot see or stop. Roku offers some controls under Settings › Privacy on the TV.
