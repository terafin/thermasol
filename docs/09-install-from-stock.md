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

Stock has side-loading enabled and **no adb**. The way in is the panel's **own app store**: it
fetches an HTTP listing from a hostname we can redirect, so if you point that hostname at a
machine you control, the panel installs whatever you put there.

This is the route that was actually used. There is no Play Store client involved and no Google
account anywhere in it.

### 1.1 Stand up the mirror

`scripts/store-mirror/fetch_bootstrap.py` downloads and verifies the APK set; `serve_store.py`
serves it in the shape the vendor app expects. Full runbook:
[11-vendor-store-mirror.md](11-vendor-store-mirror.md).

```sh
./scripts/store-mirror/fetch_bootstrap.py --out ./store \
    --apksigner /path/to/apksigner.jar --aapt /path/to/aapt
./scripts/store-mirror/serve_store.py --root ./store --port 80 \
    --base-url http://<your-server-ip> --log
```

### 1.2 Point the vendor hostname at it

Add a local-DNS A record on whatever serves the panel's VLAN:

```
thermatouch.tsolup.com.   A   <your-server-ip>
```

A UniFi gateway local-DNS record is what was used; a router, dnsmasq or pihole entry does the
same job. Confirm it with a query against **the resolver the panel uses**, not your own:

```sh
dig +short @<panel's-gateway> thermatouch.tsolup.com
```

### 1.3 Install Termux from the panel's own store

On the panel, open the app's **Settings → App Store** and install **Termux**.

Launch it once so it unpacks its bootstrap. `--log` on the server shows the exact request lines
if anything looks wrong.

### 1.4 Get root and start sshd

The stock build is `userdebug`, so `su` works. In Termux:

```sh
pkg install openssh
mkdir -p ~/.ssh && chmod 700 ~/.ssh
# paste your public key:
cat > ~/.ssh/authorized_keys <<'KEY'
ssh-ed25519 AAAA... your-key-here
KEY
chmod 600 ~/.ssh/authorized_keys
sshd                       # listens on 8022
```

Make it survive reboots:

```sh
mkdir -p ~/.termux/boot
cat > ~/.termux/boot/00-restore-access <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock
sshd
SH
chmod +x ~/.termux/boot/00-restore-access
```

Now `ssh -p 8022 <panel>` works, and keeps working across reboots.

### 1.5 Start adb

```sh
su 0 setprop ctl.start adbd
```

`adb connect <panel-ip>:5555` should report a device with `uid=0(root)`.

### 1.6 Install Termux:Boot

Termux:Boot was **not** installed through the store on the original run. Now that adb works,
push it:

```sh
adb install --no-incremental -r store/apks/com.termux.boot.apk
```

It is what gives you *persistence* — without it the shell dies at the next reboot. Do not stop
before this is on.

Once it is installed, the boot hook from §1.4 runs on every boot and both `sshd` and access
survive a reboot. **Revert the DNS record now** (§1.2) and confirm with `dig` that
`thermatouch.tsolup.com` resolves to the real vendor address again.

Add it to the same boot hook if you want adb back automatically.

### 1.7 Verify you have what you need

```sh
ssh -p 8022 <panel> 'id; su 0 id'
adb -P 5038 -s <panel-ip>:5555 shell 'su 0 id'
```

Both must show root. If either fails, stop here — flashing without two working paths is how
panels get bricked.

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

### 2.3 Push and write, one partition at a time

```sh
P=b            # the INACTIVE slot, from 2.2
for n in boot dtbo system vendor product vbmeta; do
  adb push ${n}.img /data/local/tmp/${n}.img
  adb shell "su 0 sh -c '
    test \"\$(getprop ro.boot.slot_suffix)\" != _$P || exit 9
    dd if=/data/local/tmp/${n}.img of=/dev/block/by-name/${n}_${P} bs=4M conv=notrunc,fsync
    blockdev --flushbufs /dev/block/by-name/${n}_${P}
    sha256sum /dev/block/by-name/${n}_${P}
  '"
done
```

**Compare every read-back hash** to the expected value before continuing. A mismatch means
stop, do not reboot.

### 2.4 Arm the new slot and reboot

```sh
adb shell 'su 0 sh -c "avbab arm-deploy ${P}; sync"'
adb reboot
```

If `avbab` is not available on your stock build, write the A/B metadata directly — the record
lives in `misc` at offset `0x800` (32 bytes: magic `\0AB0`, version 1, per-slot
priority/tries/successful, CRC32 of the first 28 bytes at offset 28). Set the target slot's
priority to 15 with 2 tries, and the current slot's to 14.

### 2.5 First boot

Expect ~60–90 seconds. The panel will come up on Android 15.

### If it does not boot

**First, wait for the guard.** The bootloader stamps 2 tries on the new slot. A failed boot
decrements it, and once it reaches zero the slot is marked unbootable and the other slot — the
one you did not touch — is selected automatically. This is a reset, not a decision; it does
not need you.

**If the full 2 tries are consumed and the panel comes back on the old slot**, you are where
you started and nothing is lost. That is the whole point of writing only the inactive slot.

**If the panel does not come back at all**, you are into `retrial`:

| Path | Needs | When it works |
|---|---|---|
| U-Boot console → switch active slot | UART adapter, wall open | always |
| Fastboot / SDP | USB | **not available on this panel** |
| Recovery | USB | **not available on this panel** |

So on a sealed panel with no UART adapter, a panel that will not boot on *either* slot is not
recoverable by software. The guard is what stops you getting there: it will fall back unless
the boot hangs in a way that never lets the tries decrement.

### 2.6 Rebuild the access stack

**A system flash wipes `/data`, and with it Termux, sshd, and every boot hook.** Until you
redo Stage 1 on the new build, the panel has no remote access.

Do all of Stage 1 again on the Android 15 build — §1.1 through §1.6, including the redirect,
the Termux install, the boot hook and Termux:Boot. Then verify with
[`06-procedures.md`](06-procedures.md) §B.

> On the A15 build `adbd` still needs the same manual start; there is no vendor hook that
> starts it. The boot script is the thing that makes this survivable.

---

## What you get, and what you do not

Verify all of this on *your* panel rather than trusting this document:

- Steam, lights, speaker: controlled over CAN, verified end-to-end.
- Display, touch, audio, Bluetooth: working.
- Play Store, native YouTube, Plex, Netflix: working.
- Idle: backlight to 0, lights off, speaker standby after 5 minutes.
- **Not fixed:** the ceiling speaker hiss (see [`07-open-issues.md`](07-open-issues.md)).
- **Do not use:** deep suspend. It never wakes; recovery is the breaker.
