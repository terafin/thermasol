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

Controller identity, read over I²C: `Family: 164 Variant: 3 Firmware V2.0.AA Objects: 41`,
`Touchscreen size X4095 Y4095`.

**The controller is fine. The CHG interrupt line is not.** `/proc/interrupts` shows
`24: 0 49486 236240 0 gpio-mxc 2 Edge maxtouch` — zero hardware IRQs while messages queue.

The working configuration is the **`tt_mxt_polled` driver module**: the IRQ stays requested but
disabled, and `mxt_interrupt()` runs from a 20 ms `delayed_work`. With
`poll_interval_ms=0` it is bit-for-bit stock behaviour.

**Do not add a userspace poll loop.** It duplicates the driver's accounting and fights it.
**Do not pull the CHG pin low to test it** — that caused a board reset.

Input events use `ABS_MT_POSITION_X/Y` in the range 0..4095, increasing downward for Y, plus
a separate `ABS_X/ABS_Y` axis stream.

**Synthesizing input.** `adb shell input tap` / `input swipe` / `input keyevent` work reliably
here. Use `input` first.

`sendevent` is the fallback for when `input` is unavailable (a broken `InputManager`) or when
you need a raw protocol-B stream. Sequence for a tap on `/dev/input/event1`:

```sh
# down
sendevent /dev/input/event1 3 57 <id>    # ABS_MT_TRACKING_ID
sendevent /dev/input/event1 3 53 <x>     # ABS_MT_POSITION_X
sendevent /dev/input/event1 3 54 <y>     # ABS_MT_POSITION_Y
sendevent /dev/input/event1 1 330 1      # BTN_TOUCH down
sendevent /dev/input/event1 3 0 1        # SYN_REPORT
sendevent /dev/input/event1 0 0 0
# up
sendevent /dev/input/event1 3 57 -1
sendevent /dev/input/event1 1 330 0
sendevent /dev/input/event1 3 0 0
sendevent /dev/input/event1 0 0 0
```

`ABS_MT_SLOT` is 47 when you need more than one contact. A single-axis
`sendevent /dev/input/event1 3 0 362` moves the separate `ABS_X` axis and is enough to wake the
panel, not to tap a widget.

**Reading the UI instead of guessing coordinates.** `uiautomator dump` gives you the bounds:

```sh
adb shell 'su 0 sh -c "uiautomator dump /data/local/tmp/tt-fw.xml >/dev/null; cat /data/local/tmp/tt-fw.xml"'
```

then parse `bounds="[x1,y1][x2,y2]"` and tap the centre. **The `>/dev/null` on the dump is
load-bearing** — the path chatter on stdout corrupts naive parsing.

## Audio

- Codec: **NXP WM8904** at I²C `2-001a`, on **SAI5** (`30050000.sai`), MCLK 1.536 MHz.
- DMA: i.MX SDMA, which **needs `imx/sdma/sdma-imx7d.bin` (3,202 B) present in the early
  ramdisk** or every PCM open fails with `-ENOMEM` while `tinyplay` still exits 0.
- The codec must be clocked from **SAI5**, not SAI3 — one DT cell, `0xb4` → `0xb8`.
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

### SELinux: the grant that is easy to miss

Android 15 grants `can_socket` only to `hal_can_socketcan`. The vendor service
`com.thermasol.thermatouchservice` runs as `system_app` and is therefore **denied** until a
vendor policy exists for it. The fix is a policy copied from `hal_can_socketcan.te` **minus
`net_admin`**, granting the ioctl xperms:

| xperm | ioctl |
|---|---|
| `0x8913` | `SIOCGIFFLAGS` |
| `0x8914` | `SIOCSIFFLAGS` |
| `0x8933` | `SIOCGIFINDEX` |

Only `vendor` and `vbmeta` change. A missing `0x8933` shows up as the service spinning on a
denied `read` at ~52 000 denials/second, burning a core and overwriting the kernel log.

### `can0` first-contact decision table

The service **raises `can0` itself**. A hand-run `ip link set can0 up` leaves state that
invalidates everything you measure afterwards. Read, don't touch:

| State | Meaning |
|---|---|
| `can0` UP | the path works |
| DOWN, service running | the socket was refused (policy or bind failure) |
| DOWN, and the service PID keeps changing | it is dying inside `read_can` |

`ERROR-ACTIVE` with all-zero RX/TX counters proves nothing on its own.

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

The DT compatible string is `brcm,bcm43430a1-bt` even though the part is a BCM4335C0 — it binds
the generic BCM driver with no quirks, and the kernel auto-selects the right firmware from the
chip's own version report.

Wi-Fi on the shipped board is not brought up by this port; the panel runs on Ethernet.

## Power

- **Not PoE.** The switch port has `poe_enable=False`. A network-side power cycle is
  impossible.
- The only remote power action is a breaker trip, i.e. a human.

### Memory

2 GiB, carrying roughly 1.5 GB of Google processes. Free non-CMA RAM sits at 40–140 MB while
`CmaFree` oscillates between 0.4 and 28 MB against a 320 MB pool.

**Judge memory pressure by `CmaFree` rising and `MemFree > ~200 MB`. Never judge by
`MemAvailable`** — it reads healthy while the panel is about to stall.

Why the usual knobs don't help here:

- **LMK is misprovisioned with EVK props** (`ro.lmk.upgrade_pressure=80`,
  `downgrade_pressure=95`, `sys.lmk.minfree_levels=18432:0,…`). mem_pressure around 98.7% sits
  above the 95 threshold, so **lmkd holds off while swap goes unused** — a transient deadlock.
- **Swappiness is irrelevant on 4.19**: `get_scan_count` returns `SCAN_FILE` whenever
  `inactive_file >> active_file`, so the knob does not drive reclaim. One session removed a
  swappiness-100 change on that basis and then reinstated it as an operator-approved exception;
  treat it as set, not as a fix.
- **~600 MB sits idle in CMA** while the movable list thrashes, because the allocator only falls
  back to CMA when it is empty.

The reversible lever is `panel-stabilize.sh`: it disables 8 Google packages and writes the
`pm enable --user 0` receipt **before** acting, refusing to run if that receipt cannot be
written. See issue [#16](https://github.com/terafin/thermasol/issues/16).

## Known hardware-adjacent traps

| Trap | Why |
|---|---|
| Deep suspend (`echo mem`) | **Never wakes.** No RTC/alarm wake source; the touch IRQ is registered as a wake source but does not bring the SoC out. Recovery is the breaker. |
| `Utils.ShutdownAll` | Stops steam and flushes water — not an idle action. |
| `PowerFlushActivity` / `FirmwareUpdateActivity` | Act on real hardware in `onCreate`. |
