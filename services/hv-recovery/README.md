# hv-recovery — HydroVive CAN tools

Sources for the HydroVive ceiling-unit recovery work. The evidence and the reasons are in
[`docs/14-hydrovive-recovery.md`](../../docs/14-hydrovive-recovery.md); read it first.

**Nothing here may send a bootloader, bank or option-byte command to a unit without a tested
way back.** That is how the unit was lost.

| Path | What it is |
|---|---|
| `flasher/hvflash.c` | Writes a HydroVive image through ThermaSol's own update flow (status 1 → `101#01` → … → pages on 0x102). Dry run unless `--write` and the image's sha256 are given. |
| `flasher/hvcatch.c` | Logs every CAN and error frame with boot-time ms; answers a 0x100 status announcement with `101#01`. |
| `flasher/hvpoll.c`, `hvwatch.c` | Vendor-service poller and passive watcher that run on every boot. |
| `flasher/canprobe.c`, `cansniff.c` | Send only the frames given on the command line; listen. |
| `initshim/initshim.c` | First-stage `/init` wrapper: listens on `can0` from ~2.7 s of kernel time, then execs the real init. |
| `payload/hvnet.c` | PID 1 for a standalone initramfs: loads the first-stage modules, arms `/dev/watchdog` (60 s), listens at 100k in normal mode, runs the vendor update on status 1, logs to ramoops, reboots. |
| `mkhv5h.sh` | Builds `hv5.h` from ThermaSol's published `latest.bin` (not in this repo). |

## Build

The shim and payload are static aarch64 musl binaries built with the Android tree's clang:

```sh
./mkhv5h.sh latest.bin initshim/hv5.h; cp initshim/hv5.h payload/
R=$ANDROID_BUILD_TOP
$R/prebuilts/clang/host/linux-x86/clang-r536225/bin/clang --target=aarch64-unknown-linux-musl \
  --sysroot=$R/prebuilts/build-tools/sysroots/aarch64-unknown-linux-musl -static -O2 -fno-pie \
  -rtlib=compiler-rt --unwindlib=none -fuse-ld=lld -s -o payload/hvnet payload/hvnet.c
```

`flasher/build.sh` builds the bionic tools (needs `ANDROID_BUILD_TOP`).

`payload/build.sh` builds the payload `/init` and `initrd.lz4` from these sources, the boot image's
first-stage modules and ThermaSol's `latest.bin`, and prints their sha256. An image goes on the
panel only from main, on the inactive slot, with those sums committed first.
