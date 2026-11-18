# 15 — Panel recovery plan

One trip, one fix. Read the whole page before opening the wall. Nothing on it has been run yet.

Every fact below was checked directly against one of these, and nothing else:

- **The October backup** — `~/tt-recovery/bootarea-20261011/`, taken 2026-10-11 after the CMA
  fix. Its `host-sha256.txt` verifies. `uboot_env.img` (md5 `1b1533ff43325d1a0c437826dd9aad88`)
  is the environment the panel ran on until 2026-11-17, and `mmcblk2_first8M.img` holds the
  bootloader the panel runs (`U-Boot 2019.04-41468-ge20d4ecd9f`, May 31 2022).
- **The boot image slot B runs** — `v1.2-android15/boot.img`, sha256 `5d81612048…`.
- **The v10 environment written to the panel** — md5 `a2447cd840e29fa6b40e42b0b19ec2d5`.

## What is wrong

The panel's saved U-Boot environment holds a `bootargs` with no Android settings in it:

```
console=ttymxc3,115200 earlycon=ec_imx6q,0x30a60000,115200 clk_ignore_unused keep_bootcon panic=1
```

The v10 boot script saved it (its steps 13–15: `setenv bootargs ${payargs}; …; saveenv`) after
first setting `bootcmd` back to stock (steps 0–1). So every power-on runs the stock `boota`
with this command line. The bootloader uses a saved `bootargs` in place of the boot image's
own command line. Android's first stage then looks for its mount table. The ramdisk in
`boot.img` holds only `first_stage_ramdisk/fstab.freescale`, which is found through
`androidboot.hardware=freescale`. That token is missing, so the boot stops there. Power cycles
cannot change it, because the saved environment comes back unchanged every time.

Deleting `bootargs` is **not** a fix. The boot image's header command line has no
`androidboot.hardware` and no `init=` either:

```
androidboot.vendor.apex.com.google.android.widevine=com.google.android.widevine androidboot.lcd_density=120 earlycon=ec_imx6q,0x30a60000,115200 console=ttymxc3,115200 clk_ignore_unused printk.devkmsg=on
```

The value has to be put back.

## Do not use `env default -a`

The compiled default environment in the panel's own bootloader binary contains:

```
cmaargs=if test $sdram_size = 1024; then setenv cmavar 320M@0x400M-0xb80M; else setenv cmavar 800M@0x400M-0xb80M; fi; setenv bootargs ${bootargs} cma=${cmavar};
```

On this 2 GB panel that is `cma=800M`, the cause of the 30-second touch lag fixed on
2026-10-11. The fix below restores the October values instead.

## Tools

- The **FT232R** USB-serial adapter, with **VCCIO set to 3.3 V**. VCC stays at 5 V from USB;
  that is normal. VCCIO is the one setting that can damage the panel.
- Solid-core wire, or the wires already soldered in from October.
- A laptop or host with `picocom`. Plug the adapter in and confirm the device appears
  (`/dev/ttyUSB0` on Linux, `/dev/cu.usbserial-*` on a Mac) **before** opening the wall.

## Wiring

Header **U6** on the carrier board: **GND / TX / RX / 3P3U**, 3.3 V logic, **115200 8N1**. The
holes are through-holes, not pins, so the wire is soldered or wedged.

| Adapter | U6 |
|---|---|
| GND | GND |
| RX  | TX |
| TX  | RX |

**Leave 3P3U unconnected.** Do not connect the adapter's power to the panel.

If characters echo but no prompt comes back, re-seat **GND** first. A loose ground looks
exactly like a dead console.

## Steps

1. Turn the shower supply **off** with Home Assistant
   (`switch.bathroom_bathroom_steam_shower_power`).
2. Connect the three wires. Open the terminal: `picocom -b 115200 /dev/ttyUSB0`.
3. Press and keep pressing **Enter** in the terminal, then turn the supply **on**.
   The bootloader prints `Hit any key to stop autoboot`; any key stops it. The saved delay is 1
   second, so starting to press before power-on means the key is already there.
4. At the `=>` prompt, type these three lines. They are the exact values from the October
   backup:

   ```
   setenv bootcmd 'run cmaargs; boota ${fastboot_dev}'
   setenv cmaargs 'echo cma: using device-tree default'
   setenv bootargs 'init=/init consoleblank=0 androidboot.hardware=freescale androidboot.force_normal_boot=1 firmware_class.path=/vendor/firmware transparent_hugepage=never androidboot.primary_display=imx-drm'
   ```

5. Check them before saving:

   ```
   printenv bootcmd cmaargs bootargs
   ```

   Read each printed line against step 4, character by character. `bootargs` must contain
   `androidboot.hardware=freescale`.
6. Save and boot:

   ```
   saveenv
   reset
   ```

7. Watch the console. Within about a minute, check from a host:
   - `ping 10.0.1.32` answers
   - `adb connect 10.0.1.32:5555` connects
   - `adb shell getprop sys.boot_completed` prints `1`
   - `adb shell getprop ro.boot.slot_suffix` prints `_b`

   Close the wall only after all four pass.

## If something does not match

- **No `Hit any key` line and no prompt.** The bootloader never reached its main loop, so the
  saved environment is not the cause. Copy everything the console printed and stop. Do not
  type anything.
- **`printenv` shows something different from step 4.** Retype that line. Do not `saveenv`
  until all three match.
- **It reboots into the same hang after `reset`.** Stop at the prompt again and run
  `printenv bootargs` to confirm the save took.

## What is not touched

The bootloader itself (eMMC `0x8400`), slot A, slot B, `misc`, `vbmeta` and `dtbo` are not
written. Only three environment variables change.

## Restoring the whole environment, if needed

The October backup's environment (`uboot_env.img`, md5 `1b1533ff…`) can be written back once
Android is up again:

```
adb push uboot_env.img /data/local/tmp/
adb shell su 0 dd if=/data/local/tmp/uboot_env.img of=/dev/block/mmcblk2 bs=4096 seek=1024 count=1 conv=fsync
```

This removes the leftover variables from the v10 experiment (`payargs`, `fdtaddr`,
`bootcmd_safe`, `bootcmd_orig`). It is optional; step 4 alone fixes the boot.

## The amp

Not part of this trip. There is no known way into the amp's board yet, and no evidence about
its connectors. Planning for it starts only once the board can be seen.
