# Vendor firmware — provenance only

**No vendor binaries are redistributed here.** They are ThermaSol's property, and "it is on a
public endpoint" is not a licence to republish it. What is recorded instead is the provenance:
the exact URL, byte size, SHA-256 and date — enough to identify an image and verify one you
download yourself, without shipping someone else's firmware.

## HydroVive ceiling speaker

| | |
|---|---|
| File | `hydrovive-latest.bin` (not included — download from the URL below) |
| Source | `http://thermatouch.tsolup.com/firmware/hydrovive/latest.bin` |
| Size | 47,676 bytes |
| SHA-256 | `37c81d0b020d0be55287a2ac836909cff0473f08a5ccc74a12eeb8c33083279f` |
| Dated | 2021-09-21 (server `Last-Modified`) |
| Format | raw ARM Cortex-M image; entry vector `0x080033CD`, reset `0x08002FF1` |

The panel reports the installed speaker as **7.0.0**. This is the only image the vendor
publishes — there is no versioned set, only `latest.bin` — and no newer one exists. Updating
the speaker is therefore **not** currently a route to fixing anything.

Note that the file has no embedded version string, so it is not possible to confirm from the
binary alone that it differs from what is installed.

## Other images referenced by the vendor

`firmware.json` on the same host lists DSV-4000 MCU firmware (v3, 2026-05-13) and a slave MCU
(v4). **Those do not apply to this installation**: the panel reports
`esv_get_is_dongle_present = false`. The image is downloadable at
`/firmware/lctesv/latest.bin` (53,448 bytes) but flashing it here would target hardware that
is not present.

## What this directory does not contain

- The Android system images (boot/dtbo/system/vendor/product/vbmeta) — large, and site-specific.
- The original Android 10 stock images — preserved off-device with recorded hashes.
