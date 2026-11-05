# 09 — Stock panel to Android 15, start to finish

You have a ThermaSol ThermaTouch TT10V2 running the shipped Android 10. This is the path to a
working Android 15, in order, as it was actually executed.

**Read [`10-known-pitfalls.md`](10-known-pitfalls.md) first.** It is short and it prevents the
failures below.

---

## The shape of it

| Stage | What you get | Needs |
|---|---|---|
| 0 | The panel identified, and a way back | network only |
| 1 | A shell, and adb | network only |
| 2 | A backup you have verified | the shell |
| 3 | An image set | a build host, or the release |
| 4 | The image on the inactive slot | the shell |
| 5 | A first boot, or a named reason it failed | the shell, until it reboots |
| 6 | The panel reachable again | nothing |

Stages 0–4 and 6 need **no UART and no USB**. Stage 5's failure path may.

---

# Stage 0 — Find the panel

## 0.1 It is not the steam controller

The LAN has more than one ThermaSol device. **`10.0.90.49` is a T2000 steam generator
controller**, not the panel — it answers port 80 with:

```
{"api_ver": 7, "type": "residential", "model": "T2000", "firmware": "5.65"}
```

**Check which device answered before you spend a night on it.** This is the single most common
way to lose a session: scanning for a shower panel, finding a ThermaSol thing, and not noticing
it is the wrong ThermaSol thing.

## 0.2 Find it by name, from the switch

The reliable source is the UniFi client registry, because the switch port is labelled:

```
"name": "Thermasol", "ip": "10.0.90.130", "is_wired": true,
"mac": "f8:dc:7a:9c:9a:e4", "hostname": "couchdb"
```

## 0.3 Confirm it is the panel

A full TCP scan of a stock panel returns **exactly three ports**: `3500`, `57344`, `57345`.
There is no adb. Port 3500 is a UPnP service that gives it away:

```
Server: Linux UPnP/1.0 Sonos/74.0-44280 (ACR_:freescale:dart_mx8mm:variscite)
```

`freescale:dart_mx8mm:variscite` — i.MX 8M Mini on a Variscite DART board. That is your panel.

> **Scanning trap.** A non-blocking `connect_ex` returning `EINPROGRESS` is **not** an open
> port. A scanner that treats it as one reported the panel as having 65,535 open ports.

---

# Stage 1 — Get a shell

The stock panel has no adb, no USB, and no shell. The way in is the panel's **own app store**:
it fetches an HTTP catalogue from a hostname that resolves through normal DNS, so pointing
that hostname at a machine you control makes the panel install whatever you put there.

No Play Store client is involved, and no Google account.

## 1.1 Stand up the mirror

```sh
mkdir -p store/apks store/icons
cp Termux.apk      store/apks/com.termux.apk
cp Termux-Boot.apk store/apks/com.termux.boot.apk

sudo ./scripts/store-mirror/serve_store.py \
    --root ./store --port 80 --base-url http://<your-server-ip> --log
```

**Two things a naive server gets wrong, both of which make the store render empty:**

1. The panel requests **`/index.json` and then `/index-10.json`**. A server matching only one
   returns 404 for the other and the grid shows nothing. `serve_store.py` answers both with the
   same catalogue.
2. The APK URL is **derived** from `apk_icon_url`, not given in the listing — see
   [11-vendor-store-mirror.md](11-vendor-store-mirror.md). Get the icon URL depth wrong and the
   install silently does nothing.

Run it from somewhere that survives: a `nohup` process in `/tmp` dies with a reboot.

## 1.2 Point the vendor hostname at it

The app's base URL is compiled in: `http://thermatouch.tsolup.com/`.

Add a **local-DNS A record** on whatever serves the panel's VLAN:

```
thermatouch.tsolup.com.   A   <your-server-ip>
```

A UniFi gateway record was used. Through the UniFi MCP tool the arguments nest and `confirm`
is required — the flat form fails with `unknown arguments {enabled, key, ...}. Valid arguments:
[confirm, record_data]`:

```json
{"confirm": true,
 "record_data": {"enabled": true, "key": "thermatouch.tsolup.com",
                 "record_type": "A", "ttl": 300, "value": "<your-server-ip>"}}
```

Verify **against the resolver the panel uses**, not your own:

```sh
dig +short @<panel's-gateway> thermatouch.tsolup.com
```

## 1.3 Install Termux from the panel's own store

On the panel: **Settings → App Store → Termux**. The server log confirms the panel connected:

```
172.125.77.119 GET /index.json
  User-Agent: Dalvik/2.1.0 (Linux; U; Android 10; variscite Build/QD1A.190821.014.C2)
  Host: thermatouch.tsolup.com
172.125.77.119 GET /index-10.json
```

> **If the grid is empty, the server is wrong, not the panel.** Two causes: a catalogue that
> parses to `null` because a key is missing, or JSON over 100,000 bytes — the panel's fetch
> buffer is fixed and overflow is swallowed. `/index-10.json` answering `{"status":"ok"}` gives
> Gson a null list and the app throws. Neither shows an error on the panel.

## 1.4 Set up SSH on the panel

Do this **on the panel's own touchscreen**, inside Termux:

```sh
pkg install openssh
passwd              # this becomes your SSH password
sshd                # listens on 8022
```

Confirm from your workstation:

```sh
ssh -p 8022 termux@<panel-ip>
```

## 1.5 Turn on adb — and the trap in it

`adbd` is `disabled` in init. Two approaches that look right and are not:

| Attempt | Result |
|---|---|
| `setprop ctl.start adbd` / `ctl.restart adbd` | init logs `Received control message 'start' for 'adbd'` — and **5555 stays closed**. The restarted `adbd` takes the init USB socket. |
| `stop adbd` / `start adbd` | `stop: must be root`. From Termux you are uid 10108. |

**Do not stop at the dmesg line. Check the port.**

`setprop` is not on Termux's `PATH` — use the absolute path. Then start `adbd` **detached**, so
it cannot claim the init socket and falls back to TCP:

```sh
/system/bin/setprop service.adb.tcp.port 5555
/system/bin/setprop persist.adb.tcp.port 5555
setsid /system/bin/adbd >/dev/null 2>&1 &
```

A successful run logs `adbd E auth.cpp:240] Failed to get adbd socket: Success`. **That failure
is the mechanism**, not an error to fix.

```sh
adb connect <panel-ip>:5555
adb -s <panel-ip>:5555 shell 'id; getprop ro.debuggable'      # uid=2000(shell); 1
```

Root: `adb root` → `restarting adbd as root` → `uid=0(root)`, because the stock build is
`userdebug` with SELinux `Permissive`.

> **On A10, `sys.usb.config=adb` crash-loops adbd** (signal 6, four times) and
> `persist.adb.tcp.port` is not honoured. The working combination on that build is exactly the
> three lines above plus `setprop service.adb.root ""` before any restart. This is why the
> detached-`adbd` route exists.

## 1.6 Persistence — and the step everyone forgets

```sh
adb install --no-incremental -r store/apks/com.termux.boot.apk
```

Then the boot hook. `su` on this build takes a **uid**, not `-c`:

```sh
A="adb -s <panel-ip>:5555"
T=/data/data/com.termux/files
E="HOME=$T/home PREFIX=$T/usr PATH=$T/usr/bin:/system/bin"
$A shell "su 10108 env $E sh -c 'mkdir -p $T/home/.termux/boot'"
```

`~/.termux/boot/00-restore-access`, mode 700:

```sh
#!/data/data/com.termux/files/usr/bin/sh
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=$PREFIX/bin:/system/bin
sshd 2>/dev/null
/system/bin/setprop service.adb.tcp.port 5555
```

**The forgotten step: a freshly installed Termux:Boot never runs until the package has been
launched once.** Until then it is `stopped=true notLaunched=true`, and a `BOOT_COMPLETED`
receiver will not fire for a stopped app. The hook sits correct on disk and silently never
executes. Arm it:

```sh
adb shell 'monkey -p com.termux.boot -c android.intent.category.LAUNCHER 1'
```

There is a second way to kill it: **`am force-stop com.termux`** puts the package in the stopped
state and suppresses `BOOT_COMPLETED` — you lose both adb and ssh, and only a physical launch of
the app recovers it. **Never force-stop Termux.**

## 1.7 Prove a reboot comes back

```sh
adb -s <panel-ip>:5555 reboot
for i in 1 2 3 4 5 6; do sleep 20; printf 't+%ds: ' $((i*20)); \
  for p in 5555 8022; do nc -z -w2 <panel-ip> $p && printf '%s OPEN  ' $p || printf '%s -  ' $p; done; echo; done
```

A real run:

```
t+65s: adb=down ssh=down
t+85s: adb=up   ssh=down
```

`adbd` came back; `sshd` did not, because Termux:Boot had not been armed. **Do not proceed
until a reboot gives you 5555 back** — Stage 4 reboots, and this is your only path back.

## 1.8 Revert the DNS record

Delete it and confirm resolution returns to `50.116.16.103`. A stale record silently breaks the
real store and firmware lookups, and the failure looks like an empty grid, not an error.

---

# Stage 2 — Back up

```sh
for p in boot dtbo system vendor product vbmeta; do
  su 0 sh -c "dd if=/dev/block/by-name/${p}_a of=/data/local/tmp/${p}_a.img bs=4M"
done
```

`adb pull` each one off the device, `sha256sum` both copies, store them off-panel.

> `adb push` and `adb pull` **cannot create or read `/data/local/*`** — `adbd` runs as shell.
> Write there as root, then pull with `adb exec-out`.

## 2.1 What the backup does and does not buy you

Two facts that were learned the hard way:

- **Stock Android 10 came up with no Ethernet carrier** on this panel. U-Boot brings up the
  ADIN1300 PHY, then the kernel disables it at **3.554 s** because the A10 overlay's
  `regulator-eth-phy` has neither `regulator-always-on` nor `boot-on`. No `Link is Up` in 427 s
  of log. A rollback to A10 is a **dark panel with no network**.
- The same defect exists on A15 unless the regulator is marked — see Stage 5.

So the A10 backup is a last resort, not a safety net. Your real fallback is the **other A15
slot**.

---

# Stage 3 — The image set

Either build it ([04-android15-port.md](04-android15-port.md)) or take the release. Verify:

```sh
sha256sum -c SHA256SUMS
```

Every partition must say **OK**. Then optionally the AVB signature against the public AOSP test
key — **all six images must be in one directory** or it fails on the first missing partition:

```sh
AVB=$ANDROID_BUILD_TOP/out/host/linux-x86/bin/avbtool
KEY=$ANDROID_BUILD_TOP/external/avb/test/data/testkey_rsa4096.pem
"$AVB" verify_image --image vbmeta.img --key "$KEY"
```

A good run ends with `vbmeta: Successfully verified SHA256_RSA4096` and one line per partition.
The `for image of` sizes are **payload sizes**, not partition sizes — they will not match the
file listing, and that is correct.

## 3.1 Integrity is not content

Hashes passing does not mean the image is right. Four independent defects darkened this panel,
each sufficient on its own:

| Defect | What it looks like |
|---|---|
| DT overlay never in the build chain | device boots a stock DART tree |
| 16 panel drivers built but not shipped | device tree has no drivers behind it |
| `vbmeta` chains `boot` | slot parks in USB fastboot, tries never drain |
| `/avb` GSI keys missing from the ramdisk | fstab demands keys that are not there |

Check content before arming:

1. **The kernel decompresses under 32 MiB** (`fb_fsl_boot.c:47 DST_DECOMPRESS_LEN`). At
   36,915,712 B it overflows, prints `Decompress kernel fail!`, and parks U-Boot in fastboot.
2. **Drivers are installed** (`.ko` present) and **listed in `modules.load`**.
3. **Every DT node's `compatible` has a loaded driver.**
4. **`vbmeta` has five descriptors, `flags=0`, and no `boot` chain.**

> The `.ko` vs `.o` trap: a check that matched the module list against a file listing `.o`
> returned `0` and read as "nothing shipped". It was the opposite.

---

# Stage 4 — Flash the inactive slot

**Write the slot you are not running.** That is the whole safety model.

## 4.1 Which slot

```sh
adb shell 'getprop ro.boot.slot_suffix'
```

`_a` means write `_b`, and vice versa. Re-read it inside every write (below) — the guard matters.

## 4.2 Write, and verify by reading back

Two things silently corrupt a slot:

1. **`system`/`vendor`/`product` may ship as Android sparse images** (magic `3aff26ed`).
   `dd`-ing a sparse file writes the **block map**, not the filesystem. Convert with `simg2img`.
2. **Read back exactly the bytes you wrote.** Hashing a whole partition against a shorter file
   reports a meaningless mismatch — this produced a false `vbmeta_b` failure.

```sh
P=b
T=/data/local/tmp
for n in boot dtbo system vendor product vbmeta; do
  src=${n}.img
  if [ "$(head -c4 "$src" | od -An -tx1 | tr -d ' \n')" = "3aff26ed" ]; then
    simg2img "$src" $T/raw-$n.img && src=$T/raw-$n.img
  fi
  sz=$(stat -c %s "$src"); want=$(sha256sum "$src" | cut -d' ' -f1)
  adb push "$src" $T/w.img
  adb shell "su 0 sh -c '
    test \"\$(getprop ro.boot.slot_suffix)\" != _$P || exit 9
    dd if=$T/w.img of=/dev/block/by-name/${n}_${P} bs=1M conv=notrunc,fsync
    sync'"
  got=$(adb shell "su 0 sh -c 'echo 3 > /proc/sys/vm/drop_caches; \
        head -c $sz /dev/block/by-name/${n}_${P} | sha256sum'" | cut -d' ' -f1)
  [ "$got" = "$want" ] && echo "$n VERIFIED $got" || { echo "$n MISMATCH"; exit 1; }
done
```

`drop_caches` before the read-back matters: the page cache will otherwise hand you back the
bytes you just wrote.

**Two ways this goes wrong and looks fine:**
- Two concurrent runs pushing to the same `/data/local/tmp/w.img` produce spurious verify
  failures. Serialise with `flock`.
- A `declare -A` table listing only three partitions, under `set -u`, aborts the loop after
  three successful writes.

## 4.3 Arm the slot

The slot decision is **32 bytes at `misc` offset `0x800`**. There is no `avbab`, `avbctl` or
`set_active` on the stock Android 10 build — `set_active` is a *fastboot protocol* command, not
a shell command.

Layout: magic `\0AB0`, version, then per-slot `{priority, tries, successful, rsv}` at bytes
8–11 (A) and 12–15 (B), `last_boot` at 16, **CRC32 over bytes 0–27 stored big-endian at 28**.

```python
import struct, zlib
b = bytearray(32)
b[0:4] = b"\x00AB0"; b[4] = 1; b[5] = 0
b[8:12]  = bytes([14, 0, 1, 0])       # A: priority 14, 0 tries, successful
b[12:16] = bytes([15, 4, 0, 0])       # B: priority 15, 4 tries, not yet successful
put = lambda o, v: struct.pack_into(">I", b, o, v)
put(28, zlib.crc32(bytes(b[0:28])) & 0xffffffff)
open("ab.bin", "wb").write(b)
```

Write only those 32 bytes — `seek=2048` is `0x800`, `conv=notrunc` keeps the rest of `misc`:

```sh
adb push ab.bin /data/local/tmp/ab.bin
adb shell 'su 0 sh -c "
  dd if=/data/local/tmp/ab.bin of=/dev/block/by-name/misc bs=1 seek=2048 conv=notrunc; sync
  dd if=/dev/block/by-name/misc bs=1 skip=2048 count=32 | od -An -tx1"'
```

Expect `00 41 42 30 01 00 00 00 0e 00 01 00 0f 04 00 00 ... 06 ef 18 bb`.

> **The priority trap.** A flip specified as **B=15, A=15** is a tie, and `avb_ab_flow.c:297`
> compares strictly `>`. B would never boot. Always make the target **strictly** higher.

> **The wrong-header trap.** The AOSP build tree ships a `bootloader_control` struct
> (`0x42414342`) that is **absent from this panel's U-Boot in both endiannesses**. Writing from
> that header produces valid-looking garbage. The panel speaks libavb_ab `AvbABData` (`\0AB0`),
> which is what is written above.

> **The 30-minute self-revert.** `init.nxp.rc:272` runs `tt_misc_writer guard ${ro.boot.slot_suffix} 1800`.
> An **unmarked** A15 boot returns to the previous slot half an hour later, and it presents as
> `A15 came up and then died`. If you see that, look for the guard before you debug anything.

Then `adb reboot`.

---

# Stage 5 — First boot

Expect 60–90 s. Then check, in this order:

```sh
adb shell 'getprop ro.boot.slot_suffix; getprop sys.boot_completed'
```

## 5.1 If it does not boot

**There is no automatic fallback. Do not count on one.**

The deployed U-Boot's `get_curr_slot` is **priority-only** — it never reads `tries_remaining`.
Exhausting the counter does **not** select the other slot.

And the most likely failure does not even decrement it: an oversized kernel parks U-Boot in USB
fastboot with the record untouched. On this panel the console read `B{15,4,0}`, unchanged.

Recovery:

| Path | Needs | Status |
|---|---|---|
| U-Boot console → rewrite `misc+0x800` | UART adapter, wall open | **proven** — one 512-byte `mmc write` restored A10 with `/data` and the Play registration intact |
| **Watchdog** | nothing | **proven** — reset the panel unattended (uptime 30,628 → 106, new `boot_id`) |
| Fastboot / SDP | USB | not available |
| Recovery | USB | not available |

**Before concluding the UART is dead, use a real capture tool.** Ad-hoc `stty`/`dd` reads return
0 bytes on a healthy console and read as silence. A two-fd serial open (`3u` + `15u`) produces
phantom `0 bytes` indefinitely. Open the port once, log continuously, and match on `u-boot=>`.

## 5.2 The named reasons an A15 kernel dies silently

In the order this panel hit them. Each was fixed and the next one appeared.

1. **`imx8mm_clk_driver_init+0x0/0x2c` never returns.** `initcall_debug` names it. Two plausible
   fixes (UART4 critical clock; removing the M4 SMC) were proven present in the flashed kernel
   and still failed. The real fix is **`init-on-array` on the CCM node**: 6.6's
   `imx_clk_init_on()` returns early without it, so no AXI/AHB/NOC/DRAM bus clocks are enabled.
2. **cpufreq parks the cores on the PLL it resets.** `clk-imx8mm.c:648` registers the ARM cpu
   clock with `step == mux`, so `clk_cpu_set_rate` asserts the ARM PLL reset while the cores are
   still on it. `cpufreq.off=1` removes the stall; an unmitigated control boot still hangs at
   1.897 s.
3. **init waits 10 s for partitions.** `androidboot.boot_devices=…30b60000.mmc`.
4. **fstab lists bare names.** `system`/`vendor`/`product` → `Invalid ext4 superblock`; rewrite
   to `/dev/block/by-name/…`, and set `androidboot.fstab_suffix=nxp`.
5. **A10's ext4 `/data` blocks the f2fs format.** A gated **1 MiB zero write at LBA
   `0x103b800`** makes `partition_wiped()` true. Identify the partition by its ext4 superblock
   magic at `+0x438` — this U-Boot has **no `part list`**.

After all five: `[302.754052] init: processing action (sys.boot_completed=1)`.

## 5.3 If the screen is black but the system is up

Three distinct causes, all seen here. Identify which before fixing:

| Cause | Signal | Fix |
|---|---|---|
| Heap name mismatch | `No ion heap of name reserved-uncached exists`; galcore using only 12 MiB | rename the DT node to match NXP gralloc's `reserved` / `reserved-uncached` |
| pinctrl conflict | `30660000.pwm` returns `-22`; backlight and `panel-lvds` **defer forever** | `bt-buffer` steals `SPDIF_EXT_CLK`; move it |
| `NoSuchMethodError` | `NoSuchMethodError: freezeRotation(I)V` at `HardwareService.onBind` | the vendor catches `Exception`; `NoSuchMethodError` is an `Error`. `.catch` → `.catchall`, re-sign |

The third one is worth internalising: `HardwareService.onBind` never completes, so downstream
init never runs, so the service looks dead. Screencap went from 3,867 B to 934,068 B.

**`CmaFree` is not a CMA health metric.** B booted with 320 MiB reserved, `CmaFree` 12 MB,
`maxchunk` 42367 and **zero** `__cma_alloc` failures.

## 5.4 Ethernet

Two independent causes. Fixing either alone yields nothing:

1. **`reg_eth_phy` has `regulator-boot-on` but not `regulator-always-on`** — the regulator core's
   30 s cleanup switches the PHY rail off at ~32 s. Same defect kills A10.
2. **`fec.ko` cannot load** because `ptp.ko` and `pps_core.ko` live in an SELinux-denied path.
   Also: `gpio-pca953x.ko` (whose hog releases `enet_rst`) loads at `modules.load` index 59 while
   `fec.ko` is at 37 — no softdep, so the PHY probe finds nothing and never retries.

A third, unrelated failure mode: the `eth0` policy routing table can empty itself. Restoring two
routes fixes gateway, internet and adb in the same boot.

## 5.5 Touch

The stock Android 10 driver contains, verbatim:

```c
if (irq == 65) { return IRQ_HANDLED; }
```

A deliberate vendor patch (commit `66eb455`, 2020-08-17). **There is no working CHG interrupt on
this board.** Every software attempt is a clean negative: SION `0x10`, pad `0x16`, boot-owned
pin, the exact stock driver, T18 MODE/RETRIGEN/forced COMMAND 3 — all leave `T44` queued and
IRQ 24 at zero.

So touch is **polled**, in the driver, at 20 ms. A userspace poll helper works but **silently
dies at 100,003 unhandled calls**:

```
irq 24: nobody cared (try booting with the "irqpoll" option)
Disabling IRQ #24
```

Set `IRQ_IS_POLLED` on IRQ 24 only. Soaked to 135,850 calls with zero spurious.

---

# Stage 6 — Get it back

The A15 image is built to need nothing, because `/data` is wiped by the flash. Three properties
are compiled into `/system/build.prop`:

```
ro.adb.secure=0
persist.adb.tcp.port=5555
persist.sys.usb.config=adb
```

AOSP `usbd` reads `persist.sys.usb.config` and issues `ctl.start adbd` itself — at **~21 s** of
kernel time, with no Termux and no boot hook. `adbd` then binds TCP from
`persist.adb.tcp.port` (`daemon/main.cpp:270`).

**So after a flash: `adb connect <panel-ip>:5555`.** Expect it. Verify it. Do not assume it.

> `/vendor/build.prop` carries two of those properties and init **rejects both**
> (`SELinux permission check failed`, `scontext=u:r:vendor_init:s0`). Only `/system` loads.

## 6.1 Make Chrome work

The image ships a Vulkan ICD labelled so that apps can open it, but Chrome still needs to be
told to use it. **This lives on `/data`, so a flash wipes it — redo this step after every
install.**

```sh
adb shell 'echo "_ --use-gl=angle --use-angle=vulkan --enable-features=Vulkan" \
  > /data/local/tmp/chrome-command-line'
adb shell 'chmod 644 /data/local/tmp/chrome-command-line'
```

The leading `_` is required. Prove Chrome read it:

```sh
adb logcat | grep 'COMMAND-LINE FLAGS'
# I cr_CommandLine: COMMAND-LINE FLAGS: [_, --use-gl=angle, --use-angle=vulkan, --enable-features=Vulkan] (from /data/local/tmp/chrome-command-line)
```

Without this, Chrome dies with `GLES3 is unsupported and ES version fallback is disabled`
followed by `GPU process isn't usable` — the panel's GPU is an ES 2.0 part and Chrome requires
GLES3. The full explanation is in [12-apps-and-control.md](12-apps-and-control.md).

**Wait for the panel to settle before the first launch.** Chrome can ANR with
`Input dispatching timed out` while post-boot load is still high. Measured settle is 291–334 s:

```sh
until awk -v l="$(adb shell cut -d' ' -f1 /proc/loadavg)" 'BEGIN{exit !(l<1.0)}'; do sleep 5; done
adb shell 'am start -n com.android.chrome/com.google.android.apps.chrome.Main -d about:blank'
```

The flag file stays put across ordinary reboots — `init.rc` only `mkdir`s `/data/local/tmp` and
never clears it. It is the flash that removes it.

---

## 6.2 Termux and SSH do not survive

`/data` is wiped. If you want SSH back as a second, independent path, redo Stage 1. On the
deployed panel this was never done: `pm list packages | grep -c termux` → `0`, `init.svc.sshd`
unset, 8022 closed.

That is a working state — but adb is then the **only** remote path, and it is one point of
failure.

---

## What you should have at the end

- Android 15 booting, `sys.boot_completed=1`
- adb on 5555, root via `adb shell su 0 …`
- display, touch, audio, Ethernet, CAN and Bluetooth working
- the shower app running, with a navigable UI
- Chrome launching and rendering, after the flags in §6.1 and once load has settled

Known defects that remain are tracked as issues, not described here —
[07-open-issues.md](07-open-issues.md).
