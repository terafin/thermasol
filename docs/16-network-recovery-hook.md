# 16 — Network recovery hook in U-Boot

Every power-on, before Android starts, U-Boot tries to fetch one script from a TFTP server on the
LAN and runs it if it is there. If it is not there, or anything about the fetch fails, the panel
boots normally. That turns "the panel is dark" from a wall-open job into: put a fix script on the
server, power-cycle the panel.

Installed 2026-11-17, after the dark panel in [15-recovery-plan.md](15-recovery-plan.md). That failure
was a bad saved `bootargs`; the hook would have fixed it with no console.

## What is in the environment

```
bootcmd=run tt_nethook; run cmaargs; boota ${fastboot_dev}
tt_nethook=setenv autoload no; setenv netretry no; setenv ethrotate no; setenv ipaddr <panel-ip>; setenv serverip <server-ip>; setenv netmask 255.255.255.0; setenv tftptimeout 1000; setenv tftptimeoutcountmax 2; echo tt-nethook: trying ${serverip}:tt-recover.scr; if tftpboot ${loadaddr} tt-recover.scr; then echo tt-nethook: running script; source ${loadaddr}; fi; echo tt-nethook: done
```

Only the environment changed. The bootloader binary, the slots, `misc` and `vbmeta` are untouched.
The panel's U-Boot (`2019.04-41468-ge20d4ecd9f`, `imx8mm_var_dart_android_defconfig`) has
`CMD_TFTPBOOT`, `CMD_SOURCE`, `HUSH_PARSER` and `IMAGE_FORMAT_LEGACY`, which is all the hook needs.

Why each setting is there, from the panel's U-Boot source:

| Setting | Why |
|---|---|
| static `ipaddr`/`serverip` | skips DHCP; no dependency on the router |
| `netretry no` | `net_start_again()` gives up after the first failure instead of looping |
| `ethrotate no` | no cycling through other interfaces |
| `autoload no` | nothing is loaded except the named file |
| `tftptimeout 1000`, `tftptimeoutcountmax 2` | a silent server costs about 3 s, not 50 |
| `if tftpboot …; then source …; fi` | `source` only runs on a completed transfer; `boota` always follows |

## What it was tested against

Sandbox build of the exact U-Boot tree, against a TFTP server on an isolated veth (with checksum
offload off, as real Ethernet has it):

| Case | Result | Extra boot time |
|---|---|---|
| server up, no file | `TFTP error: file not found`, `Not retrying...`, normal boot | ~0.5 s |
| valid script | script runs, then normal boot | ~0.5 s |
| corrupt file | `Wrong image format for "source" command`, normal boot | ~0.5 s |
| truncated script | `Bad data crc`, normal boot | ~0.5 s |
| server IP dead | `ARP Retry count exceeded`, normal boot | ~20 s |
| link down | `ARP Retry count exceeded`, normal boot | ~20 s |

On the panel:

- A proof script that only set and saved `tt_hook_proof=ok` was fetched 11 s after power-on; the
  variable was in the saved environment afterwards, and Android booted (`_b`, green).
- With no file on the server, the server logged `file … not found`, and `sys.boot_completed=1`
  came 71 s after power-on.

## Using it

The server is any TFTP server reachable from the panel's address, serving the file
`tt-recover.scr`. **The served directory stays empty** except during a recovery.

1. Write the fix as U-Boot commands, e.g. `fix.txt`.
2. Wrap it: `mkimage -A arm64 -T script -C none -n fix -d fix.txt tt-recover.scr`
3. Put `tt-recover.scr` in the TFTP root and power-cycle the panel.
4. Confirm the server logged the transfer, then **remove the file**.

Restoring the known-good boot values is the usual fix:

```
echo tt-recover: restoring known-good boot settings
setenv bootargs 'init=/init consoleblank=0 androidboot.hardware=freescale androidboot.force_normal_boot=1 firmware_class.path=/vendor/firmware transparent_hugepage=never androidboot.primary_display=imx-drm'
setenv cmaargs 'echo cma: using device-tree default'
setenv bootdelay 1
saveenv
```

## Rules

- **Any change to `bootcmd` keeps `run tt_nethook;` first.** Dropping it removes the only remote way in.
- **Never leave a script on the server that ends in `reset` or `boot` loops** — it runs on every power-on.
- Do not use `env default -a`: it drops the hook *and* puts CMA back to 800M
  ([15-recovery-plan.md](15-recovery-plan.md#do-not-use-env-default--a)).

## What it does not cover

- A wiped or corrupted bootloader (eMMC `0x8400`). Nothing in this project writes it.
- An environment rewritten without the hook.
- No Ethernet link. The hook adds ~20 s and the panel boots as it would have.
