# Panel pipeline: Sonos amps as native Android outputs on the ThermaTouch TT10V2

This directory rebuilds the ThermaTouch panel's vendor and system images so that every Sonos player on
the network is its own Android audio output: picked from Android's standard output switcher, named by
its Sonos name, one amp per output, no Sonos grouping and no app in the audio path. Everything needed to rebuild it is here: the scripts, the source patches, the checks that gate every
flash, and the published release the build starts from (v1.2). The helper apps the image starts are in
[`apps/`](../../apps/README.md).

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
- **No saved amp list.** Every output is a player that answered a live search; nothing about the amps
  is stored on the panel. The audio service searches when it starts and lists what answers. It starts
  before the network is up, so at boot it usually lists none; the background search (every 20 s)
  then finds each player and restarts the audio service so it is listed (seconds, no rebuild). A
  player switched off stays listed until the audio service next restarts.
- **Sticky output.** `framework.patch` (services.jar) saves the chosen output (one setting,
  `thermasol_last_output_route`) and selects it as soon as that player is listed, at boot or whenever
  it comes online later. Only a real plug-in (headset, USB, Bluetooth) takes media over; any other
  amp coming online never does.
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
| Fetch and pin the base images from the published v1.2 release (once) | `pull-base.sh` | no |
| Build the audio service + Sonos module (APEX) | `build-audio.sh` | no |
| Build services.jar with the framework patch | `build-framework.sh` | no |
| Build the signed images | `build.sh` | no |
| Flash the inactive slot and trial-boot it | `flash.sh latest` | **yes** |
| Test | `test.sh` | read-only (silent playback) |
| Run Android's audio VTS on the Sonos module | `vts-audio.sh` | yes (audioserver paused; amps muted) |
| Keep it: mark good, copy to the fallback slot | `commit.sh` | **yes** |
| Back out / switch slots | `rollback.sh` / `swap.sh <_a\|_b>` | **yes** |
| Remove retired apps, reclaim space | `remove-apps.sh` | yes |
| Install a published release onto the inactive slot (backup, verify, trial boot, keep) | `install.sh <release-tag\|dir>` | **yes** (inactive slot only) |
| Full backup to the build host (do this first) | `backup.sh` | read-only |
| Put one slot back from a backup | `restore.sh latest <slot> [--parts "..."]` | **yes** (inactive slot only) |
| Recover a panel that won't boot | `recover.sh <slot>` | **yes** (U-Boot over TFTP + power cycle) |
| Rebuild a slot with Android down | `restore.sh latest <slot> --uboot` | **yes** (U-Boot over TFTP + power cycle) |
| Check an image set, A/B record or U-Boot env offline | `imgcheck.py release <dir>` / `ab-select <hex>` / `uboot-env <file>` | no |

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
- **build.sh** starts from the pinned base images (sha-checked; all from the published v1.2 release), applies the overlay
  and the `sonos` module of `overlay/audio-policy.patch` to the vendor audio policy, labels every
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
- **backup.sh** copies boot0, boot1, the user area up to userdata (bootloader, GPT, U-Boot env, both
  slots, misc), userdata and the area after it (vbmeta), and checks each file's sha against the same
  bytes read on the panel. It writes nothing to the panel.
- **restore.sh** checks the backup's own shas, takes partitions from its own GPT, writes only the
  slot that is not running, verifies every partition by readback, then boots it. `--uboot` does the
  same with Android down: every chunk is staged and sha-checked before U-Boot can see the script, the
  panel is power-cycled until U-Boot fetches it (up to 3 times), the A/B record changes only after
  every chunk landed, and the result is verified after boot.
- **recover.sh** sets the A/B record from U-Boot over TFTP and power-cycles; it counts only fetches
  after its own power cycle and retries the power cycle up to 3 times.
- **All writes** go through `write_part_verified` (chunks pushed as files and sha-checked on the
  panel; `adb exec-in` corrupted data in testing), and `lib.sh` refuses any write to the raw eMMC
  device or boot0/boot1, so no script can reach the bootloader, GPT or U-Boot environment.

- **install.sh** refuses a release whose `SHA256SUMS` or `imgcheck.py` check fails, a panel that is not a
  TT10V2 on Android 15, an invalid A/B record or a partition-size mismatch, and runs without a verified
  backup of the current boot. It writes only the inactive slot, trial-boots it, and keeps it only if it
  comes up enforcing with the release's vbmeta digest. This U-Boot picks slots by priority only, so a
  slot that fails to boot does not fall back on its own: `recover.sh <running slot>` brings it back.
  `test_install.sh` runs it against a fake panel (`fake-adb.sh`) in CI.
- **imgcheck.py** verifies an image set the way the panel's U-Boot does (vbmeta signature with the
  public test key, flags 0, no chain descriptors, every hash and hashtree, kernel under 32 MiB) and
  prints the vbmeta digest the panel reports as `ro.boot.vbmeta.digest`; decodes an A/B record to the
  slot U-Boot boots first; and fails a U-Boot environment whose `bootcmd` does not start with the
  network recovery hook. It never prints device identifiers.

## Proven on the panel (2026-11-27)

Backup; slot switch both ways; network recovery three times back to back; restore over adb with real
writes; a full-slot restore through U-Boot with Android down (261 chunks, all six partitions match
the backup); both slots then identical and `test.sh` passing on each.

## What it cannot recover

A damaged bootloader (first 8 MB of the eMMC) or U-Boot environment without the `tt_nethook`: the
panel then needs its UART console, which means opening the wall. No script here writes either.

## The recovery server

`recover.sh` and `restore.sh --uboot` need the TFTP server the U-Boot hook fetches from
(`host/tt-tftp.service`: dnsmasq serving `/srv/tt-tftp`, empty except during a recovery) and the
hook in the panel's U-Boot environment ([docs/16](../../docs/16-network-recovery-hook.md)).
