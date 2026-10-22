# External Linux device: feasibility report

Date: 2026-10-22. Phase 7 / deliverable 11 of the project brief. A separate track: it does **not** replace the Roku app, which remains the working implementation.

## Summary

- **Why this report is justified:** a Roku channel cannot replace Roku's home screen, receive the Home button, or launch other channels (`ASSESSMENT.md`). The brief's "complete launcher control" requirement cannot be met on Roku.
- **Finding:** no external device class evaluated here meets the whole brief. Each one forces a trade between three goals:
  1. **Full launcher control**
  2. **Full-quality commercial streaming** (Netflix, Prime Video, Disney+, Hulu at 1080p)
  3. **Privacy** (no platform telemetry)

  | Device class | Launcher control | Commercial streaming | Privacy |
  |---|---|---|---|
  | A. Desktop Linux (Raspberry Pi 5 or mini PC, browser kiosk) | Yes | **No**: DRM caps quality; Hulu unsupported | Yes |
  | B. Linux + Kodi with unofficial add-ons | Yes | **Fragile**: unofficial, can break at any time | Mostly |
  | C. Android TV / Google TV box (Linux kernel, certified) | **Partial**: unofficial override | Yes (with caveats to verify) | **No**: Google telemetry, sponsored rows |

- **Recommendation:** **do not buy hardware yet.** First decide which of the three goals matters least. Then run the pre-purchase checks below on one specific device. Keep using the Roku app meanwhile.

## Method and evidence quality

The official help pages (Netflix, Prime Video, Hulu, Disney+, Google, Roku) could not be opened directly from the build environment, so evidence comes from web-search results that quote them. Each claim is tagged:

- **[Official]**: quoted from the company's own help or support page via search.
- **[Secondary]**: news, reviews or guides.
- **[Community]**: forum posts or user reports.
- **[Unverified]**: conflicting or missing evidence; must be tested.

Streaming policies change often. Recheck every row of the streaming table on the live help pages before any purchase.

## The DRM problem (classes A and B)

Commercial services protect video with Widevine. Desktop Linux browsers get only **Widevine L3** (software-only); HD and above generally need **L1** (hardware-backed) **[Secondary]**. Services cap L3 playback by OS:

| Service | Desktop Linux browser | Evidence |
|---|---|---|
| Netflix | **720p or 1080p: conflicting.** Versions of Netflix's help page list Chrome/Firefox on Linux at 720p; another cached version lists 1080p. Netflix says it can't guarantee Linux and won't troubleshoot it | [Official], [Unverified] |
| Prime Video | **SD only**: playback on operating systems other than Windows or macOS is limited to standard definition | [Official] |
| Disney+ | **480p–720p.** A user reports Disney support confirming deliberate Linux limits, measuring 854×480 | [Community], [Unverified] |
| Hulu | **Not officially supported** on Linux; help pages list Windows, macOS and ChromeOS. Third-party guides say Chrome may work | [Official], [Secondary] |
| YouTube | Mostly not DRM-protected; quality limited by hardware decode (below) | [Secondary] |

**Widevine availability does not equal service support or HD.** That's exactly what the brief warned about, and the table confirms it. Class B (Kodi with unofficial Netflix add-ons) relies on the same L3 module plus unofficial clients. A 2026 guide calls it "fragile, as Netflix updates can break the add-on at any time" **[Secondary]**. Using such add-ons may also conflict with services' terms.

## Evaluation against the brief's checklist

| Criterion | A. Desktop Linux (e.g. Raspberry Pi 5) | C. Google TV box (e.g. Google TV Streamer) |
|---|---|---|
| Netflix, YouTube, Prime, Disney+, Hulu | See the DRM table: only YouTube at full quality | Native certified apps. One spec database lists **Widevine L1 and Netflix and Prime Video certification** for the Google TV Streamer **[Secondary]**. Disney+ and Hulu certification not confirmed **[Unverified]** |
| DRM / certification | L3 only | L1 (listed) |
| Realistic 1080p | Blocked by DRM for most services, not by hardware | Expected, but must be measured per service |
| Hardware decode | Pi 5 has **no H.264 hardware decoder**, only HEVC (up to 4K60). H.264, VP9 and AV1 decode in software, which is fine at 1080p (one test saw an occasional skipped frame at 1080p60 H.264) and stutters at 4K **[Secondary]** | Hardware decode for streaming codecs; 4K60 HDR **[Secondary]** |
| Browser / app support | Chromium + `libwidevinecdm0` on Raspberry Pi OS | Google Play apps |
| Startup into fullscreen UI | Yes: kiosk mode (autologin + fullscreen browser or a native app). Fully controllable | Partial. The usual method, Projectivy's Accessibility "Override current launcher", intercepts Home. A **March 2026 Google TV update broke custom launchers**, which recovered after reconfiguration. A 2025 review says Back can still reach the stock launcher. Disabling the stock launcher via ADB is more durable, but can break the YouTube button and Quick Settings, with a risk of soft-bricking **[Secondary/Community]** |
| OS networking and recovery | Full control (NetworkManager, systemd); the diagnostics from the Roku app could do more here | Android settings only; apps cannot change Wi-Fi |
| OS telemetry controls | None needed: a minimal distro sends nothing you didn't configure | Usage & Diagnostics toggle exists, but Google lists crash logs and diagnostics collection, and IP-based location even with Location off **[Official]**. Sponsored home-screen rows remain in "apps only" mode **[Secondary]**. A replacement launcher hides them but doesn't stop OS collection. **Fails the privacy goal** |
| Roku remote | See next section: unresolved for both | Same |
| HDMI-CEC | Linux `cec-ctl`/libcec can power the TV and switch inputs; navigation pass-through from a Roku TV is undocumented (next section) | Built-in CEC; same Roku TV caveat |
| Cost | Board price not confirmed (Raspberry Pi has raised prices several times since December 2025 **[Secondary]**). Add case, cooler, 27 W supply (~€16 **[Secondary]**), storage, IR receiver | **$149.99** list from 31 August 2026 (was $99.99) **[Secondary]**; remote included |
| Power / thermal | Pi 5 idle ~2.7–3.6 W; 7–8.8 W under load (sources differ); active cooler recommended. **Playback wattage not found** **[Secondary]** | Not found **[Unverified]** |

## Integration with a Roku TV (applies to every option)

The TV keeps running Roku OS. An external box is just an HDMI input.

1. **Booting into the box.** Roku TVs offer *Settings › System › Power › Power on* to start on a chosen HDMI input or the last-used input **[Community, consistent across Roku moderators]**. Some users report it still booting to Roku home, and CEC can interfere. **Test on the target TV.**
2. **The Home button cannot be fixed by any external box.** On a Roku TV, the remote's Home button returns to Roku's home screen and leaves the HDMI input. This is the same limit as the Roku app, moved one level up. **[Unverified on the target TV; expected from Roku TV behavior]**
3. **Using the Roku TV remote to drive the box. Three possible paths, none verified:**
   - **HDMI-CEC pass-through.** Roku documents CEC for power, volume and input switching only. It says CEC "does not allow control of all aspects of every device" **[Official]**. A blog post describes a hidden Roku TV menu option enabling remote keypress forwarding to a Raspberry Pi/Kodi **[Community, old, unverified]**.
   - **Infrared.** Simple Roku remotes are IR and need no pairing **[Secondary]**; voice remotes use Wi-Fi Direct or RF and pair to the TV **[Secondary]**, so they're useless to a box. An IR receiver on a Linux box can decode Roku IR (reported as NECX with two scancodes per press, needing a custom keymap) **[Community]**. **But the TV receives the same IR at the same time**, so every press may also act on the TV (Home certainly would). Behavior while on an HDMI input must be tested.
   - **A separate remote** (the box's own remote, or a USB/Bluetooth keyboard remote) avoids the conflict but drops the "keep the Roku remote" requirement.
4. **Before recommending anything that keeps the Roku remote:** identify the exact remote model (check for a microphone button or a pairing button under the battery cover) and test CEC pass-through on the actual TV.

## Conclusion

| If the lowest priority is… | Then evaluate | You give up |
|---|---|---|
| Commercial streaming quality | **A. Raspberry Pi 5 / mini PC kiosk** running a Linux port of the Amber design | HD on Prime Video, Disney+ and possibly Netflix; Hulu support. Use the TV's built-in Roku apps for those |
| Privacy | **C. Google TV box** with a replacement launcher | Google telemetry and ads in the OS; launcher control that a system update can break |
| Full launcher control | **Stay on Roku** with the Amber app | Home button and direct app launching |

A hybrid is also realistic and cheap to try: keep the Roku app for streaming, and add class A only if the specific missing features (network control, offline media, full UI control) justify a second device.

## Pre-purchase verification checklist

For the one candidate device chosen:

1. Read the live help pages of Netflix, Prime Video, Disney+ and Hulu for that device or OS. Record maximum resolution and support status with dates.
2. For Android/Google TV: confirm Widevine level on the unit (DRM info app) and certification for all five services.
3. On the target Roku TV: test *Power on* to an HDMI input, the Home button while on HDMI, and CEC key pass-through with any CEC device available.
4. Identify the Roku remote model and whether it's IR.
5. For Linux: play each service in Chromium at its maximum and record actual decoded resolution (stats overlay) and dropped frames.
6. Measure idle and playback power at the wall.
7. For Google TV: install the replacement launcher, then check Home, Back, and behavior after a system update.

## Portability of the Roku implementation

The pure logic in `components/lib/` (focus movement, recent ordering, catalog validation, diagnostics classification, settings text) has no Roku-specific dependencies beyond BrightScript syntax. It and the design tokens in `DESIGN.md` port directly to a Linux UI. Rendering, input and networking would be rewritten.

## Sources

- Netflix supported browsers and system requirements: <https://help.netflix.com/en/node/23742>, <https://help.netflix.com/en/node/30081>
- Prime Video system requirements for computers: <https://digprjsurvey.amazon.com/csad/help/node/GUVGB3QMQRYRERYW>, <https://primevideo.com/supported-browsers>
- Disney+ Linux limit report: <https://linustechtips.com/topic/1640895-disney-intentionally-limits-linux-browsers-to-480p-confirmed-by-support-my-investigation/>
- Hulu requirements: <https://help.hulu.jp/hc/en-us/articles/360044688153>; Hulu on Linux: <https://linuxconfig.org/how-to-watch-hulu-on-linux>
- Widevine levels: <https://www.forasoft.com/learn/video-streaming/articles-streaming/widevine-l1-l2-l3>, <https://en.wikipedia.org/wiki/Widevine>
- Raspberry Pi 5 video decode: <https://www.jeffgeerling.com/blog/2024/can-raspberry-pi-5-handle-4k/>
- Raspberry Pi power: <https://raspberry.tips/en/raspberrypi-tutorials/raspberry-pi-power-consumption-update-2026-all-models-compared>
- Kodi/Netflix on Pi: <https://raspberry.tips/en/raspberrypi-tutorials/kodi-raspberry-pi-installieren-bookworm>, <https://pimylifeup.com/raspberry-pi-netflix>
- Google TV Streamer price: <https://www.techrepublic.com/article/news-google-tv-streamer-price-hike-150/>, <https://www.aftvnews.com/google-increases-the-price-of-its-google-tv-streamer-from-99-99-to-149-99/>; DRM listing: <https://www.androidtv-guide.com/?p=16823>
- Google TV launcher replacement: <https://simturax.com/replace-stock-launcher-google-tv/>, <https://www.xda-developers.com/google-tv-bloated-replaced-custom-launcher-actually-works/>, <https://xdaforums.com/t/how-to-disable-google-tv-launcher-install-3rd-party-launcher.4601397/>
- Google TV data handling: <https://support.google.com/googletv/answer/13427970>; usage and diagnostics: <https://www.sony.co.uk/electronics/support/articles/00155797>; sponsored rows: <https://androidcentral.com/how-get-rid-personalized-recommendations-chromecast-google-tv>
- Roku TV power-on input: <https://community.roku.com/discussions/tv-and-players/have-hdmi-stay-on-as-input-when-you-turn-tv-on/973427>, <https://support.getjubileetv.com/how-to-change-power-on-setting-on-tcl-smart-tvs>
- Roku CEC: <https://support.roku.com/article/configure-hdmi-settings-on-your-tv>; CEC pass-through to Kodi: <https://tim.cexx.org/?p=1679>
- Roku remote types: <https://www.digitalcitizen.life/how-to-pair-a-roku-remote-a-step-by-step-guide/>, <https://asurion.com/connect/tech-tips/roku-remote-wont-pair/>; Roku IR decoding on Linux: <https://discourse.coreelec.org/t/help-with-necx-protocol/57936>
