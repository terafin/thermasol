# HydroVive (ceiling amplifier): CAN protocol

Everything here was read out of the library the panel actually runs —
`com.thermasol.thermatouchservice` 10.1.4, `lib/armeabi-v7a/libthermacan-android.so`,
221,340 bytes, sha256 `1b5312b06616f1d09e32bc02a3da055449ad82fa078508ffde83d985e0b75d57` — and
checked against captures from the live bus. Function names are the library's own exported
symbols; the addresses are for that build.

The unit is the HydroVive light/sound ceiling module. Its current state is
[`docs/14-hydrovive-recovery.md`](../14-hydrovive-recovery.md); this page describes the protocol,
not the recovery.

## Frame format

Every frame is a standard 11-bit CAN frame. Ids in use:

| id | direction | meaning |
|---|---|---|
| `0x131` | panel → unit | every command |
| `0x131` | panel → unit | heartbeat, every request cycle |
| `0x100` | unit → panel | bootloader status |
| `0x143` | unit → panel | application status |
| `0x101`, `0x102` | panel → unit | bootloader only (below) |

A command on `0x131` is eight bytes:

```
A5 <op> 7B <p0> <p1> <p2> <p3> <p4>
```

`A5` is a start byte, `7B` is a separator, `<op>` selects the function and the rest is payload.
The bootloader's frames on `0x101` are the same three-byte header with a one-byte body; its page
frames on `0x102` use a different layout (below).

## Commands the panel sends (0x131)

Read from each exported function; `[pc]` constants and `strb` offsets in the listing give the
byte positions exactly.

| function | op | payload | notes |
|---|---|---|---|
| `hvlsr_send_heartbeat` | `B1` | none | `A5 B1 7B 00 00 00 00 00` |
| `hvlsr_mute` | `B5` | `p0 = 01` | `A5 B5 7B 01 00 00 00 00` |
| `hvlsr_unmute` | `B5` | `p0 = 00` | |
| `hvlsr_light_on` | `B4` | `p0 = 01` | |
| `hvlsr_light_off` | `B4` | `p0 = 00` | |
| `hvlsr_master_volume` | `B6` | `p0 = level \| 0x80` | bit 7 marks the field as present |
| `hvlsr_bass_volume` | `B6` | `p1 = level \| 0x80`, `p0 = 00` | |
| `hvlsr_mid_volume` | `B6` | `p2 = level \| 0x80` | |
| `hvlsr_treble_volume` | `B6` | `p3 = level \| 0x80` | |
| `hvlsr_set_source` | `B7` | `p0 = source` | |
| `hvlsr_set_rbga` | `B2` | `p0..p3 = colour, big-endian`, `p4 = 00` | 32-bit RGBA |
| `hvlsr_set_white_rbga` | `B2` | colour as above, `p4 = 01` | white channel |
| `hvlsr_set_mood_light` | `B3` | mood value | |
| `hvlsr_bluetooth_play` | `BA` | `p0 = 05` | dlc 4 |
| `hvlsr_bluetooth_pause` | `BA` | `p0 = 06` | dlc 4 |
| `hvlsr_bluetooth_skip_forward` | `BA` | `p0 = 09` | dlc 4 |
| `hvlsr_bluetooth_skip_back` | `BA` | `p0 = 0A` | dlc 4 |
| `hvlsr_bluetooth_power_on` | `BB` | `p0 = 01` | dlc 4 |
| `hvlsr_bluetooth_power_off` | `BB` | `p0 = 00` | dlc 4 |
| `hvlsr_bluetooth_get_devicename` | `BB` | `p0 = 02` | answer arrives on `0x143` `B8`/`B9` |
| `hvlsr_bluetooth_disconnect` | `BB` | `p0 = 03` | dlc 4 |

The `B6` bit-7 rule matters for anything that watches the bus: a `B6` whose field byte has bit 7
clear is *not* a volume write and does not touch the mute state. `p1..p3` are bass, mid and
treble; `p0` is master.

`hvlsr_is_active` reads a timestamp, not the bus: it returns true for five seconds after the last
`0x143` frame. `hvlsr_get_fw_version` returns one cached byte, `hvlsr_get_bootloader_version` a
cached word, `hvlsr_get_bluetooth_state` a cached byte. None of them transmit.

## Frames the panel receives

`process_msg` compares the raw id, then a byte inside the frame. Two ids matter for this unit.

**`0x100` — bootloader status.** If `data[0] == 4` the frame is a resend request: the panel sets a
flag that makes it repeat the last page. Otherwise `version = data[1]`, `status = data[2]`, and a
non-zero `data[7]` clears the ack-pending latch. The status values drive the bootloader state
machine: `1` = the unit is in the bootloader and waiting, `2` = ready for the image, `3` = ready
for pages.

Every `0x100` frame also writes zero over the cached firmware-version byte, so
`hvlsr_get_fw_version` returns 0 while the unit is in its bootloader.

**`0x143` — application status.** `data[1]` selects the field:

| `data[1]` | meaning | lands in |
|---|---|---|
| `B0` | firmware version, in `data[3]` | the byte `hvlsr_get_fw_version` returns (`A5 B0 8F 07` = **v7**) |
| `B8` | Bluetooth state, in `data[3]` | `hvlsr_get_bluetooth_state` |
| `B9` | a four-byte chunk of a string: `data[3]` is the offset (0x00–0x1C), `data[4..7]` the bytes | the Bluetooth device name |

`B9` is how the device name arrives, four bytes at a time, and a zero byte in the chunk ends the
string. Bytes past offset 0x1C are ignored.

Only `B0` stamps the activity counter that `hvlsr_is_active` reads — `B8` and `B9` do not. The
stamp is a 1 Hz tick count, not a wall clock, so `hvlsr_is_active` means "a `B0` arrived within
the last five ticks": it is false until the first one arrives, and false whenever the tick count
is behind the stamp.

`0x135`, `0x140` and `0x142` are handled by the same dispatcher for other equipment; the unit
itself uses only `0x100` and `0x143`.

## Bootloader sequence

Used only by the vendor update path. Listed because a replacement must not use it by accident:
**nothing here can read the unit's flash**, so an interrupted update has no read-back to fall
back on.

| step | frame | waits for |
|---|---|---|
| `hvlsr_start_bootloader` | `0x101 A5 BC 7B 01`, then the same on `0x131`, then 250 ms | nothing |
| `hvlsr_bootloader_load_firmware` | nothing | status `1` on `0x100` |
| | `0x101` dlc 1, `01` | status `2` |
| | `0x101` dlc 1, `02` | status `3` |
| `hvlsr_program_page(n)` | on `0x102`: `[n, count_hi, count_lo, 0x69, b0 b1 b2 b3]` per 4 bytes | an ack flag, polled about 400 ms |
| | `0x101` dlc 6, `[05, page, crc32 of that page]` — after each page | — |
| `hvlsr_complete_update_and_restart` | `0x101` dlc 1, `03` then `04` | — |

The order matters: `load_firmware` **busy-waits for status 1 without transmitting anything**, so
the unit has to announce itself before the panel sends its first byte. After that each handshake
is a wait followed by a one-byte command, not a command followed by a wait.

`hvlsr_program_page` sends the page once, then polls the ack flag for about 400 ms (eleven 40 ms
polls in the 11.0.2 build, ten in the installed one). It re-sends **only** when the unit asks —
a `0x100` frame with `data[0] == 4` sets a resend flag, and the next poll re-sends the page and
clears the flag. It is not a fixed retry timer. It returns 1 only if the ack arrived.

## Timing

- `hvlsr_start_bootloader` sleeps 250 ms after the two start frames.
- `hvlsr_program_page` polls an unacknowledged page for about 400 ms before returning failure.
- `hvlsr_is_active` is five ticks of a 1 Hz counter since the last `0x143` `B0` frame.
- The application sends its status at 1 Hz while running (captured: `0x143 A5 B0 8F 07` and
  `A5 B8 8F 00` once a second from a healthy unit).

## Safety-relevant frames

For a replacement application, these change what the room does and must reproduce the vendor's
ordering rather than being sent opportunistically:

- `B5` mute/unmute — the deployed idle daemon (`services/tt-idle-dim/deployed`) sends no B5. Only the unshipped variant in `services/tt-idle-dim` mutes on dim and re-asserts a mute the app lifts.
- `B4` light on/off and `B2`/`B3` colour and mood — the light and the sound share the unit.
- `B6` volume — a `B6` with bit 7 set can unmute as a side effect; see
  [`patches/touchsteam2-hydrovive-mute/README.md`](../../patches/touchsteam2-hydrovive-mute/README.md) (the B6 volume-15 origin) for the B6 unmute path.
- The whole bootloader section: an update erases and rewrites the unit's flash. Do not use it
  without the image in hand and a verified way back.

## Evidence

- TX layout: `hvlsr_*` in the installed library, 0x1e3d8–0x1ec4c.
- RX dispatch and fields: `process_msg` at 0x1ec4c.
- Captures: `cap-thermasol-start.txt` (`0x143 A5 B0 8F 07` and
  `A5 B8 8F 00` at 1 Hz, pre-failure), `idle-steam-off.txt` and `cap-musicon.txt` (`0x131`
  command sequences), plus the live capture described in `docs/14`.
