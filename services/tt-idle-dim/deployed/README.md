# tt-idle-dim, as deployed (v1.2-android15)

This directory is the **exact source of `/vendor/bin/tt_idle_dim` in release
`v1.2-android15`**: sha256 `ec905b343954647faa3a30f0021cbe97abd5db3295a2638fbe56d52304d9ffa9`.
`./build-android.sh idle_dim` reproduces it byte for byte.

It is the original deployed daemon (`e1ff56f2…f66fd28c`, no HydroVive coupling) plus one
change: **idle goes to the Android home screen, then dims.** The parent directory's daemon has
HydroVive mute-on-dim enabled by default and is not what runs on the panel.

**This is a second copy of the same program, not a symlink.** Exactly four files differ from the
parent: `idle_dim.c`, `idle_logic.c`, `idle_logic.h` and `build-android.sh`, and the difference
is only the HydroVive feature. A fix made in the parent does not reach the panel unless it is
made here too, and vice versa. Collapsing the two into one source with a `TT_IDLE_DIM_HV` flag
belongs here as a change of its own, gated on rebuilding this directory's binary and confirming
`ec905b34…` still comes out; until that is done, change both or neither.

## Behaviour

* No touch for 300 s **and** the playback lease reports `IDLE` → send the HOME intent, wait
  1.5 s, then set the backlight to 0.
* A playing video (`PLAYING`), or no lease verdict yet (`UNKNOWN`), never dims and never goes
  home.

## Why it is written this way (each one was observed on the panel)

* **The HOME intent, not `input keyevent KEYCODE_HOME`.** The key event sent as the backlight
  went dark did nothing.
* **Home before dark.** `am start` HOME issued at the moment of the dim returned without
  switching apps; issuing it 1.5 s earlier works.
* **The child gets `/dev/null` as stdin.** The daemon's stdin is the supervisor's playback
  pipe. `cmd activity` passes its stdio fds to system_server over binder, and with a pipe there
  it fails: `cmd: Failure calling service activity: Failed transaction (2147483646)`. The
  child's output goes to `/data/local/tmp/tt-idle-dim-home.log`.

## Verified on the panel (2026-11-16, booted from vendor_b, not a bind mount)

The deployed binary, run with a 15 s timer and fed the production supervisor's live playback
verdict:

| case | result |
|---|---|
| YouTube live video playing, 45 s | stayed on YouTube, backlight 71, no DIM/HOME |
| same video paused, 30 s | `HOME sent` → launcher in focus → `DIM 0 (restore 71)` |

`make test`: 85 + 48 assertions, 0 failures.
