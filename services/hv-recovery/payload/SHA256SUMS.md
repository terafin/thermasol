# Payload build record

`build.sh` output from this commit's sources, with these inputs:

| Input | sha256 |
|---|---|
| ThermaSol `latest.bin` (HydroVive v5) | `37c81d0b…3279f` |
| `MODDIR` / `MODLOAD` | the v1.2 boot image's first-stage modules; CAN modules reordered after `spi-imx` |

| Output | sha256 |
|---|---|
| `hvnet` | `07bfa9986db0eb6d0c0970775e3bdb4abe62fefe5fe5e1cb3037014bca2ab157` |
| `initrd.lz4` | `fda08cd2bac33f89c871c9a92e541be6da6089dd70bc45f5805218c9f68d9104` |

The kernel is the v1.2 boot image's `Image` (`3d89f0106b2cfbe0…`), unchanged.

## Where a local copy may live on the eMMC

Unpartitioned space after `vbmeta_b` (which ends at LBA 30330880) and inside the GPT's usable
range (last usable LBA 30535646; backup entries 30535647–30535678, backup header 30535679).
LBA 30335000–30400535 read back as all zeros on 2026-11-17. Nothing partitioned is touched.
