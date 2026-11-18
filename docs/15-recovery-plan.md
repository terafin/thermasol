# 15 — Panel recovery: the dark panel of 2026-11-17

**Status: done.** On 2026-11-17 the panel was recovered through the U6 console with the steps
below, and it booted slot `_b` with verified boot green, CMA at 320M and the v1.2 idle daemon
running. The same night a network recovery hook was added to U-Boot so the next dark panel can be
fixed without opening the wall: see [16-network-recovery-hook.md](16-network-recovery-hook.md).
The page is kept as the record of the failure, and as the procedure if the hook itself is ever lost.

## What the console showed, before anything was changed

```
bootcmd=run bootcmd_orig
bootargs=console=ttymxc3,115200 earlycon=ec_imx6q,0x30a60000,115200 clk_ignore_unused keep_bootcon panic=1
stage=prebooti
bootdelay=0
cmaargs=echo cma: using device-tree default
```

That is the state predicted below: the one-shot chain ran to `prebooti`, saved the payload's
command line as `bootargs`, and left `bootcmd` stock. The four values in step 4 were set, each was
compared byte for byte with the October backup, then `saveenv` and `reset`.

## What the plan was checked against

- **The October backup** — `uboot_env.img` from the boot-area backup taken 2026-10-11 after the CMA
  fix. Its `host-sha256.txt` verifies. `uboot_env.img` (md5 `1b1533ff43325d1a0c437826dd9aad88`)
  is the environment the panel ran on until 2026-11-17, and `mmcblk2_first8M.img` holds the
  bootloader the panel runs (`U-Boot 2019.04-41468-ge20d4ecd9f`, May 31 2022).
- **The boot image slot B runs** — `v1.2-android15/boot.img`, sha256 `5d81612048…`.
- **The v10 environment written to the panel** — md5 `a2447cd840e29fa6b40e42b0b19ec2d5`.

## What is wrong

The v10 environment was written to eMMC at 09:56 UTC on 2026-11-17 (md5 `a2447cd8…`), and the
supply was cycled at 09:56:43. As written, its `bootargs` is still correct. Its `bootcmd` is a
one-shot chain, and U-Boot runs that chain on the first power-on (`bootdelay=0`):

- **Steps 0–1:** `setenv bootcmd ${bootcmd_safe}; saveenv`. From then on `bootcmd` is
  `run bootcmd_orig`, which runs the stock `run cmaargs; boota ${fastboot_dev}`.
- **Steps 13–15:** `setenv bootargs ${payargs}; …; saveenv`. That saves `bootargs` as
  `payargs`, which has no Android settings in it:

```
console=ttymxc3,115200 earlycon=ec_imx6q,0x30a60000,115200 clk_ignore_unused keep_bootcon panic=1
```

Then `booti` ran the payload. Every power-on since runs the stock `boota` with that saved
command line. The bootloader uses a saved `bootargs` in place of the boot image's own command
line. Android's first stage then looks for its mount table. The ramdisk in `boot.img` holds only
`first_stage_ramdisk/fstab.freescale`, which is found through `androidboot.hardware=freescale`.
That token is missing, so the boot stops there. Power cycles cannot change it, because the saved
environment comes back unchanged every time.

What is on the eMMC after that first boot has never been read back; the panel has been dark since.
Step 4 sets all of them, so it repairs the panel whether or not the chain finished.

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

On this 2 GB panel that is `cma=800M`. That is the vendor's intended value, and it caused the
30-second touch lag fixed on 2026-10-11. Measured on this panel at 800M (Android 10,
the October work log, 3.5 minutes after a clean boot):
`workingset_refault` 40k/s and I/O pressure 75%. At the same moment `MemFree` was 598 MB, and
586 MB of that was `CmaFree`. About 600 MB sat idle in CMA while the rest of memory thrashed.
`cmaargs` was overridden to use the device-tree default (320M) at 20:21:53 that evening
(line 173). The saved environment has carried that override since, and the v10 environment on
the panel now still carries it. It has not been re-measured at 800M on Android 15. The fix below
restores the October values instead.

## Tools

The recovery itself used an ESP32 dev board (NodeMCU-32S) running ESPHome with
`oxan/esphome-stream-server`, which bridges its UART2 to a TCP port. Wiring: ESP32 `GND` → U6 GND,
`GPIO16` → U6 TX, `GPIO17` → U6 RX, ESP32 powered from its own USB supply. Any 3.3 V USB-serial
adapter works the same way:

- The **FT232R** USB-serial adapter, with **VCCIO set to 3.3 V**. VCC stays at 5 V from USB;
  that is normal. VCCIO is the one setting that can damage the panel.
- Solid-core wire, or the wires already soldered in from October.
- A laptop or host with `picocom`. Plug the adapter in and confirm the device appears
  (`/dev/ttyUSB0` on Linux, `/dev/cu.usbserial-*` on a Mac) **before** opening the wall.

## Wiring

Header **U6** on the carrier board: **GND / TX / RX / 3P3U**, 3.3 V logic, **115200 8N1**. It is
the SoC's UART4 (`ttymxc3`, the console U-Boot and the kernel print to). The holes are
through-holes, not pins, so the wire is soldered or wedged.

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
3. Start pressing **Enter** repeatedly in the terminal, and keep pressing. *Then* turn the
   supply **on**. v10 left the saved delay at **0**, not the October value of 1. At 0 the
   bootloader stops only if a key is already waiting when it checks (`common/autoboot.c`,
   `__abortboot`: one `tstc()` check, and no countdown loop). It prints
   `Hit any key to stop autoboot:  0` either way, so that line does not mean it waited. Pressing
   after power-on is too late: the panel boots straight into the hang.
4. At the `=>` prompt, first record what is there now. Copy the output into the notes; it is
   the only read-back of the environment since v10 ran:

   ```
   printenv bootcmd bootargs stage
   ```

   Expect `bootcmd` to read `run bootcmd_orig` already. The chain's first step saved that, and
   `bootcmd_orig` is the stock `run cmaargs; boota ${fastboot_dev}`. Expect `bootargs` to be the
   `payargs` line above, and `stage` to be one of the chain's markers. Then type these four
   lines; setting them all also covers any state the read-back did not predict. The first three
   are the exact values from the October backup. The last puts the 1-second delay back, so the
   next person at this prompt gets a real countdown:

   ```
   setenv bootcmd 'run cmaargs; boota ${fastboot_dev}'
   setenv cmaargs 'echo cma: using device-tree default'
   setenv bootargs 'init=/init consoleblank=0 androidboot.hardware=freescale androidboot.force_normal_boot=1 firmware_class.path=/vendor/firmware transparent_hugepage=never androidboot.primary_display=imx-drm'
   setenv bootdelay 1
   ```

5. Check them before saving:

   ```
   printenv bootcmd cmaargs bootargs bootdelay
   ```

   Read each printed line against step 4, character by character. `bootcmd` must read exactly
   `run cmaargs; boota ${fastboot_dev}`, and `bootargs` must contain
   `androidboot.hardware=freescale`.
6. Save and boot:

   ```
   saveenv
   reset
   ```

7. Watch the console. Within about a minute, check from a host:
   - `ping <panel-ip>` answers
   - `adb connect <panel-ip>:5555` connects
   - `adb shell getprop sys.boot_completed` prints `1`
   - `adb shell getprop ro.boot.slot_suffix` prints `_b`

   Close the wall only after all four pass.

## If something does not match

- **No `Hit any key` line and no prompt.** The bootloader never reached its main loop, so the
  saved environment is not the cause. Copy everything the console printed and stop. Do not
  type anything.
- **`printenv` shows something different from step 4.** Retype that line. Do not `saveenv`
  until all four match.
- **It reboots into the same hang after `reset`.** Stop at the prompt again and run
  `printenv bootargs` to confirm the save took.

## What is not touched

The bootloader itself (eMMC `0x8400`), slot A, slot B, `misc`, `vbmeta` and `dtbo` are not
written. Only four environment variables change.

## Restoring the whole environment, if needed

The October backup's environment (`uboot_env.img`, md5 `1b1533ff…`) can be written back once
Android is up again:

```
adb push uboot_env.img /data/local/tmp/
adb shell su 0 dd if=/data/local/tmp/uboot_env.img of=/dev/block/mmcblk2 bs=4096 seek=1024 count=1 conv=fsync
```

This removes the leftover variables from the v10 experiment (`payargs`, `fdtaddr`,
`bootcmd_safe`, `bootcmd_orig`). It is optional; step 4 alone fixes the boot.

## The amp — research only

Everything below is read from the v5 firmware image (`latest.bin`, sha256 `37c81d0b…`) and
ThermaSol's HydroVive installation manual. Nothing has been tested on the unit.

**What the chip uses, from its interrupt table and pin setup:**

- **USART2 on PA2/PA3**, alternate function 7 (`0x8002f8a`: pins `0x0C`, mode 2, AF 7). That is
  the exact pair ST's ROM bootloader listens on for USART2 (AN2606 Rev 61, Table 101). It is the
  realistic way in without a debugger.
- **USART1** (PC4/PC5) is also active: a factory text console, not a ROM port. The Bluetooth
  module is on USART2, so PA2/PA3 run to it. **USB is unused** — no USB handlers in the vector
  table — so USB DFU is not an option.
- **I2C2 on PA8/PA9** (`0x8002d20`: pins `0x300`, open-drain, AF 4) to the DSP.
- CAN has no interrupt handler; the firmware polls it. The ROM bootloader has no CAN at all, which
  is why nothing on the panel can reach the chip now.

**How the unit comes down (installation manual):** it is held by 3.5-inch screws under screw covers,
sealed with silicone, and hangs on its brackets when lowered. It connects by two plugs, an M12
power/data cable to the PDM and an audio cable, so it can be unplugged without cutting anything.
Its electronics are inside a sealed module; whether the board is reachable without opening that
housing is unknown.

**The next step is a look, not a fix:** lower the unit, photograph the module and any access panel
or label, and stop. Only once the board can be seen does a recovery procedure get written.

### How ThermaSol's own amp update works, and why it stopped

The panel can update the amp over CAN; the mechanism is visible on both sides.

- **The amp side (v5 `0x159a–0x15f6`).** `BC 01` erases bank 2 page `0x7F` (the last 2 KB of
  bank 2, `0x0807F800–0x0807FFFF`), inverts option bit BFB2 (bit 20) and resets. The chip then
  boots the other flash bank.
- **v5 has no updater in it.** Nothing in v5 receives the update frames (`0x101`/`0x102`). So the
  receiving end has to be a separate image in the other bank: ThermaSol's CAN updater.
- **The panel side (`libthermacan`).** `hvlsr_start_bootloader` sends `A5 BC 7B 01` on 0x101 and
  0x131. `hvlsr_bootloader_load_firmware` then waits, without transmitting, for frame `0x100` from
  the updater announcing status 1. The panel never asks; the updater must speak first.

After `BC 01` was sent on 2026-11-17 the amp went silent: no `0x100`, no `0x143`, no ACKs. So the
bank it now boots is not running a CAN updater.

**The deciding check, free and harmless, once the panel is back:** do the HydroVive's lights respond
to the panel's light control? The same chip drives them.

- **Lights respond** → the chip is running application code with CAN. A panel-side recovery is
  plausible, and the next step is to read what it reports.
- **Lights dead** → the chip is in the ST ROM bootloader or a bank with no CAN. The ROM bootloader
  has no CAN, so no panel-side recovery exists; the board has to be reached directly.
