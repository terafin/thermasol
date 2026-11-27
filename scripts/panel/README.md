# Panel pipeline: Sonos amps as native Android outputs on the ThermaTouch TT10V2

This directory rebuilds the ThermaTouch panel's vendor and system images so that every Sonos player on
the network is its own Android audio output: picked from Android's standard output switcher, named by
its Sonos name, one amp per output, no Sonos grouping and no app in the audio path. Everything needed
to reproduce it is here: the scripts, the source patches, and the checks that gate every flash.

## How it works

```
App (YouTube, Netflix, Plex, Apple TV, ThermaSol, ...)  -- ordinary Android media playback
  -> Android audio framework (audioserver + AudioPolicy); the user picks an output in the stock switcher
  -> Android's reference AIDL audio service (NXP's copy: vendor/nxp-opensource/imx/audio/default)
       primary (built-in amp) | bluetooth | usb | r_submix | sonos  <- the module this adds
  -> Sonos module: each amp is an OUT_BUS device, address = its IP
       streams 48 kHz PCM over HTTP (:8091/live.wav) and tells the chosen amp to play it (UPnP)
```

- **Discovery** finds Sonos players over SSDP and keeps only devices that can play (they advertise
  AVTransport); Boosts and the hidden half of bonded pairs are not outputs. Names come from each
  player. Nothing is hard-coded.
- **Remembered amps.** The audio service starts before the network is up, so every amp found is
  remembered (`persist.vendor.sonos.amp.<n>`, written by the service itself). Remembered amps are
  outputs from the first moment of boot, so the saved output choice can be restored immediately and a
  slow or absent player at boot never makes outputs disappear. A newly found amp is added and the audio
  service restarts to list it (seconds, no rebuild); a remembered device that answers but cannot play
  is dropped.
- **Sticky output.** `framework.patch` (services.jar) saves the chosen output and restores it at boot.
  Only a real plug-in (headset, USB, Bluetooth) takes media over; an amp coming online never does.
- **Volume.** Use Android's own controls: the Quick Settings media card's output chip opens the system
  output switcher with the volume slider for the selected amp. Amp outputs default to full media
  volume so the panel's volume, not a hidden attenuation, sets the level.
- **Tablet behaviour.** The stock image force-launched the ThermaSol app at every boot; the overlay
  drops that, so the panel boots to the launcher and ThermaSol is an ordinary app.

## What you need

- An NXP i.MX Android 15 tree: `imx-android-15.0.0_1.2.0` (manifest tag `android-15.0.0_1.2.0`),
  built for the Variscite DART-MX8M-Mini, lunch target **`dart_mx8mm-ap4a-userdebug`**. A pre-release
  config (trunk_staging) produces APEXes the released panel refuses, and it will not boot.
- A ThermaTouch TT10V2 running that Android 15 image, reachable over adb (TCP), with root via `su`.
- Copy `local.env.example` to `local.env` and fill in the panel address and, for recovery, the Home
  Assistant switch that powers the panel.

## Steps

| Step | Script | Touches the panel? |
|---|---|---|
| Pin the known-good base images (once) | `pull-base.sh _b` | read-only |
| Build the audio service + Sonos module (APEX) | `build-audio.sh` | no |
| Build services.jar with the framework patch | `build-framework.sh` | no |
| Build the signed images | `build.sh` | no |
| Flash the inactive slot and trial-boot it | `flash.sh latest` | **yes** |
| Test | `test.sh` | read-only (silent playback) |
| Run Android's audio VTS on the Sonos module | `vts-audio.sh` | yes (audioserver paused; amps muted) |
| Keep it: mark good, copy to the fallback slot | `commit.sh` | **yes** |
| Back out / switch slots | `rollback.sh` / `swap.sh <_a\|_b>` | **yes** |
| Remove retired apps, reclaim space | `remove-apps.sh` | yes |
| Recover a panel that won't boot | `recover.sh <slot>` | **yes** (U-Boot over TFTP + power cycle) |

Never hand-run `dd`, `avbtool`, misc writes or `setenforce`. If a script cannot do something, fix the
script.

## The source

- `overlay/audio-tree.patch`: the Sonos module and its hooks into the reference audio service, against
  NXP `android-15.0.0_1.2.0`. `build-audio.sh` applies it.
- `overlay/framework.patch`: per-amp outputs, sticky output, amp volume default (services.jar).
- `overlay/`: SELinux rules (each with its reason in `sepolicy.cil.why`), init files, removed vendor
  files, and the lines dropped from the stock init. See `overlay/README.md`.
- `hal/discovery.h`: Sonos discovery, shared with `hal/hosttest.sh`, which checks it against a live
  Sonos system from a desktop. `hal/PanelRoute.java` is the test helper that selects outputs.

## What each step guarantees

- **build-audio.sh** refuses any network send that could raise SIGPIPE (it would kill every audio
  module), builds the APEX, and verifies its payload signature and hashtree against the key it ships.
- **build.sh** starts from the pinned base images (sha-checked), applies the overlay, labels every
  added file (an unlabeled file fails the build), refuses an APEX built for a pre-release SDK, signs
  with the device key and verifies the whole AVB chain.
- **flash.sh** checks policy and VINTF, writes only the inactive slot, requires a readback match on
  every partition, and trial-boots it; a failed trial recovers to the fallback slot automatically.
- **test.sh** passes only if: booted, SELinux enforcing, no audio denials, all audio modules present,
  every playable Sonos player listed by its name, no retired app installed, amp volume not at the
  silent default, and silent playback reaches every awake amp (muted first, confirmed over UPnP),
  with the user's chosen output restored afterwards.
- **vts-audio.sh** runs `VtsHalAudioCoreTargetTest` on the Sonos module with every reachable amp
  confirmed muted; a failure rolls back.
- **commit.sh** needs `test.sh` and a VTS pass for the running audio build, then copies the committed
  slot to the other one so the fallback is always the last good build.
