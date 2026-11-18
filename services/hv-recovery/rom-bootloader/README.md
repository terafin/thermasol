# HydroVive MCU recovery through the ST ROM bootloader

For a unit whose MCU sits in the ST system bootloader after `BC 01` (see
[docs/14, root cause](../../../docs/14-hydrovive-recovery.md#why-the-unit-did-not-fall-back-to-v7-root-cause)).
Needs a wired connection to the MCU's USART2 on the unit's board; nothing on the CAN harness reaches it.

- `amp-uart.yaml` — ESPHome config for an ESP32 that bridges USART2 to TCP port 6639, 57600 8E1.
  Wiring: ESP32 GND to the board's GND, GPIO17 to PA3 (USART2_RX), GPIO16 to PA2 (USART2_TX).
- `recover.sh <esp32-ip>` — uses `an3155.py`, a small AN3155 client that talks to the ESP32 over TCP:
  1. identifies the chip (refuses anything but device ID 0x469, STM32G47x),
  2. reads the user option bytes at `0x1FFF7800`,
  3. backs up the full 512 KB flash and prints both banks' vector words,
  4. only after you type `YES`, writes the option word with **BFB2 cleared and nothing else changed**.

Step 4 refuses unless the read-back has the value/complement layout, RDP is level 0 (`0xAA`), and the
new value differs only in bit 20. On a unit in the state described in docs/14 it writes `0xFFEFF8AA`, the
ST factory default, after which the G47x boots bank 1 directly and the original firmware runs.

## If the script stops

- **No answer at step 1:** the MCU is running stale bank-2 code. Hold BOOT0 (PB8) at 3.3 V through about
  10 kΩ, power-cycle the shower supply, and run it again.
- **Option-byte read refused at step 2:** if the FLASH_OPTR register reads exactly `0xFFFFF8AA` (ST factory value with BFB2 set), the script offers to write the factory word `0xFFEFF8AA` after you type `FACTORY`, then verifies it. Otherwise: older G474 ROMs (before V13.5, `0xD5`) refuse reads above
  `0x1FFF73FF`. The script prints the FLASH_OPTR register instead and stops. Use STM32CubeProgrammer over
  a UART (it talks to the same ROM bootloader): its Option Bytes view shows BFB2 as a checkbox; untick it,
  Apply, change nothing else. Or from the command line, with a USB-serial adapter on PA2/PA3:

  ```
  STM32_Programmer_CLI -c port=/dev/ttyUSB0 br=57600 P=EVEN -ob BFB2=0 -ob displ
  ```

  `-ob BFB2=0` writes that one field; `-ob displ` prints the result (expect BFB2 0, RDP 0xAA). The ESP32
  bridge is TCP, so CubeProgrammer needs a real serial port for this path.

## Tests

`test/run-emulator-tests.sh latest.bin` runs the script against an AN3155 emulator of the bricked chip in four states (expected brick, older ROM refusing option-byte reads, BFB2 already clear, RDP level 1) and checks the exit code and final option word for each.
