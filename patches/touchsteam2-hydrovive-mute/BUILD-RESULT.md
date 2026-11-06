# Build result — 2026-11-06

## Artifact

`touchsteam2-patched.apk`, 18,900,176 B
sha256 `7192b190063465449626426d66cb023d6fa2f05e358bb335eab2577217d565c9`

Signed with `device/nxp/common/security/platform.{pk8,x509.pem}` —
`apksigner verify --print-certs` reports
`EMAILADDRESS=android@freescale.com, CN=Android` (the panel's platform key).
v1 + v2 + v3 all enabled.

Built on the host from the **installed** APK
(`/home/terafin/tt-recovery/apks/com.thermasol.touchsteam2.apk`), not a build tree.

## Method

1. `baksmali 2.5.2` on `classes.dex` and `classes2.dex` (11,298 smali files)
2. five guards added to `com/thermasol/touchsteam2/util/Utils.smali` and three to
   `OverheadLight.smali` (see `smali/*.patched.smali`)
3. `smali 2.5.2` reassembly, `zipalign -p 4`, `apksigner`

## Scope verification

Re-disassembled the **candidate** and diffed against the original disassembly:

* 25 files differ in total
* **23 of them are cosmetic**: smali drops redundant default initialisers
  (`= false`, `= null`). No instruction, method or field changes.
* **2 are the patch**: `OverheadLight.smali` (62 diff lines) and `Utils.smali`
  (121 diff lines)
* label renaming from `:tt_hv_*` to `:cond_*` is automatic on reassembly and is
  not a semantic change

## Not verified

Never installed or run. The buzz and audio restoration have **not** been
observed with this APK. Install requires approval.

## Bytecode verification (dexdump, on the APK's own classes2.dex)

The guards are present in the **compiled** artifact, not just the smali source:

```
ShutdownAll:  36cb1a  sput-boolean v0, OverheadLight;.sShutdownMuted:Z
ShutdownAll:  36cb32  invoke-static {v2}, OverheadLight;.mute(...)   <- final mute
ShutdownAll:  36cb90  invoke-static {v2}, OverheadLight;.mute(...)   <- pre-existing
unmute:       36c4e8  sget-boolean v0, OverheadLight;.sShutdownMuted:Z  <- instr 0
setMasterVolume: 36bfec sget-boolean v0, OverheadLight;.sShutdownMuted:Z <- instr 0
```

The flag write precedes both mutes in `ShutdownAll`, and each guard is the first
instruction of its method, so neither can send before the check.

Manifest intact: `com.thermasol.touchsteam2`, versionCode 1019, versionName
10.1.9, targetSdk 30 — identical to the installed build.
