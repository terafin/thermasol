# HydroVive MCU recovery through the ST ROM bootloader

For a unit whose MCU sits in the ST system bootloader after `BC 01` (see
[docs/14, root cause](../../../docs/14-hydrovive-recovery.md#why-the-unit-did-not-fall-back-to-v7-root-cause)).
Needs a wired connection to the MCU's USART2 on the unit's board; nothing on the CAN harness reaches it.

- `amp-uart.yaml` — ESPHome config for an ESP32 that bridges USART2 to TCP port 6639, 57600 8E1.
  Wiring: ESP32 GND to the board's GND, GPIO17 to PA3 (USART2_RX) **through a 1 kΩ resistor**, GPIO16
  to PA2 (USART2_TX). The resistor matters: PA3 is also driven by the Bluetooth module's TX once the
  real firmware runs, and two outputs fighting on that line can damage the module's pin. 1 kΩ keeps
  that under 4 mA and does not affect 57600 baud.
- `recover.sh <esp32-ip>` — uses `an3155.py`, a small AN3155 client that talks to the ESP32 over TCP:
  1. identifies the chip (refuses anything but device ID 0x469, STM32G47x),
  2. reads the user option bytes at `0x1FFF7800`, and the bank-2 block at `0x1FFFF800` (PCROP2, WRP2A/B,
     SEC2) where the ROM allows it; that block is never written, only compared afterwards,
  3. backs up the full 512 KB flash and prints both banks' vector words, and stops (exit 10) unless
     bank 1 holds a bootable image: clearing BFB2 boots bank 1 directly, with no ROM check,
  4. only after you type `YES`, rewrites the full 48-byte option block with **BFB2 cleared and every other byte as read** (a Write Memory to the option area erases all of it first), then reads it back and checks nothing else changed.
  5. after the write it reconnects to read the option bytes back. On real silicon that usually fails:
     with BFB2 cleared, the reset that follows an option-byte write boots bank 1 directly and the ROM
     never answers again. The script then prints `WRITE SENT, NOT READ BACK` and exits 0; if BFB2 had
     stayed set, the ROM would come back and the read-back would report it. Either way, disconnect the
     ESP32 (at least GPIO17) **before** the final power-cycle: the MCU then boots v7, which powers the
     Bluetooth module on the same two lines.
  6. confirm from the panel. A running unit sends status on CAN ID `0x143` by itself, once a second:
     `A5 B0 8F 07 00 00 00 00` (the `07` is the firmware version, v7) followed by `A5 B8 8F 00 …`.
     Measured on this unit before the brick (2026-10-11/12 captures: 60 in 60 s, first one within
     1 s). Listening is receive-only, and one `cansniff` run (it stops after 43 frames, about 10 s) is
     enough:

     ```
     adb shell su 0 /data/local/tmp/cansniff | grep " 143 "
     ```

     Before the fix, 9 runs (387 frames, 90 s) on 2026-11-18 held only the panel (`0x131`) and the
     generator (`0x120`): about 90 status frames missing.
  7. optional bench check, with the board still open: the firmware's own "Thermasol debug Terminal"
     is on USART1, PC4 (TX) / PC5 (RX), LQFP64 pins 22/23, 115200 8N1. At power-on it prints
     `HydroVive, firmware version 7.x`; `h` lists its commands (`lcs1` lights on, `s` sensor values).
     This is the running firmware, not the ROM; it only answers once the fix has taken.

     Before the fix, a 20 s capture on 2026-11-18 showed only the panel (`0x131`, 33 frames) and the
     generator (`0x120`, 10 frames), nothing from the unit. 20 s is too short to prove silence on its
     own; together with the ACK test in docs/14 it is.

Step 4 refuses unless the read-back has the value/complement layout, RDP is level 0 (`0xAA`), and the
new value differs only in bit 20. On a unit in the state described in docs/14 it writes `0xFFEFF8AA`, the
ST factory default, after which the G47x boots bank 1 directly and the original firmware runs.

## Where the pins are on the chip

The firmware drives PC0, PC3 and PC5, which the 48-pin G474 packages do not have, so the MCU is at least
a 64-pin part; with 512 KB of flash it is most likely the STM32G474RE in LQFP64. Not confirmed on a real
board: read the chip's marking first. If it is not a 64-pin LQFP, use the datasheet's table for that package.

LQFP64 pin numbers (DS12288, Table 12). Pin 1 is at the dot; numbering runs counter-clockwise seen from the top.

| Signal | Pin | Use here |
|---|---|---|
| PA2 (USART2_TX) | 14 | to the ESP32's RX (GPIO16) |
| VSS | 15, 31, 47 | ground for the ESP32 |
| VDD | 16, 32, 48, 64 | 3.3 V; do not power the board from the ESP32 |
| PA3 (USART2_RX) | 17 | to the ESP32's TX (GPIO17) |
| PB8-BOOT0 | 61 | only if step 1 gets no answer (below) |
| PG10-NRST | 7 | reset, if needed |
| PB5 / PB6 (FDCAN2) | 58 / 59 | the CAN transceiver; leave alone |
| PA13 / PA14 (SWD) | 49 / 50 | SWDIO / SWCLK, if an ST-LINK is used instead |

PA2 and PA3 sit either side of the VSS/VDD pair at 15-16, so a probe slip there shorts the supply:
use fine probes or tack wires.

PA2/PA3 run to the Bluetooth module's UART, so its RX/TX pads are a second place to connect; the
module is unpowered while the MCU sits in the ROM. v5 sends it `AA 00 03 02 00 <action> <chk>` at
19200 baud: Microchip's MMI_Action command (actions 0x51-0x54, 0x5D), so it is a Microchip
BM62/BM64-class module (a 15 x 29 or 15 x 32 mm can with castellated edge pads). From the BM62/64
data sheet (DS60001403F, Tables 1-2/1-3), with the module's TXD going to the MCU's RX:

| Module | Its TXD (to PA3) | Its RXD (from PA2) | GND |
|---|---|---|---|
| BM62 | pin 32 | pin 33 | 23, 37 |
| BM64 | pin 20 | pin 19 | 14, 43 |

So the ESP32's TX (GPIO17) goes on the module's **TXD** pad (that line is PA3, the MCU's RX), and the
ESP32's RX (GPIO16) on the module's **RXD** pad (PA2). Read the marking on the can first; if it is not
a BM62/BM64, find that module's UART pins. A series resistor between module and MCU, if fitted, is
fine at 57600.

Check before using the module pads. The module runs from its own BAT_IN supply and only comes up
when the MCU presses its MFB power key, which never happens while the MCU sits in the ROM. Its
I/O rail is internal ("do not connect", VDD_IO), so with the module shut down its UART pins may
clamp the line to ground through their protection diodes, and the ROM would never see the `0x7F`
sync byte. The data sheet does not state the shut-down pin state. With the shower supply on and
the ESP32 **not** connected, measure each pad to GND. AN2606 (Rev 62, Table 101) says the G47x ROM
sets PA2 (USART2_TX) to alternate push-pull with pull-up, so it drives that line high at idle, and
PA3 (USART2_RX) to input with a weak pull-up (about 40 kΩ). Expect about 3.3 V on both:

- the module's **RXD** pad (PA2) at 3.3 V says the ROM is running and driving its TX;
- the module's **TXD** pad (PA3) at 3.3 V says nothing is clamping the ROM's RX line.

The MCU pin and the module pad are the same net, so the reading is the same at either end, and
moving the clip does not get around a clamp. PA3 near 0 V or about 0.6 V means something on that net
is holding it down. Look for a series resistor between the MCU and the module on that line: wiring
on the MCU side of it (pin 17) lets the ESP32 drive PA3 through the resistor's isolation. With no
such resistor, the ESP32 (through its own 1 kΩ) may still drive a 0.6 V clamp high enough; if
`recover.sh` gets no answer, lifting the module's TXD pad or that resistor frees the line. PA2 low as
well means the MCU is not in the ROM at all (see "No answer at step 1"). A factory
header on the board, if there is one, is more likely the USART1 console on PC4/PC5 (LQFP64 pins 22/23,
DS12288), which the ROM does not listen on. No answer from such a header says nothing about
the ROM.

## If bank 1 cannot boot (exit 10)

`recover.sh` refuses to clear BFB2 unless bank 1 holds a bootable image. If it stops there, run
`restore-bank1.sh <esp32-ip> [port] <source>` first, then `recover.sh` again:

- `slot2` copies bank 2's image into bank 1. Use this if bank 2 holds the working firmware (v7).
- `latest.bin` writes ThermaSol's v5 (`firmware/hydrovive/latest.bin`; checked against its sha256).
  Bank 1 boots directly with BFB2 clear, so v5's stack pointer is not a problem there.

It backs up both banks, refuses if bank 1 already boots, erases only the bank-1 pages the image needs,
writes, and reads it back. It never touches bank 2 or the option bytes.

## Connecting without a header

The board has no known header for USART2. Ways onto the pins without soldering, from easiest:

- **Spring-needle probes on a magnetic base** (Sensepeek PCBite SP10, 0.5 mm tip, made for fine-pitch
  legs; the 4-probe kit is Sensepeek PCBITE-7028, Mouser 90-PCBITE-7028). Two of them, one on pin 14 and one on pin 17. Those two are 1.5 mm apart, not neighbours, so
  each probe has room. Take ground from any large ground point on the board, not pin 15, so no probe
  sits next to another. The run takes a few minutes, so nothing may move during it.
- **The Bluetooth module's edge pads** (BM64 19/20, BM62 32/33), about 1 mm wide, with the same probes
  or micro-grabbers.
- **Soldering** a thin wire (30 AWG wire-wrap) to each leg or pad, if the probes will not hold.

A full QFP64 test clip that grips all 64 legs at once exists, but it needs room on all four sides of
the chip, and the board's parts layout is not known.

## If the script stops

- **No answer at step 1:** first power-cycle the shower supply with the ESP32 already connected and run
  it again. After reset the ROM listens on every interface at once and locks onto the first that
  shows activity (AN2606 Fig. 59: `0x7F` on any USART, its I2C address, SPI sync, USB); it then ignores
  the rest. A glitch on another of its pins (USART1 RX on PA10, I2C2 on PC4/PA8, SPI2 on PB12-15,
  which here runs to the LED driver) could have won the race. If PA2 reads 3.3 V and it still does
  not answer after a clean power-cycle, the MCU may be running stale bank-2 code: hold BOOT0 (PB8,
  LQFP64 pin 61) at 3.3 V through about 10 kΩ, power-cycle, and run it again.
- **Option-byte read refused at step 2:** the script does not write. A Write Memory to the option area erases all 48 option bytes (AN3155), and this ROM will not let them be read back first, so a partial write could change other option fields. older G474 ROMs (before V13.5, `0xD5`) refuse reads above
  `0x1FFF73FF`. The script prints the FLASH_OPTR register instead and stops. Use STM32CubeProgrammer over
  a UART (it talks to the same ROM bootloader): its Option Bytes view shows BFB2 as a checkbox; untick it,
  Apply, change nothing else. Or from the command line, with a USB-serial adapter on PA2/PA3:

  ```
  STM32_Programmer_CLI -c port=/dev/ttyUSB0 br=57600 P=EVEN -ob BFB2=0 -ob displ
  ```

  `-ob BFB2=0` writes that one field; `-ob displ` prints the result (expect BFB2 0, RDP 0xAA). The ESP32
  bridge is TCP, so CubeProgrammer needs a real serial port for this path.

## Tests

`test/run-restore-tests.sh latest.bin` covers `restore-bank1.sh`. `test/run-emulator-tests.sh latest.bin` runs the script against an AN3155 emulator of the bricked chip: the expected brick on a V13.4 and a V13.3 ROM, an older ROM refusing option-byte reads, BFB2 already clear, and RDP level 1. It checks the exit code, the final option block and the printed ROM build for each.
