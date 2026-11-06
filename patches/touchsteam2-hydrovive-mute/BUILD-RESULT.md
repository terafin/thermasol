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
