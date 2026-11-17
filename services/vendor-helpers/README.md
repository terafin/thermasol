# vendor-helpers — sources for the panel's own vendor tools

The v1.2 vendor image ships these tools besides `tt_idle_dim`. Each row gives the sha256 of the
file in `vendor_b` of release `v1.2-android15` (read from the running panel on 2026-11-17) and
the source here that produced it.

| Vendor file | sha256 | Source | Built with | Status |
|---|---|---|---|---|
| `/vendor/bin/tt_misc_writer` | `42b1040bd1e85aeece6be7397549a8909c2c4cef06e621bd271bda7bbe25d3aa` | `avbab/avbab.c` | Soong, `avbab/Android.bp` module `tt_misc_writer` | source present; rebuilding needs the Soong tree |
| `/vendor/bin/tt_idle_peripheral` | `9c9871ae8d1db25b520bdfde9ada6eed90a5c6674a9dd3dbc19a7ce50c31e864` | `idle-peripheral/idle_can.c`, `idle_frames.h` | NDK clang, PIE, with `../tt-idle-dim/crt0.S` and `crt_glue.c` | rebuilds byte for byte |
| `/vendor/lib/modules/tt_reboot_pin.ko` | `b0114f007bad00b392aba788f7cd19bb5a671c5fb46a0b28c0bd360908e12a0e` | `reboot-pin/tt_reboot_pin.c` | out-of-tree module against the deployed kernel (`6.6.58-4k-ga9e7dfe9bde2`) | source present; rebuilding needs that kernel's build tree |
| `/vendor/bin/tt_touch_bind.sh` | `dc890231aae03836cf3c4b6e4715846f495b7bc4b7c43ebec0effdfe112edd3e` | `touch-bind/tt_touch_bind.sh` | the file itself | identical by definition |

The four sha256 values match the running panel and
[`verification/v1.2-vendor-helpers.md`](../../verification/v1.2-vendor-helpers.md), which gives
the exact commands that rebuild `tt_idle_peripheral` and, for the other two, what the rebuild
needs.

The init services that start each tool are in the vendor image's
`etc/init/hw/init.freescale.rc`.

## What each one does

- **`tt_misc_writer` / `avbab`** — reads and writes the libavb AvbABData record at
  `misc+0x800`. `tt_misc_writer guard <slot> 300` is the 300-second self-revert after a deploy.
- **`tt_idle_peripheral OFF|RESUME`** — sends the idle frames on 0x131: `OFF` mutes (B5 01),
  turns the light off (B4) and sends `5F FF`; `RESUME` sends only the unmute (B5 00). It sends
  nothing else (`idle_frames.h`).
- **`tt_reboot_pin.ko`** — restores GPIO1_IO02 to WDOG1_WDOG_B on the normal reboot path only;
  changes no pad at load.
- **`tt_touch_bind.sh`** — once per boot, binds the `2-004b` maXTouch client to the polled
  driver `tt_mxt_polled`.
