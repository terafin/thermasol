# Scripts

Small, self-contained tools. Each one is safe to read before running; none of them change
hardware state unless the filename says so.

| Script | What it does | Mutates hardware? |
|---|---|---|
| `panel-status.sh` | Read-only health snapshot of the panel | no |
| `panel-send-can.sh` | Send an explicit, whitelisted CAN frame | **yes** — controls lights/speaker |
| `can-capture.sh` | Passive capture of `can0` traffic | no |
| `pull-installed-apk.sh` | Pull + hash the APK actually installed for a package | no |
| `panel-reboot-verify.sh` | Reboot and verify the panel comes back healthy | yes (reboot) |

Set `PANEL` and `ADB` to override defaults:

```sh
export ADB=adb
export PANEL=<panel-ip>:5555
```
