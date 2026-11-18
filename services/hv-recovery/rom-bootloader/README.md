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
  2. reads the user option bytes at `0x1FFF7800`,
  3. backs up the full 512 KB flash and prints both banks' vector words,
  4. only after you type `YES`, rewrites the full 48-byte option block with **BFB2 cleared and every other byte as read** (a Write Memory to the option area erases all of it first), then reads it back and checks nothing else changed.
  5. after `SUCCESS`, disconnect the ESP32 (at least GPIO17) **before** the final power-cycle. The MCU
     then boots v7, which powers the Bluetooth module on the same two lines.

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

PA3 near 0 V or about 0.6 V means the module is holding it down; use the MCU's pins 14/17 instead.
PA2 low as well means the MCU is not in the ROM at all (see "No answer at step 1"). The MCU's own
pins are the safer default. A factory
header on the board, if there is one, is more likely the USART1 console on PC4/PC5 (LQFP64 pins 22/23,
DS12288), which the ROM does not listen on. No answer from such a header says nothing about
the ROM.

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

`test/run-emulator-tests.sh latest.bin` runs the script against an AN3155 emulator of the bricked chip: the expected brick on a V13.4 and a V13.3 ROM, an older ROM refusing option-byte reads, BFB2 already clear, and RDP level 1. It checks the exit code, the final option block and the printed ROM build for each.
