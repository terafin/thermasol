# Panel U-Boot environment — record of the pre-payload original

**The 4 KB image is not stored here.** It carries the unit's `ethaddr` and `serial#`, and this
repository is public. What is recorded is what identifies the image and what regenerates it.

| | |
|---|---|
| File | `env-orig-0x400000.bin` (not included) |
| Size | 4096 bytes |
| MD5 | `1b1533ff43325d1a0c437826dd9aad88` |
| Header | CRC32 stored little-endian at bytes 0–3; value `0x7992bb94` = crc32 of bytes 4–4095 |
| Taken | 2026-11-17T00:09Z, before any payload or arming |
| Flash location | LBA `0x2000`, 8 sectors of 512 (byte offset `0x400000`) |

Working copies exist under `~/.local/state/issue-shower-amp/` on tellah, in three places
(`env-orig-0x400000.bin`, `scratch/env-orig-0x400000.bin`, `scratch/env-orig.bin`). That is a
session state directory: nothing prevents it being swept, and if it is, the recovery route that
needs it has nothing to send. Copy it somewhere durable before relying on it.

## Regeneration

The image is a little-endian CRC32 header followed by NUL-separated `key=value` pairs. The
original's assignments, with the two device identifiers redacted:

```
baudrate=115200
board_name=VAR-SOM-MX8M-MINI
bootargs=init=/init consoleblank=0 androidboot.hardware=freescale androidboot.force_normal_boot=1 firmware_class.path=/vendor/firmware transparent_hugepage=never androidboot.primary_display=imx-drm
bootcmd=run cmaargs; boota ${fastboot_dev}
bootdelay=1
carrier_rev=legacy
cmaargs=echo cma: using device-tree default
console=ttymxc3,115200 earlycon=ec_imx6q,0x30a60000,115200
ethaddr=<redacted — the unit's own, on the SoM label>
ethprime=FEC
fastboot_dev=mmc1
fdt_high=0xffffffffffffffff
fdtcontroladdr=b9f1f9b0
initrd_high=0xffffffffffffffff
loadaddr=0x40480000
sdram_size=2048
serial#=<redacted — the unit's own, on the SoM label>
soc_type=imx8mm
som_rev=som_rev11
splashpos=m,m
stderr=serial
stdin=serial
stdout=serial
```

`fdtcontroladdr` is a runtime address from the boot that produced this dump, not a setting; a
regenerated image carrying it is harmless, because U-Boot overwrites it at boot.

A regenerated image is **not** byte-identical to the original and must not be described as the
original: the two redacted values differ per unit. It restores the same behaviour, which is what
the recovery needs.

## Note on why the token matters

`bootargs` here carries `androidboot.hardware=freescale`. The panel's device tree supplies
`fstab_suffix=nxp` and neither deployed ramdisk carries `fstab.nxp`, so that token is the only
thing that resolves the first-stage fstab — see `docs/14-hydrovive-recovery.md`.
