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

Stock has a Play Store and side-loading enabled. No account is needed for any of this.

### 1.1 Install Aurora Store

Aurora is an open-source Play Store client. Download the APK from its site or F-Droid and
side-load it (`adb install` or a file manager). It lets you fetch the next two apps without
signing a Google account into the panel.

### 1.2 Install Termux and Termux:Boot

Through Aurora, install:

- **Termux** — the terminal environment
- **Termux:Boot** — makes scripts run at boot (this is what gives you *persistence*)

Launch Termux once so it unpacks its bootstrap.

### 1.3 Get root and start sshd

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

### 1.4 Start adb

```sh
su 0 setprop ctl.start adbd
```

`adb connect <panel-ip>:5555` should report a device with `uid=0(root)`.

Add it to the same boot hook if you want adb back automatically.

### 1.5 Verify you have what you need

```sh
ssh -p 8022 <panel> 'id; su 0 id'
adb -P 5038 -s <panel-ip>:5555 shell 'su 0 id'
```

Both must show root. If either fails, stop here — flashing without two working paths is how
panels get bricked.

---

## Stage 2 — Flash Android 15

### 2.1 Download the image set

Grab the release assets for this repo (six `.raw` files) and verify them:

```sh
sha256sum -c SHA256SUMS
avbtool verify_image --image vbmeta.raw --key testkey_rsa4096.pem
```

The expected hashes are in [`../build/README.md`](../build/README.md).

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
  adb push ${n}.raw /data/local/tmp/${n}.raw
  adb shell "su 0 sh -c '
    test \"\$(getprop ro.boot.slot_suffix)\" != _$P || exit 9
    dd if=/data/local/tmp/${n}.raw of=/dev/block/by-name/${n}_${P} bs=4M conv=notrunc,fsync
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

If it does not boot: **switch the active slot back to the old one in U-Boot** (see
[`06-procedures.md`](06-procedures.md) §D). That is why you left it untouched.

### 2.6 Rebuild the access stack

**A system flash wipes `/data`, and with it Termux, sshd, and every boot hook.** Until you
redo Stage 1 on the new build, the panel has no remote access.

Do §1.2–§1.4 again on the Android 15 build. Then verify with
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
