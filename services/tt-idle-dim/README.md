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

## Verification

* import reproduced the deployed hash exactly: `e1ff56f2…f66fd28c`
* `make test` — 85 logic assertions + 48 playback assertions, 0 failures
* `make hosttest` — 9 playback/daemon host tests, OK
* `tests/test_hv_display.py` — real deployed args (`--dim 0`, `--playback-stdin`),
  IDLE lease line, asserts exactly one mute on dim, one unmute on wake, and **no
  mute when the dim write fails**

## What is NOT verified

* the frames were observed on a **host vcan interface**, never on `can0`
* whether the ceiling unit applies B5 is unverified — the protocol has no ACK
* `hv_can_open` failing at startup retries on the existing 1 Hz tick; a dim that
  happens while the interface is absent is **not** replayed later
