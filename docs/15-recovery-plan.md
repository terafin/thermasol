# 15 — Recovery plan: the dark panel and the silent amp

One trip, two units, no improvising. Read the whole page before opening anything. Every step
names what it checks and what to do when it fails. Nothing on this page has been executed yet;
everything it relies on is cited to code or to a captured artifact.

## The two failures, in one line each

| Unit | What broke it | Evidence |
|---|---|---|
| Panel (ThermaTouch, in the wall) | U-Boot env **v10**, written 2026-11-17 09:56:08Z, saved a bare `bootargs` with no Android tokens | `env-v10-bare-0x400000.bin` md5 `a2447cd8…`; `common/image-android.c:82-90` at `varigit/uboot-imx@e20d4ecd9f`; UniFi last-seen 10:05:14Z |
| Amp (HydroVive, in the ceiling) | `A5 BC 7B 01` on 0x101 and 0x131, 2026-11-17 00:43:34Z: erase bank-2 page 0x7F and toggle option bit BFB2 | bus capture `flash-v5-bus.txt` (2 frames); amp's `0x143` last seen 00:43:22Z; never since |

They are separate faults. Either can be fixed without the other.

## Order of work

1. **Amp first, from inside the shower.** It needs no wall opening: the HydroVive is a 37 lb
   ceiling module held by screws from below and sealed with silicone. Its board is behind that
   module, not behind the wall.
2. **Panel second, through the wall,** only if the UART wires from the 2026-10-13 recovery are
   no longer reachable.

Do not combine the two into one power-on session; each has its own checks.

## Part A — Panel

### A0. What the panel does on every power-on now

U-Boot loads the saved environment (one copy at eMMC byte `0x400000`; no redundant copy, no
bootcount). Two cases are possible and the console tells you which:

- **v10's self-disarm stored.** `bootcmd = run bootcmd_orig` → `boota mmc1` with the stripped
  `bootargs` → the kernel boots but Android's first stage has no fstab (`androidboot.hardware`
  is missing) → hangs silently. The link comes up during U-Boot, then nothing.
- **v10's self-disarm did not store.** `bootcmd` is still the v10 chain → it reruns the 812-byte
  payload every boot → hangs.

The fix below covers both, so you do not have to know which.

### A1. Before opening the wall (nothing touches the panel)

- [ ] USB-to-3.3 V TTL serial adapter (FTDI/CP2102/CH340) that is **3.3 V**, not 5 V. The SoC's
      UART is 1.8/3.3 V tolerant only at 3.3 V; a 5 V adapter can damage it.
- [ ] Plug it into **tellah**, confirm `/dev/ttyUSB0` appears, and that `picocom` or `screen` is
      installed: `picocom -b 115200 /dev/ttyUSB0`.
- [ ] Have this page and `env-orig-0x400000.bin` (md5 `1b1533ff43325d1a0c437826dd9aad88`) on
      tellah. It is in `~/.local/state/issue-shower-amp/` and in the handoff bundle.
- [ ] Turn the shower supply **off** with `switch.bathroom_bathroom_steam_shower_power` before
      touching wiring. Check `light.master_bathroom_shower_lights` is off first.

### A2. Wiring

Console: SoC UART4 = `ttymxc3`, `0x30a60000`, **115200 8N1**, three wires.

| Adapter | Panel |
|---|---|
| GND | GND |
| RX  | panel TX |
| TX  | panel RX |

Do **not** connect the adapter's VCC. If the wires from 2026-10-13 are still attached at the
U6/SoM header, use them; the earlier recovery used this exact path.

### A3. Catching the U-Boot prompt

`bootdelay` is `0` in the saved environment, so there is no countdown to see. With the
terminal open and the supply off:

1. Hold the **Enter** key down (or send Ctrl-C repeatedly) in the terminal.
2. Turn the supply on.
3. Keep sending until you see a `=>` prompt.

This worked on 2026-10-13 against this board. If after three attempts there is no prompt,
stop and go to A6.

### A4. The fix (at the `=>` prompt)

Type exactly this — it restores the three values the panel ran on for months, all taken from
the saved original environment `env-orig-0x400000.bin`:

```
setenv bootcmd 'run cmaargs; boota ${fastboot_dev}'
setenv cmaargs 'echo cma: using device-tree default'
setenv bootargs 'init=/init consoleblank=0 androidboot.hardware=freescale androidboot.force_normal_boot=1 firmware_class.path=/vendor/firmware transparent_hugepage=never androidboot.primary_display=imx-drm'
setenv bootdelay 1
printenv bootcmd cmaargs bootargs bootdelay
```

Read the four lines `printenv` prints and compare them character for character with the
commands above. Only then:

```
saveenv
reset
```

Why each line matters:

- `bootcmd`: if v10's disarm never stored, this is what stops the payload rerunning.
- `cmaargs`: the compiled default (`include/configs/imx8mm_var_dart_android.h`) sets
  `cma=800M` on 2 GB boards — the cause of the 30-second touch lag fixed in October. Keep it
  overridden.
- `bootargs`: the only line that actually fixes the boot. It must contain
  `androidboot.hardware=freescale`.
- `bootdelay 1`: gives a one-second window next time, so a console session is easy.

**Do not use `env default -a`.** It restores `cma=800M` and brings the touch lag back.

### A5. Confirming it worked

- The console shows the Android kernel log, then the login prompt or `init` messages.
- Within about 60 s, `ping 10.0.1.32` answers from tellah and `adb connect 10.0.1.32:5555` works.
- `adb shell getprop ro.boot.slot_suffix` → `_b`; `getprop sys.boot_completed` → `1`.

Leave the serial adapter connected until all three pass. Then close the wall.

### A6. If there is no U-Boot prompt

That rules out the saved environment as the cause: the fault is before U-Boot's main loop
(SPL, ATF, or power). Record everything the console prints from power-on and stop. Do not write
anything; bring the capture back for analysis. Do not write `flash.bin` (bootloader at `0x8400`).

### A7. Fallback: write the original environment back from the prompt

Only if A4 fails to boot and the prompt is available. Needs the network to come up in U-Boot.

```
setenv ipaddr 10.0.1.32
setenv serverip <tellah IP>
tftpboot 0x41000000 env-orig-0x400000.bin
mmc dev 1
mmc write 0x41000000 0x2000 8
reset
```

Serve the file from tellah with a TFTP server first. Unverified on this board.

## Part B — Amp

### B0. What is known

- MCU: **STM32G4** (FDCAN at `0x4000A400`, 127-entry vector table, GPIO at `0x48000000`).
  It is not an L4; earlier notes saying so are wrong. Exact part (G474 vs G473) is not yet read
  from the chip.
- Firmware **v7** before the incident; only **v5** is published (`latest.bin`, sha256
  `37c81d0b…`). v5 is a single image linked at `0x08000000`.
- What `BC 01` did: erased bank-2 page `0x7F` (`0x0807F800–0x0807FFFF`) and inverted BFB2.
  No application pages were written; bank-1 word 0 was not touched.
- Since then the unit neither sends nor ACKs on CAN at any rate (decisive ACK test, docs/14).

### B1. Why it is silent (and why that is recoverable)

ST's ROM reads BFB2 at reset (AN2606 Rev 61, Figure 59). With BFB2=1 it boots bank 2 if bank-2
word 0 is a valid SRAM address, otherwise bank 1 if bank-1 word 0 is valid, otherwise the ROM
bootloader. Bootloader **V13.3** has a known limitation: *"Boot from bank2 is not working"*
(Table 102). So the unit is running either (a) whatever was in bank 2, or (b) the ROM
bootloader. Neither talks CAN. Neither erased the firmware. The fix is to put BFB2 back and/or
reflash — and the ROM bootloader can always be forced from a pin.

### B2. The routes into the chip, best first

| Route | Needs | What it can do |
|---|---|---|
| **SWD** (SWDIO PA13, SWCLK PA14, NRST, GND, 3.3 V) | an ST-LINK V2/V3 and a pad or header on the board | everything: read option bytes, clear BFB2, read/back up both banks (v7!), reflash |
| **BOOT0 high at reset + USART2 (PA2/PA3)** | a 3.3 V USB-serial adapter and access to BOOT0 | ROM bootloader: read/clear option bytes, read and write flash |
| **BOOT0 high + USB DFU (PA11/PA12)** | only if the board routes USB to the MCU | same as USART2 |
| CAN | — | **not possible**: the G47x ROM bootloader has no FDCAN (AN2606 Table 101) |

PA2/PA3 is also v5's debug UART at 19200, so if the board has a debug header for it, that header
is a ROM-bootloader port when BOOT0 is high. The bootloader runs 8E1 and auto-detects the baud
after a `0x7F` sync byte.

### B3. Before opening the ceiling

- [ ] **ST-LINK V2 or V3** (V3MINIE is small) plus fine probe hooks or pogo pins.
- [ ] **3.3 V USB-serial adapter** (same as A1 works).
- [ ] A **jumper wire with a 10 kΩ resistor** to pull BOOT0 to 3.3 V.
- [ ] **STM32CubeProgrammer** installed on a laptop, or `stm32flash` on tellah for the UART route.
- [ ] Good light, a phone camera, and a magnifier.
- [ ] Supply **off** via the HA switch before removing the module.
- [ ] Replacement screws in the same size, since the panel's are stripping; check the
      HydroVive's 3.5" mounting screws before loosening them.

### B4. Opening (photos at every step)

1. Supply off. Wait a minute.
2. Lower the HydroVive gently; it is 37 lb and hangs on internal hooks. Don't strain the cables.
3. Photograph the board front and back **before touching anything**: every connector, every
   unpopulated header, every test pad, the MCU's top marking. Send them over before doing
   anything else. The plan's next step depends on what is actually on the board.

### B5. Identify the access point (from the photos)

Look for, in order:

- a **5-, 6- or 10-pin header** or row of pads near the MCU (SWD: GND, 3V3, SWDIO, SWCLK, NRST)
- a **3- or 4-pin header** labelled TX/RX/GND (the USART2 debug port)
- a pad, jumper or resistor on **BOOT0** (on LQFP-64 G4 parts, pin 60; on LQFP-48, pin 44 —
  confirm against the MCU marking before touching it)
- the MCU top marking, which decides the pinout.

No step after this is performed until the photos are reviewed and the pin map is confirmed.

### B6. Recovery with SWD (preferred)

1. Connect ST-LINK: GND, SWDIO, SWCLK, NRST. **Not** 3.3 V if the board is powered.
2. Power on. CubeProgrammer → ST-LINK → mode **Under reset**, reset mode **Hardware reset**.
3. Connect. Read the option bytes. Record **BFB2**, **nBOOT0**, **nSWBOOT0**, **RDP**, **DBANK**.
4. **Read both banks to files first** (`0x08000000`, 512 KB). That is the only copy of v7 that
   exists anywhere. Do not proceed until both files are saved and their sha256 is recorded.
5. Find v7 in the two dumps. `BC 01` **inverted** BFB2, so the bank that ran v7 is the one the chip
   is no longer booting. Check each bank for a valid vector table (word 0 in `0x2000xxxx`, word 1
   an odd address inside that bank) and compare against v5's layout. The bank that held v7 is the
   one whose image differs from v5 and has a valid table.
6. Set **BFB2 to the value that selects that bank** — i.e. invert the BFB2 you read in step 3 —
   and apply. The chip resets into v7.
7. Disconnect, power-cycle, and check the panel (once it is back) hears `143 A5 B0 8F 07`.

Nothing erased either image's code: `BC 01` only erased bank-2 page `0x7F` (the last 2 KB of
bank 2, far past the end of a ~48 KB image). So flipping BFB2 back should restore v7 with no
reflash. If the bank holding v7 is bank 2 and the chip reports bootloader V13.3, bank-2 boot does
not work on that ROM (AN2606 Table 102); then copy the v7 image into bank 1 and boot bank 1.

Note: the BOOT0 pin is honoured only while option bit **nSWBOOT0 = 1** (the factory default).
Read it in step 3; if ThermaSol cleared it, B7 cannot work and SWD is the only route.

### B7. Recovery with BOOT0 + USART2 (if there is no SWD)

1. Supply off. Pull BOOT0 to 3.3 V through 10 kΩ.
2. Connect the adapter to PA2 (TX) / PA3 (RX) / GND.
3. Supply on. `stm32flash /dev/ttyUSB0` should identify the device (it sends `0x7F` itself).
4. Read both banks to files first, as B6 step 4.
5. Clear BFB2 with `stm32flash` or CubeProgrammer's UART mode.
6. Supply off, remove the BOOT0 pull, supply on, and confirm `0x143` as B6 step 6.

### B8. If bank 1 is empty or damaged

Only then flash v5 (`latest.bin`, sha256 `37c81d0b…`) to `0x08000000`. That is a downgrade from
v7 and may change behaviour; the v7 backup from B6/B7 step 4 lets it be restored later.

### B9. Do not

- Do not send any CAN bank, option-byte or bootloader command to any ThermaSol peripheral again.
- Do not run "mass erase" or set RDP; RDP level 2 is permanent.
- Do not power the board from the ST-LINK while the shower supply is also on.

## Rules for this trip

- One person types; a second reads each command back before Enter.
- Photographs before every connection.
- Nothing is written to either chip before its backup is taken and checksummed.
- Every result goes into this page the same day.
