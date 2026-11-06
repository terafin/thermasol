# tt-idle-dim — the panel's idle/lock daemon, with HydroVive quiet-on-idle

This is the **source of the daemon currently deployed** at `/vendor/bin/tt_idle_dim`
(sha256 `e1ff56f27454ebdcbf466e1757426bb67b644794b520a3c9b4018a6cb66fd28c`) and its
supervisor `tt_idle_dim_super.jar` (`e25666ac…e2e65706`).

Provenance: recovered from this project's session transcript after the original
scratch directory was lost. The import is verified by **reproducing the deployed
binary byte-for-byte** before any change was made — see "Verification" below.

## What the daemon does

* read-only evdev listener; no EVIOCGRAB, no suspend, no input masking
* dims the backlight after the idle threshold, restoring a re-read value
* **playback lease** (`--playback-stdin`): the supervisor pipes `PLAYING` / `IDLE`
  lines; the lease starts **UNKNOWN**, and UNKNOWN *inhibits* dimming, so a
  daemon with no control channel never dims
* **HydroVive coupling** (added here): a *successful* brightness transition sends
  one CAN frame. Dim → `131#A5B57B01`, restore → `131#A5B57B00`. A failed
  backlight write sends nothing.
* **the app cannot leave it unmuted while dimmed**: the daemon also *reads*
  `0x131` (filtered, own messages off) and, while it owns the dim, re-sends the
  B5 mute whenever a frame would lift it — `B5 00`, or any `B6` (the firmware
  unmutes before it writes gain). Rate-limited to one re-mute per second so one
  app action collapses into one frame. It never hears its own transmissions, so
  it cannot loop.

## Why the app needs policing, and where

The desired behaviour is display-linked: dim → muted, lit → unmuted. That is
exactly the transition the daemon owns. The app does not know the panel is
dimmed — it keeps running with the screen "on" from Android's point of view —
so its own audio calls are not gated by display state.

Every app call site that emits `B5 00` or `B6`, and what triggers it:

| emits | site | trigger |
|---|---|---|
| `B5 00`, `B6` | `Utils.toggleMusicAndSource` | music button, source change, external app, guest button, profile select, app launch — all local taps |
| `B6` | `Utils.delayMusicVolume` -> `setMasterVolume` | 2 s timer spawned by the above |
| `B6` | `Utils.setRoutedVolume` | volume slider, guest button, `loadUserSettings` |
| `B5 00`, `B6` | `SettingsActivity$IdentificationFragment` | settings screen |

All but one require a local tap, and a tap wakes the panel (the daemon restores
and unmutes anyway). The exception is remote: an MQTT/Alexa **"user one" /
"user two"** command (`AwsMqttConnectionService.handleAction`) writes
`externalLogin`, and `MainControlRequestMonitor.handleExternalLogin` turns that
into `loadUserSettings` -> `toggleMusicAndSource` -> unmute, with nothing
touching the backlight. That is the case the re-assert covers.

The ThermaSol "Slide to unlock" screensaver is **lit**, not dimmed, so it is not
a mute state and nothing here treats it as one. Neither `ShutdownAll` (the app's
power button) nor shower/steam start is involved.

### Trade-off

A stray unmute is audible for as long as it takes the re-mute to land — a few
milliseconds on the bus, since the daemon reacts to the frame rather than to a
timer. The alternative, gating inside the app on the brightness node, would need
the app to read `/sys/class/backlight` and would break when the daemon is not
the one managing the backlight. Re-asserting keeps the daemon the single owner
and costs one frame per stray unmute.

## Deployed configuration (unchanged by this work)

```
tt_idle_dim --parent-death --input-name "Atmel maXTouch Touchscreen" \
  --idle-seconds 300 --dim 0 --status /data/local/tmp/tt-idle-dim.status \
  --playback-stdin
```

300-second threshold, `--dim 0` (backlight to 0 of max_brightness 100). Panel gain
(`WM8904 Headphone Volume 63`) is a separate subsystem and is not touched here.

## Build

```
./build-android.sh idle_dim        # aarch64, AOSP clang r536225
```

Current candidate: `78725764746c69e74ee1ae4430eebf89bb8794431d1e1df7d7793c1c85b32f74`
(the RAM-trial build running on the panel is the earlier `83e2bbe1…c1ef7`).

## Verification

* import reproduced the deployed hash exactly: `e1ff56f2…f66fd28c`
* the HV build is reproducible from this tree: `./build-android.sh` emits
  `83e2bbe1…c1ef7`, byte-identical to the binary running as the RAM trial on
  the panel (`/data/local/tmp/tt_idle_dim_new`)
* `make test` — 85 logic assertions + 48 playback assertions, 0 failures
* `make hosttest` — 9 playback/daemon host tests, OK
* `tests/test_hv_display.py` — real deployed args (`--dim 0`, `--playback-stdin`),
  IDLE lease line, asserts exactly one mute on dim, one unmute on wake, and **no
  mute when the dim write fails**
* `tests/test_hv_reassert.py` — with the panel dimmed: app `B5 00` -> one
  re-mute; app `B5 01` -> none; app `B6` -> one; a three-frame burst -> one;
  `B5 00` while lit -> none; the re-mute does not repeat; `hv_reasserts` counts
  them. Both suites need `hvtest0` up and must be the only listener on it.

## What is NOT verified

* the frames were observed on a **host vcan interface**, never on `can0`
* the re-mute has never seen a real app-issued frame: the host test injects the
  frames the app would send, which proves the daemon's reaction, not the app's
  behaviour
* that the daemon's **own** B5 frames reach the unit is unverified — they have
  only been exercised against a host vcan. (The unit does apply a hand-sent
  `131#A5B57B0100000000`: sent 2026-11-06 14:22:47, operator reported "muted
  and stayed". So the frame semantics are established; only this daemon's
  delivery is not.)
* `hv_can_open` failing at startup retries on the existing 1 Hz tick; a dim that
  happens while the interface is absent is **not** replayed later
