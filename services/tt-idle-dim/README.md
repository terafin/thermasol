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
  B5 mute when a frame lifts it. There is no time-based suppression: a second
  app unmute after a re-mute must still end muted. Frames that arrive together
  are coalesced by the drain, so one action is normally one re-mute. The
  decision is taken after the tick's state machine, so a touch or a restore in
  the same tick wins and the daemon never mutes a lit panel.
* **the bus is retried**: `tt-can0` is late-start and this daemon starts at
  `sys.boot_completed`, so the interface can be missing for the first seconds.
  The daemon retries every 2 s in the main loop, logs each attempt, and
  reattaches if it goes away (`EPOLLERR`/`EPOLLHUP`).

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

### What a B6 means (from `latest.bin`, not assumed)

The handler at `0x151a` is `ldrsb.w r3, [r4, #3]` — **signed**:

* `data[3] >= 0` (bit 7 clear): the master-volume block is **skipped entirely**.
  No mute, no unmute. `data[4..6]` may still adjust bass/mid/treble, each gated
  on its own bit 7, and none of those touches the mute cell.
* `data[3] < 0`: `v = data[3] & 0x7f`, then `0x1778(v)` — `v == 0` calls
  `0x1714(1)` = **mute**; `v > 0` calls `0x173c(v)`, which calls `0x1714(0)` =
  **unmute** before writing the gain.

So exactly one B6 shape lifts the mute: bit 7 set and index non-zero. `B6 8F`
(index 15) unmutes; `B6 80` (index 0) mutes; `B6 0F` does not touch master
volume. B5 is `ldrb data[3]; 0x1714` — `0` unmutes, anything else mutes.
Frames shorter than four bytes are ignored: the decoder checks `can_dlc`
before touching `data[3..6]`.

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
the one managing the backlight. Re-asserting keeps the daemon the single owner.

Traffic: one frame per unmute that reaches the bus. The captured power-off pair
(`B5 00` then `B6 8F` 11 ms later) usually lands in two drains because the first
re-mute is already out before the B6 arrives, so it costs two — the minimum that
keeps the final state muted. Nothing is sent periodically.

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

Current candidate: `725b6f3d5fb81e516640a9c2cccdf85a9c3a2216eb565e8563edee7ca26fe9a6`
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
* `tests/test_hv_reassert.py` — with the panel dimmed: the captured pair
  (`B5 00`, then `B6 8F` 11 ms later) ends with the last dispatched audio frame
  being a mute; a second unmute 200 ms after a re-mute is **not** dropped;
  `B6 80` and `B6 0F` and `B5 01` need no re-mute; a 3-byte frame is ignored;
  an app burst racing a touch leaves the panel lit and unmuted; every re-mute on
  the bus matches `hv_reasserts`
* `tests/test_hv_reattach.py` — with a bus that does not exist the daemon still
  dims, stays alive, sends nothing and retries repeatedly; with the bus present
  it attaches and mutes once
* all three need `hvtest0` up and must be the only listener on it

## What is NOT verified

* the frames were observed on a **host vcan interface**, never on `can0`
* the re-mute has never seen a real app-issued frame: the host test injects the
  frames the app would send, which proves the daemon's reaction, not the app's
  behaviour
* a bus that *appears after start* could not be exercised here — creating a
  `vcan` needs CAP_NET_ADMIN, which this host does not grant. The retry uses the
  same open-and-register path as the startup attach
* that the daemon's **own** B5 frames reach the unit is unverified — they have
  only been exercised against a host vcan. (The unit does apply a hand-sent
  `131#A5B57B0100000000`: sent 2026-11-06 14:22:47, operator reported "muted
  and stayed". So the frame semantics are established; only this daemon's
  delivery is not.)
* `hv_can_open` failing at startup retries on the existing 1 Hz tick; a dim that
  happens while the interface is absent is **not** replayed later
