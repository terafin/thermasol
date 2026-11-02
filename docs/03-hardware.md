# 03 — Hardware

Everything here was read off the running panel or its device tree. Nothing is from a
datasheet unless stated.

## SoC and board

| | |
|---|---|
| SoC | NXP i.MX 8M Mini — 4× Cortex-A53, no GPU block beyond GC320/GCNanoLite-VG |
| Module | Variscite **DART-MX8M-MINI** |
| Carrier | Variscite DT8MCustomBoard 2.x |
| RAM | 2 GiB — **this is the defining constraint of the whole project** |
| Storage | eMMC (`mmcblk2`), A/B slots |
| Kernel | 4.19 NXP; i.MX `imx8mm` platform |

**2 GiB is tight.** Android 15 plus Google Mobile Services idles around 600 MB of Google
services alone. This shows up as: slow app launches, LMK pressure, and apps that silently
fail to start. See [05-fixes.md](05-fixes.md) for the memory findings.

## Display

1024×600 LVDS, density 120 dpi, landscape.

MIPI-DSI from the SoC is converted to LVDS by a **TI SN65DSI83** bridge on I²C. The bridge's
enable line is `GPIO1_IO11` (gpio-43 in sysfs, named `enable`).

Timings were captured verbatim from the running panel — **do not guess these**:

```
clock 51.2 MHz
hactive 1024  hfront 24   hsync 136  hback 160
vactive 600   vfront 3    vsync 6    vback 29
hsync-active 0  vsync-active 0  de-active 1  pixelclk-active 0
```

Backlight is `pwm-backlight`, exposed at `/sys/class/backlight/backlight`. Practical range on
this panel: 0 (off) to 100, default 71.

There is a real-time clock chip, `isil,isl12057/8`, on I²C — but see
[07-open-issues.md](07-open-issues.md): there is **no RTC wakealarm** on this kernel.

## Touch

**Atmel maXTouch** on I²C2 @ address `0x4b`, registered as `/dev/input/event1`.

This one caused enormous trouble. Short version:

- The stock Android 10 driver polls. The A15 kernel's driver is interrupt-driven.
- The interrupt never fires reliably on this board.
- The working configuration is **driver-owned polling** (`vendor.tt.touch_driver=tt_mxt_polled`),
  not userspace polling.

Do not "fix" this by adding a userspace poll loop; it duplicates and fights the driver.

Input events use `ABS_MT_POSITION_X/Y` in the range 0..4095, increasing downward for Y, plus
a separate `ABS_X/ABS_Y` axis stream. **`input tap` / `input swipe` are unreliable on this
device**; use `sendevent` against `/dev/input/event1` when you need to synthesize input.

## Audio

- Codec: **NXP WM8904** at I²C `2-001a`, on **SAI5** (`30050000.sai`), MCLK 1.536 MHz.
- Headphone and line outputs are both wired up; the ceiling speaker is fed from the analog
  line/headphone path and has its own amplifier.
- The codec's `init_ctl` lives in `/vendor/etc/configs/audio/wm8904_config.json`. The accepted
  gain (`Headphone Volume` 63/63) is baked in there.

**Debugging trap:** `dapm/bias_level` reads `Off` and regmap `06: 0000` / `0c: 0000` **while
audio is playing normally.** They are not a power indicator on this board. See
[08-lessons.md](08-lessons.md).

## CAN — the shower

`can0` via **mcp251xfd**, **100 kbit/s**. This is how the panel talks to everything else.

**The framing that matters:** the panel is `0x131`, controllers answer on `0x120` and
`0x143`. A frame on 0x131 looks like `A5 <opcode> 7B <payload…>`.

Known-good commands (verified on the bus, `0x131`):

| Purpose | Frame |
|---|---|
| Ceiling light | `A5 B2 7B …` |
| Speaker mute / unmute | `A5 B5 7B 01` / `A5 B5 7B 00` |
| Speaker volume | `A5 B6 7B <level>` (vendor normal = `8A` = 138) |
| Speaker source | `A5 B7 7B 00` |
| Speaker BT power on/off | `A5 BB 7B 01` / `A5 BB 7B 00` |
| Speaker BT disconnect | `A5 BB 7B 03` |
| Steam generator off | `A5 0F 7B` |
| Standby | `A5 5F 7B FF` |

**`A5 5F 7B FF` is the legacy SLSR standby, and the legacy SLSR device is not present on this
unit** (`slsr_is_active = 0`). Every `slsr_*` command is a no-op here. The live device is the
HVLSR (`hvlsr_is_active = 1`, firmware 7). This single fact explains hours of confusion.

Subsystems behind CAN:

| Prefix | Device |
|---|---|
| `psb_*` | Steam generator (pressure/steam board) |
| `esv_*` | Water/valve board (“ESV”/DSV-4000) — **not present on this installation** |
| `slsr_*` | Legacy speaker/light — **not present** |
| `hvlsr_*` | HydroVive ceiling speaker/light — **the live one** |

## Bluetooth

Broadcom **BCM4335C0** on **UART2** (`30890000.serial`) via serdev, `hci_uart_bcm`, firmware
`brcm/BCM4335C0.hcd` build 0809. Bring-up baud is **115200**, which is enough to connect but
**not** enough for audio streaming.

**Wi-Fi is physically broken** — damaged by soldering instructions from a previous agent.
There is no Wi-Fi fallback and no further soldering is sanctioned. Treat this panel as
Ethernet-only.

## Power

- **Not PoE.** The switch port has `poe_enable=False`. A network-side power cycle is
  impossible.
- The only remote power action is a breaker trip, i.e. a human.

## Known hardware-adjacent traps

| Trap | Why |
|---|---|
| Deep suspend (`echo mem`) | **Never wakes.** No RTC/alarm wake source; the touch IRQ is registered as a wake source but does not bring the SoC out. Recovery is the breaker. |
| `Utils.ShutdownAll` | Stops steam and flushes water — not an idle action. |
| `PowerFlushActivity` / `FirmwareUpdateActivity` | Act on real hardware in `onCreate`. |
| Wi-Fi | Broken. Do not "just enable it". |
