# HydroVive MCU recovery through the ST ROM bootloader

For a unit whose MCU sits in the ST system bootloader after `BC 01` (see
[docs/14, root cause](../../../docs/14-hydrovive-recovery.md#why-the-unit-did-not-fall-back-to-v7-root-cause)).
Needs a wired connection to the MCU's USART2 on the unit's board; nothing on the CAN harness reaches it.

- `amp-uart.yaml` — ESPHome config for an ESP32 that bridges USART2 to TCP port 6639, 57600 8E1.
  Wiring: ESP32 GND to the board's GND, GPIO17 to PA3 (USART2_RX) **through a 1 kΩ resistor**, GPIO16
  to PA2 (USART2_TX) **through a second 1 kΩ**. Power the ESP32 before the shower supply: if the amp is
  up while the ESP32 is not, PA2 drives the ESP32's unpowered GPIO16, and the second resistor keeps that
  current to about 3 mA (PA2 is FT_a, PA3 TT_a per DS12288, so 3.3 V signals are within limits either way).
  Neither resistor hurts the signal (DS12288): against the ROM's PA3 pull-up (RPU 25-55 kΩ) a low from the
  ESP32 reads at most 0.13 V, under VIL 0.3 x VDD = 0.99 V; and 1 kΩ with about 35 pF of pin, wire and
  probe slows each edge by about 35 ns against a 17.4 µs bit at 57600 baud. The resistor matters: PA3 is also driven by the Bluetooth module's TX once the
  real firmware runs, and two outputs fighting on that line can damage the module's pin. 1 kΩ keeps
  that under 4 mA and does not affect 57600 baud. These are the same NodeMCU-32S pins (left row: GND
  6th, P17 11th, P16 12th) that bridged the panel's U6 console on 2026-11-17, so they are known free on
  that board; on an ESP32-WROVER module GPIO16/17 belong to the PSRAM and must not be used.
- `bridge-check.sh <esp32-ip>` — run first, before any wiring: confirms the ESP32 is on the network and the
  stream server answers, so a later "no answer" from `recover.sh` points at the wiring or the chip.
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
     is on USART1, PC4 (TX) / PC5 (RX), LQFP128 pins 37/38, 115200 8N1. At power-on it prints
     `HydroVive, firmware version 7.x`; `h` lists its commands (`lcs1` lights on, `s` sensor values).
     This is the running firmware, not the ROM; it only answers once the fix has taken.

     Before the fix, a 20 s capture on 2026-11-18 showed only the panel (`0x131`, 33 frames) and the
     generator (`0x120`, 10 frames), nothing from the unit. 20 s is too short to prove silence on its
     own; together with the ACK test in docs/14 it is.

Step 4 refuses unless the read-back has the value/complement layout, RDP is level 0 (`0xAA`), and the
new value differs only in bit 20. On a unit in the state described in docs/14 it writes `0xFFEFF8AA`, the
ST factory default, after which the G47x boots bank 1 directly and the original firmware runs.

## Where the pins are on the chip

The owner's board photo (2026-11-18, board AS03-7225 Rev A) shows the MCU is an **STM32G474QET6**:
LQFP128, 14 x 14 mm, **0.4 mm pitch**, 32 pins per side. (The firmware alone suggested LQFP64; it is
not.) The Bluetooth module is a **BM64SPKS1MC2**, the DSP an ADAU1701, the power amp a TPA3116. The
board has no conformal coating.

LQFP128 pin numbers (DS12288 Table 12). Pin 1 is at the dot; numbering runs counter-clockwise seen
from the top.

| Signal | Pin | Use here |
|---|---|---|
| PA2 (USART2_TX) | **29** | to the ESP32's RX (GPIO16), through 1 kΩ |
| VSS | 30 | between the two signals: do not probe here |
| VDD | 31 | 3.3 V: do not touch |
| PA3 (USART2_RX) | **32** | to the ESP32's TX (GPIO17), through 1 kΩ |
| PG10-NRST | 21 | reset, if needed |
| PB8-BOOT0 | 123 | only if step 1 gets no answer (below) |
| PB5 / PB6 (FDCAN2) | 120 / 121 | the CAN transceiver; leave alone |
| PA13 / PA14 (SWD) | 96 / 98 | debug port |
| PC4 / PC5 (USART1 console) | 37 / 38 | ThermaSol debug terminal, 115200 |

PA2 and PA3 sit on the same side, three pins apart, with VSS and VDD between them at 0.4 mm spacing:
probe with sharp tips or tack wires, and take ground from a large ground point, not pin 30.

**J10** is a 6-pin 2.54 mm right-angle header on the right edge of the board, pin 1 marked with a ▼,
next to U9 (an SOIC-8, probably the CAN transceiver). Checked with a meter on 2026-11-18: one J10 pin is
ground (it beeps to MCU pin 30 and to the BM64 can); no J10 pin reaches pins 29, 31 or 32. **J10 does
not carry USART2.** Its ground pin is still a convenient ground for the ESP32.

**J7** is a Tag-Connect-style footprint: two rows of seven pads with locating holes. MCU pin 96 (PA13,
SWDIO) reaches one J7 pad and ground another; pin 98 (PA14, SWCLK) reaches none of them. So J7 alone is
not enough for SWD, and the serial route below is the plan.

PA2/PA3 also run to the BM64's UART pads, the easiest small targets on this board (about 1 mm, castellated).
The module on this board is confirmed as a **BM64SPKS1MC2**. From Microchip's pad diagram (DS60001403F,
Figure 1-5), with the antenna end at the top: pads 1-17 run down the left side, **18-26 along the bottom
edge from left to right**, and 27-43 up the right side. **Pad 19 (HCI_RXD) is PA2; pad 20 (HCI_TXD) is
PA3**: the 2nd and 3rd pads from the left on the bottom edge. Ground is pad 14 or 43, or the metal can.
Confirm with a meter that pad 19 beeps to MCU pin 29 and pad 20 to pin 32 before relying on them, and do
the idle-voltage check below.

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
  legs; the 4-probe kit is Sensepeek PCBITE-7028, Mouser 90-PCBITE-7028). Two of them, one on pin 29 and one on pin 32. They are on the same side of
  the LQFP128, three pins apart at 0.4 mm pitch, with VSS (30) and VDD (31, 3.3 V) between them: a slip
  from either probe can short the supply. Take ground from any large ground point on the board, not
  pin 30. The run takes a few minutes, so nothing may move during it.
- **The Bluetooth module's edge pads** (BM64 19/20), about 1 mm wide, with the same probes
  or micro-grabbers.
- **Soldering** a thin wire (30 AWG wire-wrap) to each leg or pad, if the probes will not hold.

A full LQFP128 test clip that grips all 128 legs at once exists, but it needs room on all four sides
of the chip, and the board's parts layout is not known.

## The bridge during a run

The ESP32's stream server (pinned commit `d2c2ac3`) accepts any number of TCP clients, writes every
client's bytes to the UART and copies every UART byte to every client. It has no client limit or
address filter. Anything that connects to port 6639 during a run, such as a network scanner probing
with `GET / HTTP...`, puts its bytes straight into the ROM bootloader. The ROM checks every command
and data frame, so stray bytes cannot cause a wrong write, but they can break the step in progress.

Run recovery on a network where nothing scans the ESP32, ideally the ESP32's own access point or an
isolated VLAN, and keep other clients (Home Assistant, a browser tab on the ESP32) off port 6639.
A reply reaches the laptop within about 20-100 ms (ESPHome loop plus Wi-Fi), inside the client's
1 s sync and 3 s command timeouts.

## What each exit code means

| `recover.sh` | Meaning | Written? |
|---|---|---|
| 0 | BFB2 cleared and read back, or `WRITE SENT, NOT READ BACK` (the chip left the ROM, as clearing BFB2 does); also "stopped before any write" if you did not type YES | yes / no |
| 1 | the option block failed a check (RDP not level 0, or not value + complement) | no |
| 2 | not an STM32G47x (device ID is not 0x469) | no |
| 3 | BFB2 is already clear, so clearing it is not the fix | no |
| 4 | no answer from the ROM: wiring, or the chip is not in the ROM (see below) | no |
| 5 | this ROM refuses option-byte reads; use STM32CubeProgrammer (printed) | no |
| 6 | the write was sent but BFB2 still reads set | no |
| 8 | option bytes other than OPTR changed; compare `2-ob.bin` and `5-ob-after.bin` | yes |
| 9 | the bank-2 option block changed; bank 1 still boots, restore it from `2-ob2.bin` | yes |
| 10 | bank 1 cannot boot; run `restore-bank1.sh` first | no |
| 11 | FB_MODE=1, banks are swapped in the address map | no |
| 12 | ROM V13.5 or later, which should have booted the firmware; the diagnosis does not fit | no |

`restore-bank1.sh`: 0 written and verified (or stopped before writing), 2 bank 1 already boots,
3 bank 2 blank for `slot2`, 4 no answer or not a G47x, 5 source file rejected, 6 verify failed after
writing, 11 FB_MODE=1.

## If the script stops

- **No answer at step 1:** first power-cycle the shower supply with the ESP32 already connected and run
  it again. After reset the ROM listens on every interface at once and locks onto the first that
  shows activity (AN2606 Fig. 59: `0x7F` on any USART, its I2C address, SPI sync, USB); it then ignores
  the rest. A glitch on another of its pins (USART1 RX on PA10, I2C2 on PC4/PA8, SPI2 on PB12-15,
  which here runs to the LED driver) could have won the race. If PA2 reads 3.3 V and it still does
  not answer after a clean power-cycle, the MCU may be running stale bank-2 code: hold BOOT0 (PB8,
  LQFP128 pin 123) at 3.3 V through about 10 kΩ, power-cycle, and run it again.
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
