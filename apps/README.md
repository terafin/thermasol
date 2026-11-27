# Helper apps

The panel image starts or expects these small apps. Their original source was lost, so the source
here was **recovered from the installed APKs** by decompiling them (jadx). It was then repaired where the
decompiler produced code that does not compile, and rebuilt and checked against the installed apps:
each rebuilt manifest matches the installed one, and the decompiled code differs only by compiler
layout and the repairs below.

| App | Package | What it does |
|---|---|---|
| `ttcontroller` | `net.siliconspirit.ttcontroller` | Keeps a binding to ThermaSol's `HardwareService` alive and rebinds when it drops, so the shower controller stays connected. Started by the vendor init (`tt-controller-keeper`). |
| `ttidle` | `net.siliconspirit.ttidle` | Handles the idle broadcasts `STANDBY`, `STATUS`, `OFF` and `RESUME`. When nothing is playing (checked through the audio service), `OFF` sends the peripheral off sequence (`98, 97, 38`) to ThermaSol's `HardwareService`; `RESUME` unmutes only a mute it made itself. Uses hidden platform APIs. Installed but **disabled** on the reference panel; the idle daemon (`services/tt-idle-dim/deployed`) does this job. |
| `ttstatus` | `net.siliconspirit.ttstatus` | Read-only probe: calls `HardwareService` getters and writes the results to a JSON status file. |
| `ttsensor` | `net.siliconspirit.ttsensor` | Listens to the ambient-temperature sensor (type 13) for up to 12 s and writes a report of what it saw. |
| `ttstop` | `net.siliconspirit.ttstop` | Sends the off command through `HardwareService` only when the controller is already in standby (state 255, no errors, no steam or flush timer), and reports the controller state before and after; otherwise it refuses (`precondition_not_standby`). |
| `ttsimplehome` | `net.siliconspirit.overlay.ttsimplehome` | Resource overlay on the launcher (`com.android.launcher3`) for the home screen. |
| `ttblacktaskbar` | `net.siliconspirit.overlay.ttblacktaskbar` | Resource overlay on the launcher that sets the taskbar colour, light and dark. |

## Repairs made to the decompiled source

- `ttcontroller` `StatusStore.read()`: the decompiler moved the `return` out of its `try`; restored.
- `ttidle`, `ttsensor`, `ttstop`: lambda bodies referred to a synthetic `f$0` field; they call the
  enclosing instance (`Worker.this`, `SensorActivity.this`, `StopActivity.this`) as the original did.
- `ttstatus` `runQueries()` and `writeStatus()`: duplicated and tangled exception handling rewritten
  with the same output fields and behaviour.

## Building

```sh
apps/build-app.sh apps/ttcontroller out/ttcontroller.apk
FRAMEWORK_JAR=<aosp>/out/soong/.intermediates/frameworks/base/framework/android_common/turbine-combined/framework.jar \
  apps/build-app.sh apps/ttidle out/ttidle.apk      # hidden platform APIs
```

Needs the Android SDK (build-tools, platform 35) and a JDK. The installed copies are signed with the
platform key (`--sign <key.pk8> <cert.x509.pem>` to match); unsigned output is for checking only. CI
builds every app except `ttidle`, which needs the AOSP tree's `framework.jar`.
