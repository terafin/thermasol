# HydroVive MCU recovery through the ST ROM bootloader

For a unit whose MCU sits in the ST system bootloader after `BC 01` (see
[docs/14, root cause](../../../docs/14-hydrovive-recovery.md#why-the-unit-did-not-fall-back-to-v7-root-cause)).
Needs a wired connection to the MCU's USART2 on the unit's board; nothing on the CAN harness reaches it.

- `amp-uart.yaml` — ESPHome config for an ESP32 that bridges USART2 to TCP port 6639, 57600 8E1.
  Wiring: ESP32 GND to the board's GND, GPIO17 to PA3 (USART2_RX), GPIO16 to PA2 (USART2_TX).
- `recover.sh <esp32-ip>` — uses `socat` and `stm32flash`:
  1. identifies the chip (refuses anything but device ID 0x469, STM32G47x),
  2. reads the user option bytes at `0x1FFF7800`,
  3. backs up the full 512 KB flash and prints both banks' vector words,
  4. only after you type `YES`, writes the option word with **BFB2 cleared and nothing else changed**.

Step 4 refuses unless the read-back has the value/complement layout, RDP is level 0 (`0xAA`), and the
new value differs only in bit 20. On a unit in the state described in docs/14 it writes `0xFFEFF8AA`, the
ST factory default, after which the G47x boots bank 1 directly and the original firmware runs.
