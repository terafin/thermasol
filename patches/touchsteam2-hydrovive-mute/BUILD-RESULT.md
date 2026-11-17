# Build result — 2026-11-06

## CORRECTION: the first build used the wrong base

The patch was first applied to `/home/terafin/tt-recovery/apks/com.thermasol.touchsteam2.apk`
(the recovery-tree copy). That is **not** what is installed:

| | recovery copy | installed base.apk |
|---|---|---|
| size | 28,652,204 | 25,580,448 |
| sha256 | a047b21d… | 8ad27395… |
| `classes.dex` | 91ed83bd… | 91ed83bd… (same) |
| `classes2.dex` | 09fd113e… | **686e1086… (different)** |

`classes2.dex` is exactly where `Utils` and `OverheadLight` live, so the first
APK would have delivered the patch to a stale dex. Rebuilt against the pulled
installed `base.apk`.

## Artifact

`touchsteam2-patched-v2.apk`, 23,663,997 B
sha256 `10be1fb19731d19a7231d6b2beaed79860ee42bc861a003e234c0cdd7b4b270f`

Signed `platform.pk8` / `platform.x509.pem` — cert SHA-256
`7fbae817b7db24642d8959c347b561c003c6cfde2cb10f909c932f21a4d6d804`,
**identical to the signer of the installed `base.apk`**, so `install -r` will
be accepted as an update. v1 + v2 + v3.

## Scope verification (re-disassembled the candidate)

Diff against the installed dex: **2 files, and only those 2** —
`OverheadLight.smali` and `Utils.smali`. Every other one of the 3,563 classes is
byte-identical. (The first build spread 23 cosmetic diffs across unrelated
classes; this one does not, because it round-trips the same input.)

## Bytecode checks to repeat after install

`dexdump -d classes2.dex`, expect `sget-boolean … sShutdownMuted` as the first
instruction of both `unmute` and `setMasterVolume`, and `sput-boolean` before
both `mute` calls in `ShutdownAll`.

## Not verified

Never installed, never run. Buzz silencing and audio restoration remain
**unverified**.

## Final structural validation

* `dexdump -f` on the patched `classes2.dex`: **exit 0, zero warnings**
* `d8 --min-api 30` accepts it with no diagnostics (a malformed dex fails here)
* class count parity: patched **3,563** = installed **3,563** — no classes added,
  removed or renamed
* `dexdump -d` still shows `sget-boolean … sShutdownMuted` as instruction 0 of
  `OverheadLight.unmute`

## Side note for the operator

The host root volume filled to 100% (96 KB free of 503 GB) during the d8 run.
That was not caused by this work alone, but the build scratch contributed
~370 MB; the regenerable intermediates were deleted and free space recovered to
21 GB. The artifact hash was re-checked afterwards and is unchanged.

## Call-chain verification against the INSTALLED dex

The chain the patch depends on was re-read from the **installed** `classes2.dex`
(the one pulled off the panel, `09fd113e…` — not the stale recovery-tree copy).
Every link is present, in this order:

```
Utils.ShutdownAll
  OverheadLight.mute          (1st)
  OverheadLight.mute          (2nd)
  Utils.PersistPauseAndKillBluetooth
      Utils.KillBluetooth
          Utils.toggleMusicAndSource
              OverheadLight.mute
              OverheadLight.unmute      <-- the unmute the patch suppresses
              Utils.delayMusicVolume    <-- the delay that later sends B6
  OverheadLight.mute          (3rd)
```

So `mute` → `unmute` → delayed `setMasterVolume(15)` all run *inside*
`ShutdownAll`, which is exactly what the `sShutdownMuted` flag guards. The
sequence recorded in `tests/test_shutdown_mute_model.py` (`B5 01` ×3, `B5 00`,
`B6 0F`) is reproduced by this installed code, not by an assumed one.

# Build v3 — the shipped candidate

`touchsteam2-patched-v3.apk`
sha256 `4096849d69de20f11400d00a8262e302d209342f369e9b77536ed45ba4a5f6c8`,
25,519,008 B.

## What changed from v2, and why

v2 was never installed. Re-reading the installed dex killed its premise:

1. **The latch stranded audio.** v2 cleared `sShutdownMuted` only in
   `loadUserSettings`, which the installed dex reaches from two places: the
   `UserFragment` profile buttons, and `handleExternalLogin` (dead —
   `EXTERNAL_LOGIN_KEY` is written only by the MQTT service and was `-1`). The
   real resume paths — `MusicController`, `MenusMgr`, the external-app launcher
   and its teardown — all call `toggleMusicAndSource`, which the latch silenced.
2. **v2's "final mute" was dead code.** `Utils.smali:793` was `return-void` and
   the added `mute` sat on the next line, unreachable. The model test asserted
   four mutes; the app would have sent three.
3. **v2's APK was malformed for install.** `resources.arsc` was deflated.
   Apps targeting SDK 30 must ship it stored and 4-byte aligned, so the install
   would have been rejected. The archive also carried a stray
   `work/classes2.dex` entry, which is inert but not something to ship.

v3 replaces the latch with `sInShutdown` (scoped to the bluetooth teardown) plus
`sAudioGen` (invalidates timers scheduled before the power-off). See
`README.md` for the design and for why the latch is kept in the model as a
failing case.

## How v3 was built

Reproducible from a pristine disassembly, not hand-edited blobs:

```
unzip -o installed-base.apk classes2.dex -d pristine/     # 686e1086…3265e, matches the device
java -jar tools/baksmali.jar d pristine/classes2.dex -o pristine/smali
cp -a pristine/smali work/smali
python3 apply_patch.py work/smali                         # 3 files edited
java -jar tools/smali.jar a work/smali -o work/classes2.dex
cp installed-base.apk built-v3-unsigned.apk               # copy the REAL apk
cd stage && zip -X ../built-v3-unsigned.apk classes2.dex  # replace ONE entry
zipalign -p -f 4 … && apksigner sign --key device/nxp/common/security/platform.pk8 …
```

## Gates passed

* `smali` reassembles to DEX **035**, the same version as the installed dex
* re-disassembly of the assembled dex differs from pristine in **exactly 3
  files** — `OverheadLight.smali`, `Utils.smali`, and the delayed-volume lambda
  class — and the diff is only the intended instructions (labels renumber)
* class count **3,563**, unchanged; no classes added, removed or renamed
* `dexdump -f`: exit 0, **zero** warnings
* `d8 --min-api 30` accepts the dex
* `classes2.dex` inside the signed APK is byte-identical to the validated dex
  (`b0f53e68…96c9`)
* `resources.arsc` **Stored**, CRC `b5a069c7` — identical to the installed APK
* **869** zip entries, same count as the installed APK; no stray paths
* `zipalign -c -p 4` passes
* signer **`7fbae817b7db24642d8959c347b561c003c6cfde2cb10f909c932f21a4d6d804`**
  — the installed APK's own signer, taken from `device/nxp/common/security/`.
  (v2 was signed with the same correct key. An earlier note here claimed v2
  used the vanilla AOSP key in `build/make/target/product/security/`
  (`c8a2e9bc…`) — that was wrong, and was corrected after verifying v2's
  signature directly.)
* v3-scheme only, matching the installed APK (minSdk 29)

## Not verified

Never installed, never run. Buzz silencing and audio restoration remain
**unverified** until the runbook is executed on the panel.

# Build v4 — session start restores audio

`touchsteam2-patched-v4.apk`
sha256 `341e68be0ca6280f92a008d29e309dd90aa341e25aa83c43256ee5a4e0ee0bfe`,
25,519,008 B. Supersedes v3.

## Why v4

v3 suppressed the power-off unmute but left nothing to lift it again until an
audio-shaped action. Starting a shower or steam made no audio call at all
(`DigitalShowerScreenFragment.handleTap` -> `esv_turn_on`;
`SteamFragment.onSlide` -> `Utils.TurnOnSteam` -> `toggleSteam` +
`resetLightSettings`), so a user who powered off and came back to shower had a
dead speaker. That does not meet "restore normal audio when the user resumes or
starts it".

v4 unmutes at the two session-start chokepoints, which are the only places the
power-off mute is lifted:

* `HardwareServicePersist.esv_turn_on()` calls `OverheadLight.unmute(mContext)`.
  This one method covers every shower start: the screen tap
  (`DigitalShowerScreenFragment.handleTap`), the management thread
  (`DigitalShowerScreenFragment$ManagementThread`), and the remote request
  (`AwsMqttConnectionService`).
* `Utils.TurnOnSteam(Context)` calls `OverheadLight.unmute(context)`, covering
  `SteamFragment.onSlide` and `MainControl$MainControlRequestMonitor`.

Deliberately not hooked: `DateTimeFragment.login()` (slide-to-unlock). Unmuting
on unlock would fire for a user who unlocks and walks away, which is the
premature case.

## Files changed from the installed dex

Four, and only these four:

* `util/OverheadLight.smali` — two fields, guards on `unmute`/`setMasterVolume`
* `util/Utils.smali` — generation bump and teardown bracket in `ShutdownAll`,
  guards in `delayMusicVolume`, stale-timer check in the lambda body, unmute in
  `TurnOnSteam`
* `comm/HardwareServicePersist.smali` — unmute in `esv_turn_on`
* `util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA.smali` — generation field

## Gates passed

* assembles to DEX 035; re-disassembly differs from pristine in exactly 4 files
* class count 3,563; `dexdump -f` exit 0, zero warnings
* `classes2.dex` inside the signed APK is byte-identical to the validated dex
  (`75a20a41…3177`)
* `resources.arsc` stored, CRC `b5a069c7`, unchanged
* 869 entries, same as the installed APK
* `zipalign -c -p 4` passes
* signer `7fbae817…a4d6d804` — the installed APK's own key; v3 scheme only,
  matching the installed app (minSdk 29)

## Not verified

Never installed, never run. Buzz silencing, session-start restoration and all
resume paths remain unverified until the runbook is executed on the panel.
