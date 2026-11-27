# ThermaTouch TT10V2 — Android 15

Field notes from converting a stock ThermaSol ThermaTouch TT10V2 shower panel from its
shipped Android 10 build to a working Android 15 build, without losing the shower.

This is a record of what actually happened, what was verified, and what is still broken.
It is written for the next person — including future me — who has to touch this panel.

**Status: operational but not finished.** The shower runs, the display is correct, touch
works, audio works, Google services work, and the panel is remotely recoverable, including
from a failed boot ([docs/16](docs/16-network-recovery-hook.md)). The ceiling amp (HydroVive) has
been unresponsive since a failed firmware update on 2026-11-16 ([docs/14](docs/14-hydrovive-recovery.md)). Nothing here is certified by ThermaSol.

**Working in this repo as an agent?** Read [AGENTS.md](AGENTS.md) first — it has the hard
rules and the map. Otherwise start with [docs/00-overview.md](docs/00-overview.md).

## Layout

```
AGENTS.md                 Agent guidance: hard rules, orientation, what not to try
docs/
  00-overview.md          What the device is, and the shape of the whole effort
  01-mechanisms.md        Why the panel behaves as it does: access, boot, CAN, failure modes
  02-access.md            How we get a shell on it (and how we got one the first time)
  03-hardware.md          SoC, display, touch, audio, CAN, Bluetooth, storage
  04-android15-port.md    The port itself: device tree, image build, flashing
  05-fixes.md             Each defect found, its root cause, and its fix
  06-procedures.md        Runbooks: flash, rollback, recover, verify
  08-lessons.md           What I would do differently
  09-install-from-stock.md  Stock panel -> Android 15, start to finish
  10-known-pitfalls.md    Flat "do not do this" list
  11-vendor-store-mirror.md  The vendor app store, served from our own host
  12-apps-and-control.md  Installed apps, the local control app, adb UI recipes
  13-instruments-lie.md   Every way a measurement returned a clean, wrong answer
  14-hydrovive-recovery.md  The ceiling amp: the bricked update and the evidence
  15-recovery-plan.md     The dark panel of 2026-11-17 and how it was recovered
  16-network-recovery-hook.md  U-Boot fetches a fix script from the LAN on every boot
build/                    How OUR Android 15 image is assembled, + its hashes
devicetree/               Our device-tree additions (ThermaSol port + BT UART2)
patches/                  Our HAL + vendor-APK patches
scripts/                  Small, self-contained tools used above
firmware/README.md        Vendor firmware provenance: URL, size, hash (no binaries)
```

## Safety

The panel is sealed into a finished bathroom wall. There is no reset button, no USB, and the
only documented connector is behind silicone. Every recovery path therefore depends on a
software path staying alive; the U-Boot network hook is the last one that does not need the wall open. Read [docs/06-procedures.md](docs/06-procedures.md) before
changing anything.

## License

Documentation, device tree and patches: CC BY 4.0. Scripts: MIT.

**The images are not stored in git** (4.4 GB). They are published as release assets for owners of this hardware; `product.img` contains Google's proprietary apps and `vendor.img` is NXP/Variscite content. No ThermaSol firmware is redistributed. Verify images with the `SHA256SUMS` attached to each release.
