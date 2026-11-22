# 17 — Selectable Sonos output (showercast)

The panel can now send whatever it is playing — **including DRM apps** (YouTube, Netflix,
Apple TV) — to a Sonos/UPnP renderer as an *added* sound output, while the panel's own amp
stays primary. The output is **selectable**, not hardcoded: the stock default is the local
amp with zero added footprint, so other people running this firmware are unaffected until
they opt in.

Source lives in [`apps/showercast/`](../apps/showercast/) (Kotlin, platform-signed). This
page is the record of what was built, why, and how it was proven.

---

## Why

The TT10V2's ceiling amp is damaged (see [14-hydrovive-recovery](14-hydrovive-recovery.md));
while that is being fixed we want the panel's audio out a working speaker. A Sonos Play:5
(Atrium, `10.0.1.179`) is on the same LAN. Two constraints shaped the design:

1. **DRM must work.** The user runs YouTube, Netflix and Apple TV on the panel. Per-app
   capture (`AudioPlaybackCapture`) returns *silence* for Widevine/Netflix/Apple-TV content.
   Only the post-mix bus carries everything.
2. **It must be pluggable.** Other units run this firmware and do not want a Sonos stream
   hardwired into them. The feature has to be opt-in, default-off, and reversible.

## The two legs

### Capture — `REMOTE_SUBMIX`, platform-signed

`AudioRecord` with source **`REMOTE_SUBMIX`** (not `AudioPlaybackCapture`). `REMOTE_SUBMIX`
is the post-mix bus and carries every app's audio, DRM included. It requires
`CAPTURE_AUDIO_OUTPUT`, which only a **platform-signed** APK gets (same cert as
framework/systemui/settings); a debug-signed APK is permission-denied. The build signs with
the device's platform key (passphrase `android`); the key file is never committed — see
`apps/showercast/build.sh`.

Capture runs at 48 kHz stereo, applies a gain (default ×24; the submix runs hot-low, raw
peaks ~570) and a **tanh soft-limiter** instead of a hard clamp — clamping square-waves loud
passages into noise, whereas with a limiter `peak≈32767` is expected, not a fault.

### Transport — UPnP + endless chunked WAV

Stream the captured PCM to the renderer by pulling an **endless chunked WAV** from a local
HTTP server (`:8090`), driven by two SOAP calls to the renderer's
`:1400/MediaRenderer/AVTransport/Control`: `SetAVTransportURI` (DIDL
`protocolInfo=http-get:*:audio/wav:*`) then `Play`.

We pivoted away from AirPlay 2: Sonos discards NTP-timed audio and bare-IP PTP yields zero
exchanges, so AP2 was silent. UPnP+WAV is boring, robust, and DRM-safe (it moves the same
captured bytes). Non-negotiables that cost real debugging time:

- **Serve `Transfer-Encoding: chunked`, never a fake `Content-Length`.** A huge length
  (e.g. `0xFFFFFFFF`) is rejected; a finite one plays only to EOF.
- **WAV header is exactly 44 bytes**, with `audioFormat`/`channels`/`blockAlign`/
  `bitsPerSample` as 2-byte shorts. Wrong width → 52-byte header → Sonos validates and RSTs
  within ~30 ms.
- **Smoothness = a fixed wall-clock tick, not proportional sleep.** Emit exactly one
  fixed-size slice per fixed interval of *real* time: advance an absolute deadline,
  `sleep(deadline − 5ms)` then busy-spin to the exact deadline, zero-pad any shortfall.
  Proportional pacing jitters every iteration → underruns on a tight-buffered renderer →
  audible chop. Keep the ring topped up with ~25 ms capture batches, not large lumps.
- **Fire-once control, not polling.** Send `SetAVTransportURI`+`Play` once; re-send only
  after the client has been gone >~15 s. Repeatedly re-sending the URI nudges the renderer's
  volume and churns the app.

## Pluggable-sink architecture

```
CaptureEngine  (REMOTE_SUBMIX @48k stereo → gain × tanh → RingBuffer)
      │
      └──► sinks (each implements AudioSink):
             • LocalPassthroughSink  id="local"   default, no-op (today's behaviour)
             • SonosSink            id="sonos"   :8090 chunked WAV + UPnP fire-once
```

- `AudioSink` — contract: `id`, `label`, `start(ring)`, `stop()`.
- `RingBuffer` — single-producer / multi-consumer live ring (4 s of PCM).
- `CaptureEngine` — generic capture core; starts **only** when a real sink needs audio.
- `ShowerCastService` — thin orchestrator: resolves the selected sink(s) from prefs (or
  intent extras), runs the engine only if needed, hands the shared ring to each sink.
- `BootActivity` — on-panel UI: pick Local/Sonos, set host + gain, START/STOP.
- `BootReceiver` — on boot, starts the service **only** if a non-local sink was chosen.

Selection is stored in SharedPreferences (`sel`/`host`/`gain`); `--es sinks` on the start
intent overrides it for one run. `sinks` accepts a comma list (`local,sonos`) so both run
together — the local amp always keeps playing because `REMOTE_SUBMIX` is a tap, not a
reroute.

## Default-off guarantee

- **`local` (default):** `LocalPassthroughSink` is a no-op. No capture thread opens, no
  socket binds, no CPU. The panel behaves exactly as stock. Verified: after starting with
  `sinks=local`, `:8090` is not listening and no capture log appears.
- **Boot:** `BootReceiver` reads the persisted selection and stays dormant unless it
  contains `sonos`. So a unit that never opens the UI adds nothing after reboot.
- **Other users:** untouched. They keep the local default; the Sonos path exists but is
  inert until explicitly selected.

## Verification (all three DRM apps)

Proven on the Atrium (`RINCON_5CAAFD094F4A01400`, fw 86.11):

| App | Result |
|---|---|
| Tone probe (440 Hz) | Plays cleanly through the Atrium — transport `PLAYING`, `clients=1`. |
| YouTube (DRM) | Varying non-zero capture peaks (~5–18 k post-gain), `clients=1`, audible. |
| Netflix (DRM) | PlayerActivity audio captured, `clients=1`, audible. |
| Apple TV (DRM) | Signed in as Justin Wood; trailer audio flowing, `clients=1`, audible. |

The refactor was re-verified without touching the Atrium: started with `sinks=sonos`
pointed at an unreachable dummy host → capture opened, `:8090` bound and served a valid
RIFF/WAVE/chunked stream (PCM, 2 ch, 48 kHz, 16-bit), and the control loop failed
gracefully against the dummy (`fire err Failed to connect`). Stopping the service closed
`:8090` fully.

## adb recipes

```sh
adb install -r showercast-platform.apk
adb shell pm grant com.ghost.showercast android.permission.POST_NOTIFICATIONS

# route to the Sonos (host = the renderer's IP; gain near full scale ≈ 24)
adb shell am start-foreground-service -n com.ghost.showercast/.ShowerCastService \
    --es sinks sonos --es host 10.0.1.179 --ef gain 24

# back to stock local-only behaviour
adb shell am start-foreground-service -n com.ghost.showercast/.ShowerCastService \
    --es sinks local

# stop everything (closes :8090, stops the renderer)
adb shell am force-stop com.ghost.showercast

# watch it
adb shell logcat -s airvia:V
```

Or drive the on-panel UI: open `com.ghost.showercast/.BootActivity`, choose the output,
set host/gain, tap START.

## Getting into a playing state (per-app)

These are webview/native entry points that do **not** resolve launcher intents; drive them
by explicit component + touch/vision:

- Netflix: `am start -n com.netflix.mediaclient/.ui.launch.UIWebViewActivity`
- Apple TV: `am start -n com.apple.atve.androidtv.appletv/com.apple.android.tv.MainActivity`
  (sign-in is hamburger → Apple Account → Sign In → Continue with Email; a locked Apple ID
  is a hard stop — see the skill `android-audio-to-sonos` → `app-launch-and-signin`).

## Durability: `/data` vs baked into the image

Installing to `/data` (as above) works immediately but is lost on factory reset. For a
durable install the APK is baked into the vendor partition and the image rebuilt
metadata-preserving (extract EROFS → add `vendor/app/ShowerCast/` → rebuild with the original
salt → re-sign `vbmeta` → `avbtool verify_image`), per [`build/README.md`](../build/README.md).
The built `.apk` and the resulting `vendor.img`/`vbmeta` are shipped as release assets, not
committed here.

## Status

- Refactor to pluggable sinks: **done, built, installed, verified in both modes.**
- Documentation + source in this repo: **this commit.**
- Baked vendor image + release assets: see the release for this branch.
- Flashing the baked image to the sole surviving panel: **gated** — requires a verified
  rollback image and the U-Boot recovery hook proven on this unit first
  ([15-recovery-plan](15-recovery-plan.md)). Not done unilaterally.
