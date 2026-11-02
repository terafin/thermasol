# ThermaTouch TT10V2 — Android 15

Field notes from converting a stock ThermaSol ThermaTouch TT10V2 shower panel from its
shipped Android 10 build to a working Android 15 build, without losing the shower.

This is a record of what actually happened, what was verified, and what is still broken.
It is written for the next person — including future me — who has to touch this panel.

**Status: operational but not finished.** The shower runs, the display is correct, touch
works, audio works, Google services work, and the panel is remotely recoverable. The
ceiling speaker hisses and has not been silenced. Nothing here is certified by ThermaSol.

**Working in this repo as an agent?** Read [AGENTS.md](AGENTS.md) first — it has the hard
rules and the map. Otherwise start with [docs/00-overview.md](docs/00-overview.md).

## Layout

```
AGENTS.md                 Agent guidance: hard rules, orientation, what not to try
docs/
  00-overview.md          What the device is, and the shape of the whole effort
  01-history.md           Chronological narrative: stock → rooted → Android 15
  02-access.md            How we get a shell on it (and how we got one the first time)
  03-hardware.md          SoC, display, touch, audio, CAN, Bluetooth, storage
  04-android15-port.md    The port itself: device tree, image build, flashing
  05-fixes.md             Each defect found, its root cause, and its fix
  06-procedures.md        Runbooks: flash, rollback, recover, verify
  07-open-issues.md       What is still wrong (be honest here)
  08-lessons.md           What I would do differently
  09-install-from-stock.md  Stock panel -> Android 15, start to finish
  10-known-pitfalls.md    Flat "do not do this" list
build/                    How OUR Android 15 image is assembled, + its hashes
devicetree/               Our device-tree additions (ThermaSol port + BT UART2)
patches/                  Our HAL + vendor-APK patches
scripts/                  Small, self-contained tools used above
firmware/README.md        Vendor firmware provenance: URL, size, hash (no binaries)
```

## Safety

The panel is sealed into a finished bathroom wall. There is no reset button, no USB, and the
only documented connector is behind silicone. Every recovery path therefore depends on a
software path staying alive. Read [docs/06-procedures.md](docs/06-procedures.md) before
changing anything.

## License

Documentation, device tree and patches: CC BY 4.0. Scripts: MIT.

**No binaries are redistributed here** — not ThermaSol's speaker firmware, not the Android
image. Our `product.img` contains 1.4 GB of Google's proprietary apps and `vendor.img` is
NXP/Variscite content; neither is ours to publish. Image hashes are recorded in
`build/README.md` so you can verify one you build yourself.
