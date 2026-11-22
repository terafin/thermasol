# showercast — selectable Sonos output for the TT10V2 panel

Routes whatever the panel is playing (YouTube, Netflix, Apple TV, …) to a **Sonos/UPnP
renderer as an *added* sound output**, while the panel's own amp stays primary. One
mechanism covers every app because it captures the post-mix submix (`REMOTE_SUBMIX`),
not per-app streams — so DRM titles work too.

See [`docs/17-showercast-selectable-output.md`](../../docs/17-showercast-selectable-output.md)
for the full write-up: why it exists, the architecture, verification evidence, and the
adb recipes.

## Why it is pluggable (and default-off)

Other people run this firmware. The app must therefore be **opt-in**: the stock default
is `local` (the panel plays through its own amp exactly as before, with **zero added
footprint** — no capture thread, no socket, no CPU). Only when a user selects the `sonos`
output does the app open the submix and start serving. Boot auto-start honours the same
selection, so untouched units stay dormant after reboot.

## Architecture

```
CaptureEngine  (REMOTE_SUBMIX @48k stereo → gain × tanh soft-limit → RingBuffer)
      │
      └──► sinks (each implements AudioSink):
             • LocalPassthroughSink  id="local"   default, no-op (today's behaviour)
             • SonosSink            id="sonos"   :8090 chunked WAV + UPnP fire-once
```

- `AudioSink` — the contract: `id`, `label`, `start(ring)`, `stop()`.
- `RingBuffer` — single-producer / multi-consumer live ring (4 s of PCM).
- `CaptureEngine` — the generic capture core; only runs when a real sink needs audio.
- `ShowerCastService` — thin orchestrator: reads the selected sink(s) from prefs (or
  intent extras), starts the engine only if needed, hands the shared ring to each sink.
- `BootActivity` — the on-panel UI: pick Local/Sonos, set host + gain, START/STOP.
- `BootReceiver` — on boot, starts the service **only** if a non-local sink was chosen.

The vendored `com.opus.airvia` package supplies `LogBus` (tagged logging) and the
transport helpers. The `raop/` and `ap2/` AirPlay code is vestigial — we pivoted from
AirPlay 2 (NTP timing is discarded by Sonos) to plain UPnP+WAV; it still compiles but is
not used on this path.

## Build

```sh
export PLATFORM_P12=/path/to/platform.p12   # device platform key, passphrase "android"
./build.sh                                  # -> showercast-platform.apk
```

The platform key grants `CAPTURE_AUDIO_OUTPUT`; a debug-signed APK gets permission-denied
on `REMOTE_SUBMIX`. **The key file is never committed** — `build.sh` refuses to run
without `PLATFORM_P12` pointing at a local copy.

## Install + drive (adb)

```sh
adb install -r showercast-platform.apk
adb shell pm grant com.ghost.showercast android.permission.POST_NOTIFICATIONS

# select + start via the on-panel UI (tap BootActivity), or straight from adb:
adb shell am start-foreground-service -n com.ghost.showercast/.ShowerCastService \
    --es sinks sonos --es host 10.0.1.179 --ef gain 24     # route to the Sonos
adb shell am start-foreground-service -n com.ghost.showercast/.ShowerCastService \
    --es sinks local                                        # back to stock behaviour
adb shell am force-stop com.ghost.showercast                # stop everything
```

`--es sinks` takes a comma-separated list (`local,sonos`) so both can run at once; the
local amp always keeps playing because `REMOTE_SUBMIX` is a tap, not a reroute.
