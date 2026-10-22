# Amber for Linux (mini PC)

Turns a mini PC into a quiet TV box. It boots straight into the black-and-amber Amber launcher, with no desktop, no ads, no animations and no telemetry from Amber. Plug it into the TV's HDMI input and set the TV to power on to that input.

> **Status: tested in a container and a headless browser, not yet on a mini PC.** What was verified is listed under [Testing](#testing). The installer, sway session, Chromium DRM and remote behavior have not run on real hardware yet.

## How it works

```
power on → Debian boots → autologin on tty1 → sway (fullscreen, no bar)
         → amber-session → local server (127.0.0.1:8484) + Chromium showing the launcher
select a tile → a second fullscreen Chromium opens that site on top
press Home    → that window closes → you're back on the launcher
```

| Piece | What it is |
|---|---|
| `server/` | Python 3 standard library only. Serves the UI and a small local API: network status, diagnostics, launch, restart network, reboot, power off |
| `ui/` | The launcher: same layout, colors and remote behavior as the Roku app, in plain HTML/CSS/JS. No frameworks, no external files |
| `bin/` | `amber-session` (starts everything, restarts the launcher if it closes), `amber-play` (opens a site), `amber-home` (closes it) |
| `sway/config` | Kiosk window manager: every window fullscreen, Home key bound to `amber-home`, nothing else |
| `chromium/policies.json` | Turns off Chromium metrics, sync, sign-in, search suggestions, translation, ad features and more |
| `install.sh` | Sets all of this up on Debian 13 |

What Linux can do that Roku couldn't:
- **Real launcher control.** The box boots into Amber, and Home always comes back to it.
- **Tiles actually open the services.** They open each service's website, not a store page.
- **Network control.** The box can restart its own networking, and diagnostics test the router and name lookup directly.
- **Power.** Restart and shut down the box from Settings, with a second OK to confirm.

## What you give up

From [the feasibility report](../docs/LINUX_FEASIBILITY.md):

| Service | On Linux (via website) |
|---|---|
| YouTube | Full quality (not DRM-limited) |
| Netflix | 720p or 1080p: Netflix's own pages conflict |
| Prime Video | **SD only** (Amazon's stated policy for Linux) |
| Disney+ | Up to 720p, reportedly 480p |
| Hulu | Not officially supported; may work |

These caps come from the services, not from Amber, and every tile shows its own. They're [unverified] until tested on your box. Watching these at full quality means using the TV's own Roku apps.

## You'll need

- **The mini PC**: x86-64 (Intel or AMD) with Wi-Fi or Ethernet. The installer assumes x86-64 Debian; ARM boards aren't tested.
- **A USB stick** for the Debian installer. Installing Debian **erases the mini PC's disk**.
- **A remote that acts like a keyboard.** Recommended: a USB "air mouse" remote (2.4 GHz dongle) with arrow keys, OK, Back, Home and a gyro pointer. The pointer matters: the streaming websites are built for a mouse, and arrow keys alone won't get around all of them. The Roku TV's remote **won't** control the box (see the feasibility report). HDMI-CEC needs a separate USB adapter on most mini PCs and is untested.
- **A USB keyboard** for setup.

## Install

1. **Install Debian 13** from the official netinst image (debian.org).
   - At *Software selection*, **untick** "Debian desktop environment" and every desktop.
   - Tick **SSH server** (optional, for admin) and **standard system utilities**.
   - Create your own admin user when asked. Don't name it `amber`.
2. **Get Amber onto the box.** Log in on the console as your admin user, then:
   ```sh
   sudo apt install git
   git clone https://github.com/IgunnerI/Roku-Tv-OSUpgrade.git
   ```
3. **Run the installer** from the console, not over SSH, because networking moves to NetworkManager:
   ```sh
   sudo sh Roku-Tv-OSUpgrade/linux/install.sh
   ```
4. **On Wi-Fi?** Run `sudo nmtui` → *Activate a connection* → pick your network. Wired works automatically.
5. **Reboot:** `sudo systemctl reboot`. The box should start straight into Amber.
6. **On the TV:** *Settings › System › Power › Power on* → the HDMI input the box is on.

**Admin access later:** press **Ctrl+Alt+F2** on a keyboard and log in as your admin user, or use SSH. **Ctrl+Alt+F1** returns to Amber.

**Updates:** `cd Roku-Tv-OSUpgrade && git pull && sudo sh linux/install.sh`, then reboot.

## Keys

| Key | Launcher | Streaming window |
|---|---|---|
| Arrows | Move focus | Site's own behavior |
| OK / Enter | Open | Site's own behavior |
| Back / Esc / Backspace | Close the menu or Settings | Browser back |
| ☰ Menu (or `M`) | Open the menu | — |
| Home | — | **Close the site, return to Amber** |

## Privacy: who the box talks to

| Traffic | When | Controlled by |
|---|---|---|
| Amber launcher | **Nothing**, except the diagnostics check when you run it (HEAD requests to `connectivitycheck.gstatic.com`, then `www.msftconnecttest.com`) | Amber. Enforced by tests |
| Streaming sites | While you use them, including their own analytics | The services. Out of Amber's control |
| Chromium | Safe Browsing list updates; the component updater, which downloads the Widevine DRM module from Google. Metrics, sync, suggestions, translation and ad features are off by policy | `chromium/policies.json`. Setting `ComponentUpdatesEnabled: false` would break DRM playback |
| Debian | Package updates (`deb.debian.org`) and time sync (`debian.pool.ntp.org`, needed for secure connections) | Debian. Neither sends usage data. `popularity-contest`, Debian's only opt-in usage reporter, is removed |
| NetworkManager | No connectivity checks: Debian's check config isn't installed | — |

The launcher keeps only the Recent list (in its browser profile) and diagnostics results (in memory). Settings › Privacy › *Clear all local data* removes both. Streaming logins live in the player profile at `~amber/.local/state/amber/player`.

The Chromium policy blocks third-party cookies. If a service's sign-in fails, remove `"BlockThirdPartyCookies": true` from `/etc/chromium/policies/managed/amber.json` and restart.

## Testing

Run from the repository root:

```sh
python3 -m unittest discover -s linux/tests      # server, diagnostics, security, privacy audit
node --test linux/tests/ui-lib.test.mjs          # focus, recent, settings logic
node linux/tests/e2e.mjs                         # real server + launcher in headless Chromium (needs Playwright)
```

| Verified here (2026-10-22) | Result |
|---|---|
| 21 Python tests: diagnostics verdicts, retry and backoff bounds, route parsing, API security (foreign Host rejected, POST needs the custom header, launches limited to the catalog, actions allowlisted, path traversal blocked), source privacy audit, Chromium policy | Pass |
| 4 Node tests: focus rules (exhaustive range check), Recent, Settings sections, power confirmation | Pass |
| End-to-end in headless Chromium: 8 tiles, one focus ring, D-pad paths, drawer, Settings and Back with focus restored, launch command, two-step shut down, clear Recent, 720p scaling, **zero requests outside the local server**, no page errors | Pass |
| Live network code on a real Linux kernel: link, address, router and netlink change events detected; real diagnostics correctly reported a name-lookup failure in 2 s | Pass |
| Shell and Python syntax | Pass |

**Not yet verified (needs your mini PC):** `install.sh` on Debian 13; sway, autologin and the Home binding; Widevine in Debian's Chromium (if it doesn't download, the fallback is Google Chrome, which brings more Google services); actual streaming resolutions; video smoothness and hardware decode for your GPU; your remote's key codes; power use.

## Undo

```sh
sudo rm /etc/systemd/system/getty@tty1.service.d/amber-autologin.conf
sudo rm /etc/chromium/policies/managed/amber.json
sudo rm -rf /opt/amber
sudo userdel -r amber
# If install.sh moved your network config:
sudo mv /etc/network/interfaces.amber-backup /etc/network/interfaces
sudo systemctl reboot
```
