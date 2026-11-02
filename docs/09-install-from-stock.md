# 09 — Installing this image on a stock panel

This is the guide that makes the rest of the repo useful: you have a stock ThermaSol
ThermaTouch TT10V2 running Android 10, and you want it running the Android 15 build in
`../build/`.

It works in two stages. **Stage 1 gets you a shell on a completely stock panel** — no
soldering, no UART, no opening the wall. **Stage 2 uses that shell to flash.**

Read [`06-procedures.md`](06-procedures.md) before doing anything destructive. Read
[`07-open-issues.md`](07-open-issues.md) so you know what you are and are not getting.

---

## Before you start

| You need | Why |
|---|---|
| A TT10V2 panel reachable on your LAN | obviously |
| A machine with `adb` and a browser | to drive it |
| ~30 minutes and a power cycle you can perform | physical access to the breaker |
| A backup of your panel's current state | see §0 |

**This is irreversible without a backup.** Slot A holds the stock image; capture it before
you overwrite anything.

### The one thing that will bite you

There is **no USB, no reset button, and no documented recovery** on this device. Once you
start flashing, your only recovery paths are the A/B slot you did *not* touch, and the UART
(which needs the wall open). Keep slot A intact. Verify it before every write.

---

## Stage 0 — Back up before touching anything

Once you have a shell (§1), capture slot A:

```sh
for p in boot dtbo system vendor product vbmeta; do
  su 0 sh -c "dd if=/dev/block/by-name/${p}_a of=/data/local/tmp/${p}_a.img bs=4M"
done
```

Then `adb pull` each one off the device and record `sha256sum` for both copies. Those files
are your rollback. Store them somewhere that is not the panel.

> **Verify the backup actually boots before you rely on it.** On this unit, Android 10 came up
> with **no ethernet carrier** — the A10 overlay's `regulator-eth-phy` lacks
> `regulator-always-on`/`boot-on`, so the kernel disables the PHY at 3.554 s and there is never
> a `Link is Up`. A "successful" rollback to A10 would have been a dark panel with no network
> and no way in. See [04-android15-port.md](04-android15-port.md) §"Rolling back" and issue
> [#9](https://github.com/terafin/thermasol/issues/9).
>
> Test the rollback path *before* the wall closes, or accept that your real safety net is the
> A15 slot you did not touch.

---

## Stage 1 — Get a shell on stock

The stock panel has **no adb** (port 5555 refused), and a full TCP scan of it returns exactly
three ports: `3500`, `57344`, `57345`. There is no USB, no shell, and no vendor mechanism to
lean on.

The way in is the panel's **own app store**. It fetches an HTTP catalogue from a hostname that
resolves through normal DNS — so point that hostname at a machine you control, and the panel
installs whatever you put there.

> **Do not expect a Play Store client to help.** This is the route that was actually used, and
> it involved no store client and no Google account at any point.

### 1.0 Find the panel

Through the UniFi controller, not a subnet scan — the switch port is labelled, and the client
record gives you the address:

```
"name": "Thermasol", "ip": "10.0.90.130", "is_wired": true, "mac": "f8:dc:7a:9c:9a:e4"
```

The panel's UPnP banner on port 3500 confirms what it is:
`Server: Linux UPnP/1.0 Sonos/74.0-44280 (ACR_:freescale:dart_mx8mm:variscite)`.

### 1.1 Stand up the mirror

`scripts/store-mirror/fetch_bootstrap.py` downloads and verifies the APK set; `serve_store.py`
serves it in the shape the vendor app expects. Full runbook:
[11-vendor-store-mirror.md](11-vendor-store-mirror.md).

```sh
./scripts/store-mirror/fetch_bootstrap.py --out ./store \
    --apksigner /path/to/apksigner.jar --aapt /path/to/aapt
sudo ./scripts/store-mirror/serve_store.py --root ./store --port 80 \
    --base-url http://<your-server-ip> --log
```

Port 80 needs root. Serve from somewhere that survives the session — a `/tmp` process started
with `nohup` works but dies with a reboot; a systemd unit does not.

**The one thing a naive server gets wrong:** the panel requests `/index.json` **and then**
`/index-10.json`. A server matching only `/index.json` returns 404 for the second and the store
shows nothing. Both names must return the same catalogue.

### 1.2 Point the vendor hostname at it

The app's base URL is compiled in:

```java
private static final String BASE_URL = "http://thermatouch.tsolup.com/";
```

Add a **local-DNS A record** for that exact hostname. A UniFi gateway record is what was used;
a router, dnsmasq or pihole entry is equivalent.

```
thermatouch.tsolup.com.   A   <your-server-ip>
```

Verify against **the resolver the panel uses**, not your own:

```sh
dig +short @<panel's-gateway> thermatouch.tsolup.com      # must return your server
```

Via the UniFi MCP tool the arguments are nested and `confirm` is required — the flat form fails
with `unknown arguments {enabled, key, ...}. Valid arguments: [confirm, record_data]`:

```json
{"confirm": true,
 "record_data": {"enabled": true, "key": "thermatouch.tsolup.com",
                 "record_type": "A", "ttl": 300, "value": "<your-server-ip>"}}
```

### 1.3 Install Termux from the panel's own store

On the panel, open **Settings → App Store** and install Termux. It fetches the catalogue from
your server and the APK from `<base>/apps/<package>.apk`.

Confirm on your server log that the panel asked for it — the requests look like this:

```
172.125.77.119 GET /index.json
  User-Agent: Dalvik/2.1.0 (Linux; U; Android 10; variscite Build/QD1A.190821.014.C2)
  Host: thermatouch.tsolup.com
172.125.77.119 GET /index-10.json
```

Launch Termux once so it unpacks its bootstrap, then set up SSH **on the panel's own
touchscreen** — install `openssh`, set a password, start `sshd` on 8022. The transcript cannot
see this step; it happened on the device's screen and there is no record of the exact commands.

```sh
# in Termux, on the panel
pkg install openssh
passwd                     # this is the password you will sshpass with
sshd                       # listens on 8022
```

### 1.4 Turn on adb — and the trap in it

`adbd` is `disabled` in init, and on this build **two obvious approaches do not work**:

| Attempt | Result |
|---|---|
| `setprop ctl.start adbd` / `ctl.restart adbd` | init logs `Received control message 'start' for 'adbd'` — and **5555 stays closed**. The restarted `adbd` takes the init USB socket. |
| `stop adbd` / `start adbd` | `stop: must be root`. From a Termux shell you are uid 10108, not root. |

Do not stop at the dmesg line. **Check the port, not the log.**

`setprop` is not on Termux's `PATH` — call it by absolute path. Then start `adbd` **detached**,
so it cannot claim the init socket and falls back to TCP:

```sh
/system/bin/setprop service.adb.tcp.port 5555
/system/bin/setprop persist.adb.tcp.port 5555
setsid /system/bin/adbd >/dev/null 2>&1 &
```

A successful run logs `adbd E auth.cpp:240] Failed to get adbd socket: Success` — that failure
**is the mechanism**. Confirm from your workstation:

```sh
adb connect <panel-ip>:5555
adb -s <panel-ip>:5555 shell 'id; getprop ro.debuggable'
```

Root comes from `adb root` (`restarting adbd as root` → `uid=0(root)`), which works because the
stock build is `userdebug` (`ro.debuggable=1`) with SELinux `Permissive`.

> **Do not leave `service.adb.root` set.** A leftover `adb root` flag makes `adbd` abort on
> startup and crash-loop. Clear it with `setprop service.adb.root ""` before you rely on a
> reboot coming back.

### 1.5 Install Termux:Boot, and the step everyone forgets

```sh
adb install --no-incremental -r store/apks/com.termux.boot.apk
```

Then the boot hook, as the Termux user (`su` on this build takes a **uid**, not `-c`):

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
/system/bin/setprop persist.adb.tcp.port 5555
```

**The forgot-step: a freshly installed Termux:Boot never runs until the package has been
launched once.** Until then it is `stopped=true notLaunched=true`, and a boot-completed receiver
will not fire for a stopped app. Arm it:

```sh
adb shell 'monkey -p com.termux.boot -c android.intent.category.LAUNCHER 1'
```

Without that, the hook is on disk, correct, and silently never executes.

### 1.6 Verify a reboot comes back

```sh
adb -s <panel-ip>:5555 reboot
# then poll — do not assume
for i in 1 2 3 4 5 6; do sleep 20; printf 't+%ds: ' $((i*20));   for p in 5555 8022; do nc -z -w2 <panel-ip> $p && printf '%s OPEN  ' $p || printf '%s -  ' $p; done; echo; done
```

A real run from this phase:

```
t+65s: adb=down ssh=down
t+85s: adb=up   ssh=down
```

`adbd` comes back on its own — that is what `persist.adb.tcp.port` plus the `userdebug` build get
you. `sshd` did **not**, because Termux:Boot was still `notLaunched`; it needed the `monkey` arm
in §1.5 first.

**Do not move on until a reboot gives you 5555 back.** Everything after this depends on a shell
that survives a restart — and Stage 2 reboots.

### 1.7 Revert the DNS record

Once Termux is installed you do not need the redirect. Delete it and confirm resolution returns
to the real vendor address (`50.116.16.103`). A stale record silently breaks the panel's real
store and firmware lookups, and the failure looks like an empty app grid, not an error.

---

## Stage 2 — Flash Android 15

### 2.1 Download the image set

Six `.img` files plus `SHA256SUMS`, from the release page of this repo — about 4.4 GB, and
`product` and `system` are 1.75 GiB each, so check free space first.

```sh
sha256sum -c SHA256SUMS
```

Every partition must report **OK** before you continue. A single FAILED means a truncated or
wrong download, and the fix is to fetch it again — not to proceed.

The same hashes are listed in [`../build/README.md`](../build/README.md) with byte counts, so
you can cross-check without trusting one source.

### 2.1b Optional — verify the AVB signature too

`vbmeta.img` is signed with the **public AOSP test key**, so this is checkable by anyone. It
proves something the hashes cannot: that the image set is internally consistent, every
partition hash inside `vbmeta` matching the partition you actually have.

**All six images must be in the same directory**, or it fails on the first missing one:

```sh
AVB=$ANDROID_BUILD_TOP/out/host/linux-x86/bin/avbtool
KEY=$ANDROID_BUILD_TOP/external/avb/test/data/testkey_rsa4096.pem   # same as the BSP key
"$AVB" verify_image --image vbmeta.img --key "$KEY"
```

A good run ends:

```
vbmeta: Successfully verified SHA256_RSA4096 vbmeta struct in vbmeta.img
boot:   Successfully verified sha256 hash of boot.img for image of 34469888 bytes
dtbo:   Successfully verified sha256 hash of dtbo.img for image of 69099 bytes
product: Successfully verified sha256 hashtree of product.img for image of 948834304 bytes
system:  Successfully verified sha256 hashtree of system.img for image of 861192192 bytes
vendor:  Successfully verified sha256 hashtree of vendor.img for image of 84840448 bytes
```

Note the `for image of` sizes are **payload sizes, not partition sizes** — they will not match
the file listing. That is correct, not a mismatch. Skip this step if you do not have a build
tree; `sha256sum -c` already proves you have the same bytes.

### 2.2 Decide which slot to write

Whichever slot **is not currently running**. Check with:

```sh
adb shell 'getprop ro.boot.slot_suffix'
```

If the panel is on `_a`, you write the `_b` partitions, and vice versa. **Never write the
running slot.**

### 2.3 Write each partition, and verify by reading it back

Two things will silently corrupt a slot if you skip them:

1. **`system`/`vendor`/`product` ship as Android sparse images** (magic `3aff26ed`). `dd`-ing a
   sparse file writes the **block map**, not the filesystem. Convert with `simg2img` first.
2. **Read back exactly the bytes you wrote.** Hashing the whole partition against a file smaller
   than the partition reports a meaningless mismatch.

```sh
P=b                        # the INACTIVE slot
T=/data/local/tmp
for n in boot dtbo system vendor product vbmeta; do
  src=${n}.img
  # sparse -> raw, if needed
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
  [ "$got" = "$want" ] && echo "$n VERIFIED $got" || { echo "$n MISMATCH want=$want got=$got"; exit 1; }
done
```

That is the real shape from the deployment script — including the `test slot != _$P` guard and
the `drop_caches` before the read-back, which matters because the page cache will otherwise hand
you the bytes you just wrote.

**Gotchas that actually bit:**

- `declare -A WANT` listing only three partitions, under `set -u` → the script aborts after three
  successful writes with `WANT[$part]: unbound variable`.
- Two concurrent runs pushing to the same `/data/local/tmp/w.img` → spurious verify failures.
  Serialise with `flock -n 9`.

### 2.4 Arm the new slot

The slot decision is **32 bytes at `misc` offset `0x800`**. There is no `avbab`, `avbctl` or
`set_active` available on the stock Android 10 build — `set_active` is a *fastboot protocol*
command, not a U-Boot shell command.

Layout: magic `\0AB0`, version, then per-slot `{priority, tries, successful, rsv}` at bytes
8–11 (A) and 12–15 (B), `last_boot` at 16, and a **CRC32 over bytes 0–27 stored big-endian at
offset 28**.

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
  dd if=/data/local/tmp/ab.bin of=/dev/block/by-name/misc bs=1 seek=2048 conv=notrunc
  sync
  dd if=/dev/block/by-name/misc bs=1 skip=2048 count=32 | od -An -tx1"'
```

Expected read-back — `0e 00 01 00` for A, `0f 04 00 00` for B, CRC `06 ef 18 bb` on the end:

```
00 41 42 30 01 00 00 00 0e 00 01 00 0f 04 00 00
00 00 00 00 00 00 00 00 00 00 00 00 06 ef 18 bb
```

Then `adb reboot`.

### 2.5 First boot

Expect ~60–90 seconds. The panel will come up on Android 15.

### If it does not boot

**First, wait for the guard.** The bootloader stamps 2 tries on the new slot. A failed boot
decrements it, and once it reaches zero the slot is marked unbootable and the other slot — the
one you did not touch — is selected automatically. This is a reset, not a decision; it does
not need you.

**If the full 2 tries are consumed and the panel comes back on the old slot**, you are where
you started and nothing is lost. That is the whole point of writing only the inactive slot.

**But the guard does not always fire.** It only decrements when the bootloader gets far enough to
record a failure. A kernel too large for U-Boot's decompress window is the case that bit this
panel: over 32 MiB, U-Boot prints `Decompress kernel fail!` and jumps to USB fastboot, the try
counter **never decrements**, and the panel sits dark indefinitely. On the console the record
still read `B={15,4,0}` — unchanged, proving it never even counted.

That is a recovery-by-console situation, and it is why §2.6 says verify the image content, not
just its hash.

**If the panel does not come back at all**, you are into `retrial`:

| Path | Needs | When it works |
|---|---|---|
| U-Boot console → switch active slot | UART adapter, wall open | always |
| Fastboot / SDP | USB | **not available on this panel** |
| Recovery | USB | **not available on this panel** |

So on a sealed panel with no UART adapter, a panel that will not boot on *either* slot is not
recoverable by software. The guard is what stops you getting there: it will fall back unless
the boot hangs in a way that never lets the tries decrement.

### 2.6 Check the image CONTENT before you trust a successful boot

Integrity passing does not mean the image is right. The dark panel that cost a day had passed
every gate available — size, AVB layout, signature pubkey, CRC, boot header version, page size —
and still would not boot. Two content defects:

- **Kernel too big.** This U-Boot decompresses a non-raw kernel into a **32 MiB** window
  (`fb_fsl_boot.c:47 DST_DECOMPRESS_LEN`). A kernel of 36,915,712 B overflows it, deterministically.
  Check the uncompressed kernel size before flashing.
- **Wrong device tree.** Flashing a `dtbo` from a different board tree produces a dark panel with
  no network. Compare against the panel's own.

Check both *before* arming the slot — after arming, the only ways back are the guard (which may
not fire) and the console.

### 2.7 Rebuild the access stack

**A system flash wipes `/data`, and with it Termux, sshd, and every boot hook.** Until you redo
Stage 1 on the new build, the panel has **no remote access at all**.

**On the Android 15 image you built in §2, adb comes back by itself.**
`persist.adb.tcp.port=5555`, `persist.sys.usb.config=adb` and `ro.adb.secure=0` are compiled into
`/system/build.prop` and `/vendor/build.prop`. `adbd` starts at ~21 s with no Termux, no boot
hook, and nothing typed. Verified on the deployed panel.

So after the flash:

1. `adb connect <panel-ip>:5555` — expect it within a few seconds of boot.
2. Verify with [`06-procedures.md`](06-procedures.md) §B before you walk away.

**Termux and sshd do not survive the flash, and were never reinstalled on this build.** The
panel runs on adb alone: `pm list packages | grep -c termux` → `0`, `init.svc.sshd` unset, 8022
closed. That is a working state, not a broken one — but it means adb is the *only* remote path,
so treat §1's redirect and Termux work as a one-time entry step, not as something to restore.

Redo §1.1–§1.6 **only if** you want SSH back as a second, independent path. It is worth having:
one transport is one point of failure.

---

## What you get, and what you do not

Verify all of this on *your* panel rather than trusting this document:

- Steam, lights, speaker: controlled over CAN, verified end-to-end.
- Display, touch, audio, Bluetooth: working.
- Play Store, native YouTube, Plex, Netflix: working.
- Idle: backlight to 0, lights off, speaker standby after 5 minutes.
- **Not fixed:** the ceiling speaker hiss (see [`07-open-issues.md`](07-open-issues.md)).
- **Do not use:** deep suspend. It never wakes; recovery is the breaker.
