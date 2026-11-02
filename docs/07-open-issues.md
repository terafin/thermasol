# 07 — Open issues

Honest list. These are **not** fixed.

---

## 1. The ceiling speaker hisses, and nothing we control silences it

**Symptom.** Continuous hiss from the ceiling speaker, audible in the attached bedroom.
Display dimmed, nothing playing — still hissing. Operator reports stock silenced it "at sleep".

**What was ruled out, with evidence:**

| Test | Result |
|---|---|
| Panel audio chain idle (codec DAPM bias off, SAI5 clock disabled, AudioFlinger standby, no PCM) | hiss unchanged |
| Nine distinct CAN controls (standby, HV mute, music off, BT power off, BT disconnect, master vol 0, source 0, codec headphone off, codec line out off) — each verified on the bus | hiss unchanged |
| Android Bluetooth disabled | hiss unchanged |
| ~40 s of total host CAN silence (vendor app + service frozen) | hiss unchanged |
| **Full SoC suspend** (`echo mem`), panel dark and off the network | **hiss unchanged** |
| Codec actively driving digital silence into the amp | hiss unchanged |

**What that means.** The panel emits nothing, and the noise survives the panel being
completely suspended. The hiss is generated **inside the ceiling unit**.

**Structural finding that explains much of the confusion:** `slsr_is_active = 0` — the legacy
SLSR device **is not present on this installation**. Every `slsr_*` command is a no-op,
including `slsr_voice_mute` (which transmits nothing at all). The live device is the HVLSR
(`hvlsr_is_active = 1`, firmware 7).

**Firmware.** The vendor publishes exactly one HydroVive image
(`firmware/hydrovive/latest.bin`, 47,676 bytes, dated 2021-09-21). The panel reports **7.0.0**.
There is no newer speaker firmware to install. The app's own *System updates* entry opens the
updater and immediately closes — nothing to do. The `esv_*`/DSV-4000 controller firmware that
*is* available is irrelevant: `esv_get_is_dongle_present = false`, that device isn't here.

**Not attempted.** Flashing the DSV-4000 firmware anyway (wrong device), or a bus-level tap at
the speaker (needs hardware access to the ceiling unit).

**Next step, if it is ever chased again:** power-cycle the **speaker's own** supply (separate
from the panel's) and listen. If the hiss clears, it is a stuck amp state and the fix is a
power path to that unit. If it does not, it is a hardware/firmware fault and needs ThermaSol.

---

## 2. Deep suspend must never be used

`echo mem > /sys/power/state` **never wakes.**

- No RTC or alarm wake source exists: `/dev/rtc*` and `/dev/alarm` are absent.
- The maXTouch device is registered as a wake source (`device/power/wakeup = enabled`) but
  its IRQ does not bring the SoC out of `mem`.
- Ethernet is not a wake source, so ADB and SSH are gone too.
- Recovery is the mains breaker.

This was learned the hard way — see [08-lessons.md](08-lessons.md). It is why the idle policy
uses backlight-0 plus a `SCREEN_BRIGHT` wake lock rather than real sleep.

---

## 3. Wi-Fi is physically destroyed

Damaged by soldering instructions given by a previous agent. There is no Wi-Fi path and no
further soldering is sanctioned. **Ethernet only.** This is not a software problem and should
not be attempted as one.

---

## 4. Bluetooth audio throughput

Bring-up baud is **115200**. That is enough to connect and stay connected; it is not enough
for A2DP audio. A higher-baud configuration is a separate piece of work, not started.

Related, untested: pairing a real peer, RF range, and audio through an accessory. The stack
discovers devices (`HCI_SUCCESS`) and never pairs with an unknown device on purpose.

---

## 5. Home Assistant is heavy

The main HA dashboard runs ~82% of four-core capacity on this 2 GiB SoC, with WebView
tile-memory warnings and a duplicate custom-card registration error. It *works*; it is not
pleasant. A lighter dashboard would help more than any code change.

---

## 6. Chrome / WebView GPU incompatibility

The stock WebView is Chromium 74 (2019) and the GPU stack does not support it properly.
Modern web UIs fail in it. Mitigation used: native apps wherever possible, and a
Chromium-based browser of its own for the rest.

---

## 7. Apple TV sign-in

Deferred by the operator; not started. Netflix DRM and Plex both work, and native YouTube
works.

---

## 8. Physical things not certified

- Speaker silence and light output are **commands sent**, not observed by a human. Only the
  operator can confirm them.
- The waterproof seal was applied by the operator; nothing here certifies it.
- Long-term thermal behaviour under sustained steam is not characterised.

---

## 9. Nothing here is ThermaSol-approved

The vendor app has been modified (two UI-only methods). The HAL binary was replaced. The
device tree was changed. ThermaSol has not been asked, and would not bless it. If the panel
ever needs warranty service, this is entirely non-stock.
