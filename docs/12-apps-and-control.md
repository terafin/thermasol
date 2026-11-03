# 12 — Apps, audio control and the UI surface

The port is only half the work. This page is the other half: what was actually installed, the
local control app that front-ends the vendor service, and the adb recipes that made it possible
to drive a sealed panel from a terminal.

Everything here was run on the deployed Android 15 panel.

---

## 1. The local control app: `net.example.ttaudiosource`

A small companion app written during the hiss investigation. It exposes vendor service codes
through activities so adb can drive them, and it is **the lever used for all the audio
isolation work**.

```sh
# apply a code — force-stop FIRST, or the second --ei is silently ignored
am force-stop net.example.ttaudiosource
am start -W -n net.example.ttaudiosource/.AudioSourceActivity --ei code 104 --ei value 1

# hold silence for a bounded time
am start -W -n net.example.ttaudiosource/.SilenceHoldActivity --ei seconds 300

# read back what was applied
cat /data/user/0/net.example.ttaudiosource/files/audio-source-status.json
cat /data/user/0/net.example.ttaudiosource/files/silence-status.json
```

| code | meaning |
|---|---|
| 104 | source select. The only verified value is **0** (`A5 B7 7B 00` restores audio); the library swaps 1↔2 by Bluetooth capability, so do not assume 1 is "analog" |
| 100 | master volume |
| 111 | `hvlsr_bluetooth_power_off` — **not** a mute |

`am force-stop` between codes is **required**. The activity reads the extras once at start; a
second `am start` without a force-stop reuses the existing instance and drops the new values.

Restoring normal audio after an experiment:

```sh
am force-stop net.example.ttaudiosource
am start -W -n net.example.ttaudiosource/.AudioSourceActivity --ei code 104 --ei value 1
am start -W -n net.example.ttaudiosource/.AudioSourceActivity --ei code 100 --ei value 50
```

## 2. Volume: `net.example.ttvolume`

The stock volume UI is not usable on a panel with no hardware buttons. `ttvolume` supplies a
foreground service plus a notification-shade control.

```sh
adb install --no-incremental -r ttvolume.apk
pm grant net.example.ttvolume android.permission.POST_NOTIFICATIONS
am start-foreground-service -n net.example.ttvolume/.VolumeService
```

`--no-incremental` is mandatory for vendor APKs here (see [06-procedures.md](06-procedures.md) §G).

**The volume curve:** the MediaSession index the app displays is **8 below the raw stream
value** — `display = raw − 8`. Verified against the mixer's dB anchors. Do not "correct" this;
the offset is real and consistent.

Without the notification grant the service starts but its control is invisible, which looks
exactly like a broken service.

## 3. Driving the UI from a terminal

```sh
# what is on screen, with bounds
su 0 uiautomator dump /sdcard/ui.xml
su 0 cat /sdcard/ui.xml

# tap the centre of a bounds="[x1,y1][x2,y2]"
input tap $(( (x1+x2)/2 )) $(( (y1+y2)/2 ))

# expand the shade to reach volume / notifications
su 0 cmd statusbar expand-notifications

# set a stream volume directly (stream 3 = music)
cmd media_session volume --stream 3 --set 0
cmd media_session volume --stream 3 --get

# screenshot
adb exec-out screencap -p > panel.png

# navigation
input keyevent 3      # HOME
input keyevent 4      # BACK
input keyevent KEYCODE_WAKEUP
```

`input` is reliable here — see the correction in [03-hardware.md](03-hardware.md).
`uiautomator dump` must run **directly as `su 0`**. Wrapping it in `su 0 sh -c` breaks on
redirect quoting and yields empty dumps.

## 4. Installed apps and entry points

| App | Package / component |
|---|---|
| Termux | `com.termux` |
| Termux:Boot | `com.termux.boot` |
| 1Password | `com.onepassword.android/.setup.welcome.WelcomeActivity` |
| Plex | `com.plexapp.android/com.plexapp.plex.activities.SplashActivity` |
| Netflix | `com.netflix.mediaclient` |
| Chrome | `com.android.chrome` |
| YouTube | `com.google.android.youtube` (native) |
| Home Assistant | `io.homeassistant.companion.android` |
| Music Assistant | via HA |

```sh
am start -W -n com.plexapp.android/com.plexapp.plex.activities.SplashActivity
am start -W -a android.intent.action.VIEW -d 'https://m.youtube.com/' -p com.android.chrome
```

### Browsers on this panel

| | Status |
|---|---|
| **Cromite** | works |
| **Firefox** | works (YouTube playback verified) |
| **Chrome** | **does not run** — `GLES3 is unsupported and ES version fallback is disabled`; both 128 and 155 die |

**WebView versions.** The Android 10 image shipped **Chromium 74**. The A15 image ships
**Trichrome WebView 128**, and **155.0.8059.44** installs as a normal **data update** — signer-
verified, survives reboot, and runs the modern HA frontend (`legacyResources: 0,
modernResources: 109`). Replacing the WebView provider does not need a system flash.

## 5. Audio forensics for the hiss work

The probes that actually discriminated "is audio playing" from "is the codec silent":

```sh
cat /sys/kernel/debug/asoc/wm8904-audio/dapm/bias_level
dumpsys media.audio_flinger | sed -n '/Tracks of/,/^$/p' | head -8
dumpsys audio | grep -cE 'state:started'
cat /sys/kernel/debug/regulator/regulator_summary | head -40
cat /sys/kernel/debug/gpio | grep -iE 'amp|spk|speaker|mute|audio|sai|codec|en'
tinymix -D 0 | grep -iE 'hp|line|dac|aif'
```

**Isolation by force-stop** — the test that separates a misbehaving client from the codec:

```sh
am force-stop com.google.android.youtube
am force-stop net.example.ttaudiosource
dumpsys media.audio_flinger | sed -n '/Tracks of/,/^$/p' | head -8   # must be empty
```

Then listen. If the hiss survives with zero tracks and the codec idle, the client is exonerated.

**The trap that cost the most time:** `dapm/bias_level` reads `Off` and regmap `06`/`0c` read
`0000` **during normal, working playback**. Treating those as a power indicator produced a
completely wrong conclusion that had to be retracted. See [08-lessons.md](08-lessons.md).

## 6. What the app work does not cover

- **Apple TV** sign-in is deferred (issue [#7](https://github.com/terafin/thermasol/issues/7)).
- **Netflix** works; DRM is fine on this image.
- **HA dashboard** runs but costs ~82% of the SoC. That is a Home Assistant dashboard problem,
  not a panel defect — a lighter dashboard is the fix, not code.
- **Bluetooth audio** is not usable at 115200 baud (issue
  [#4](https://github.com/terafin/thermasol/issues/4)).
