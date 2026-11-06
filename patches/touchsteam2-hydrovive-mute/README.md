# touchsteam2: keep the HydroVive muted through shower shutdown

> **NOT THE CHOSEN APPROACH — do not install this APK.**
> The desired behaviour is linked to the panel's **display state**, not to the
> app's power button or to shower/steam start. That belongs entirely to the
> idle daemon (`services/tt-idle-dim`), which already owns the dim/restore
> transitions and now re-asserts the mute when the app lifts it while dimmed.
> This patch is kept as the record of the app-side investigation — the
> shutdown chain, the B6 volume-15 origin, and the paths that restore audio —
> not as a candidate.

## The defect

Powering the panel off leaves the ceiling speaker **buzzing**, and silences it
only for about one second. The cause is in the installed UI app
(`com.thermasol.touchsteam2`), not in the daemon.

`Utils.ShutdownAll()` ends with `PersistPauseAndKillBluetooth()` →
`KillBluetooth()` → `toggleMusicAndSource()`, and that last call is a **start-up
action running inside a shutdown**: it mutes, then unmutes, then restores the
volume. Both the explicit unmute and the B6 volume frame unmute the ceiling unit
(the DSP's `0x173c` calls the mute primitive with 0 *before* writing gain).

Captured on 2026-11-06, id `0x131`:

```
55.679  A5 B5 7B 01   mute        <- ShutdownAll #1
55.921  A5 B5 7B 01   mute        <- ShutdownAll #2
56.142  A5 B5 7B 01   mute        <- toggleMusicAndSource
56.343  A5 B5 7B 00   UNMUTE      <- the buzz returns here
56.354  A5 B6 7B 8F   volume 15   <- and B6 unmutes again 11 ms later
```

First mute to unmute is 1.03 s, which is the dip the operator hears.

The chain is confirmed against the **installed** `classes2.dex` (the copy pulled
off the panel, not a recovery-tree copy): `ShutdownAll` calls `mute`, `mute`,
`PersistPauseAndKillBluetooth`, and `mute`; `PersistPauseAndKillBluetooth` calls
`KillBluetooth`; `KillBluetooth` calls `toggleMusicAndSource`; and
`toggleMusicAndSource` is the one that does `mute → unmute → delayMusicVolume`.

## The fix

Two static fields on `OverheadLight`, both written only by `Utils.ShutdownAll`:

| field        | meaning                                                        |
|--------------|----------------------------------------------------------------|
| `sInShutdown`| true **only** for the span of `PersistPauseAndKillBluetooth()` |
| `sAudioGen`  | bumped once per power-off; invalidates timers already queued   |

* `OverheadLight.unmute()` and `OverheadLight.setMasterVolume()` return early
  while `sInShutdown`.
* `Utils.delayMusicVolume()` does not spawn while `sInShutdown`, and stamps the
  thread it does spawn with the current `sAudioGen`.
* `lambda$delayMusicVolume$1` drops itself if `sAudioGen` moved while it slept.

Guarding at the two send sites rather than only reordering matters: the volume
restore is **delayed** (`delayMusicVolume`, up to 2 s), so a trailing mute alone
could be undone by a B6 that fires afterwards.

Nothing is latched. `sInShutdown` is false again as soon as the bluetooth
teardown returns.

### Starting a session restores audio

Suppressing is only half of it. After a power-off the unit stays muted until
something unmutes it, so the two session-start chokepoints call
`OverheadLight.unmute()`:

| start | chokepoint | callers it covers |
|---|---|---|
| shower | `HardwareServicePersist.esv_turn_on()` (uses its own `mContext`) | `DigitalShowerScreenFragment.handleTap`, `DigitalShowerScreenFragment$ManagementThread`, `AwsMqttConnectionService` |
| steam | `Utils.TurnOnSteam(Context)` | `SteamFragment.onSlide`, `MainControl$MainControlRequestMonitor` |

These are the only places the power-off mute is lifted, which is what makes it
not premature: they fire when the user actually starts a session, not when the
screen wakes or when an unrelated control is touched.

### Why not a flag cleared on resume (the rejected first design)

The first candidate used one `sShutdownMuted` flag, set by `ShutdownAll` and
cleared by `Utils.loadUserSettings()`. It silences the power-off, but it is
wrong for the panel:

`loadUserSettings` is reachable only from the two user-profile buttons in
`UserFragment` and from `handleExternalLogin` (dead: `EXTERNAL_LOGIN_KEY` is only
written by the MQTT service and was `-1`). It is **not** the resume path. The
real resume paths — `MusicController`, `MenusMgr`, the external-app launcher and
the external-app teardown — all go through `toggleMusicAndSource()`, and the
latch made every one of them silent. A user who powered off mid-shower and then
pressed play would have got nothing back until they opened the user screen.

`tests/test_shutdown_mute_model.py` keeps the latch in the model and asserts
that it strands audio on that path, so a regression back to it fails loudly.

## Audio restoration paths

All of these send `B5 00` (and a `B6` where volume is restored), so audio comes
back from any of them:

| action | path |
|---|---|
| start shower | `esv_turn_on` -> `unmute` |
| start steam | `TurnOnSteam` -> `unmute` |
| music button | `MusicController.hardwareStartBluetooth` -> `StartBluetooth` -> `toggleMusicAndSource(2)` |
| source change | `MusicController.hardwareSourceChange` -> `toggleMusicAndSource` |
| external app | `ExternalAppsScreenFragment` / app launch -> `toggleMusicAndSource` |
| guest button | `MenusMgr.handleGuestButton` -> `toggleMusicAndSource` |
| profile select | `loadUserSettings` -> `toggleMusicAndSource` |

Neither shower nor steam start previously made any audio call at all —
`DigitalShowerScreenFragment.handleTap` called `esv_turn_on`, `SteamFragment.onSlide`
called `Utils.TurnOnSteam` (`toggleSteam` + `resetLightSettings`), and
`DateTimeFragment.onSlide` called `login()` (lock pattern only). That is why the
first candidate, which only suppressed, left the panel silent after a session
start.

Note what is **not** a resume hook: `DateTimeFragment.login()` (slide-to-unlock).
Unmuting there would fire for a user who unlocks and walks away, which is the
premature case this design avoids.

## What is not changed

Playback (the daemon's playback lease and `--playback-stdin`), the 300 s idle
timeout, `--dim 0`, shower/steam/light controls, and the WM8904 gain 63.

## Verification

`tests/test_shutdown_mute_model.py` replays the recovered call order under three
implementations — the installed app, the rejected latch, and the shipped design:

* baseline reproduces the capture exactly — 3 mutes, 1 unmute, B6 `0F`
* shipped power-off: **no unmute, no B6, ends muted**, last frame is a mute
* shipped shower start from the muted state: sends the unmute, ends audible
* shipped steam start from the muted state: sends the unmute, ends audible
* the rejected latch swallows both, which is the second reason it was wrong
* idling after a power-off produces no further frame (the unmute is not premature)
* music-controller and user-select resumes both send the unmute and end audible
* an ordinary mute/unmute and an ordinary volume change are unaffected
* three shutdown/resume cycles do not latch

`tests/test_delayed_volume_race.py` covers the two timer windows: a timer
scheduled before power-off, and a timer woken while the panel is off.

## Remaining uncertainty

The model is a faithful replay of the decompiled call order, not a run of the
app. Not yet verified on the panel; that needs an install and a
power-off/listen cycle.

Specifically unproven: that the ceiling unit receives any frame (the protocol
has no ACK, so the bus is the only delivery evidence and the speaker is the only
effect evidence); that the thread-timing guard behaves under real concurrency;
that the inserted static fields do not disturb the Kotlin class metadata at
runtime.
