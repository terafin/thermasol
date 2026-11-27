# hvframe — send the HydroVive standby frame once

`hvframe` sends exactly one CAN frame on `can0` and exits:

```
0x131  A5 BB 7B 03 6D 00 61 00
```

That is the standby command the vendor ThermaSol app sends to the HydroVive ceiling unit, captured from
the app on 2026-11-06. The frame is compiled in, so this binary cannot be made to send a heat, water,
flush or firmware frame; change the source and rebuild to send anything else.

**When to use it:** only on the HydroVive amp, and only once the repaired board is back and answering on
CAN again ([issue #1](https://github.com/terafin/thermasol/issues/1),
[docs/14](../../../docs/14-hydrovive-recovery.md)). The repo's hard rules apply: never send guessed frames,
and never send `A5 BC 7B 01` / `BD 01` (see `AGENTS.md`).

**Build** (Android NDK r28, no AOSP tree needed):

```sh
./build.sh            # writes ./hvframe (aarch64, PIE)
```

Push it to the panel and run it as root: `adb push hvframe /data/local/tmp/ && adb shell su 0 /data/local/tmp/hvframe`.
It prints `sent 131#A5BB7B036D006100` on success.
