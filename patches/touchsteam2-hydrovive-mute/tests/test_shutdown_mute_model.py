#!/usr/bin/env python3
"""Model the installed app's power-off and resume command sequences.

Replays the call order recovered from the 2026-11-06 CAN capture and the
decompiled com.thermasol.touchsteam2 sources, once WITHOUT the patch and once
WITH it, and asserts the resulting frame list.

The model is the real thing that matters: which B5/B6 frames reach the bus.
Frame semantics are from the ceiling-unit firmware:
  B5 01 -> DM 0x07 := 0        (mute)
  B5 00 -> DM 0x07 := 1.0      (unmute)
  B6 xx -> unmute, then DM 0x08 := table[xx & 0x7f]   (0x173c calls 0x1714(0))
"""
import sys

MUTE, UNMUTE = "B5:01", "B5:00"


def b6(vol):
    return f"B6:{vol:02X}"


class Speaker:
    def __init__(self):
        self.muted = False
        self.volume = 10
        self.bus = []

    # --- primitives (what the panel's calls actually produce) ---
    def mute(self):
        self.muted = True
        self.bus.append(MUTE)

    def unmute(self):
        self.muted = False
        self.bus.append(UNMUTE)

    def set_master_volume(self, v):
        self.muted = False            # firmware unmutes first
        self.volume = v
        self.bus.append(b6(v))


class App:
    """Mirrors Utils/OverheadLight from the installed touchsteam2 APK."""

    def __init__(self, spk, patched):
        self.spk = spk
        self.patched = patched
        self.shutdown_muted = False

    # OverheadLight.mute / unmute / setMasterVolume
    def ol_mute(self):
        self.spk.mute()

    def ol_unmute(self):
        if self.patched and self.shutdown_muted:
            return
        self.spk.unmute()

    def ol_set_master_volume(self, v):
        if self.patched and self.shutdown_muted:
            return
        self.spk.set_master_volume(v)

    # Utils.setRoutedVolume -> OverheadLight.setMasterVolume (HV branch)
    def set_routed_volume(self, v):
        self.ol_set_master_volume(max(0, min(15, v)))

    # Utils.toggleMusicAndSource
    def toggle_music_and_source(self):
        self.ol_mute()
        self.ol_unmute()                     # waitForHardwareReaction
        # setMusicSource -> B7 (no-op in firmware), then delayMusicVolume
        self.ol_set_master_volume(15)

    # Utils.loadUserSettings  (RESUME path)
    def load_user_settings(self):
        if self.patched:
            self.shutdown_muted = False      # release before restoring audio
        self.set_routed_volume(10)
        self.toggle_music_and_source()

    # Utils.ShutdownAll          (POWER-OFF path)
    def shutdown_all(self):
        if self.patched:
            self.shutdown_muted = True
        self.ol_mute()                       # 1st mute
        self.ol_mute()                       # 2nd mute
        self.toggle_music_and_source()       # via PersistPauseAndKillBluetooth
        if self.patched:
            self.ol_mute()                   # final word


fails = 0
def check(cond, what):
    global fails
    print(("ok   " if cond else "FAIL ") + what)
    if not cond:
        fails += 1


def run(patched):
    spk = Speaker()
    app = App(spk, patched)
    app.shutdown_all()
    after_shutdown = list(spk.bus)
    shut_muted = spk.muted
    spk.bus.clear()
    app.load_user_settings()
    return after_shutdown, shut_muted, list(spk.bus), spk


print("-- baseline: reproduce the captured power-off sequence --")
bus, muted, _, _ = run(patched=False)
check(bus.count(MUTE) == 3, f"unpatched sends 3 mutes (capture had 3): {bus}")
check(UNMUTE in bus, f"unpatched sends an explicit unmute: {bus}")
check(b6(0x0F) in bus, f"unpatched sends B6 volume 15: {bus}")
check(not muted, "unpatched ends AUDIBLE (the bug)")

print("\n-- patched: power-off must end muted with no unmute --")
bus, muted, _, _ = run(patched=True)
check(UNMUTE not in bus, f"no explicit unmute: {bus}")
check(b6(0x0F) not in bus, f"no B6 volume frame: {bus}")
check(muted, "ends MUTED")
check(bus[-1] == MUTE, f"last frame is a mute: {bus[-1]}")

print("\n-- patched: resume must restore audio --")
bus2, muted2, resume_bus, spk = run(patched=True)
check(UNMUTE in resume_bus or any(b.startswith("B6") for b in resume_bus),
      f"resume sends an unmute or volume: {resume_bus}")
check(not spk.muted, "resume ends AUDIBLE")
check(spk.volume == 15, f"volume restored to 15: {spk.volume}")

print("\n-- patched: a normal (non-shutdown) mute still works --")
spk = Speaker(); app = App(spk, patched=True)
app.ol_mute(); app.ol_unmute()
check(not spk.muted and UNMUTE in spk.bus, "ordinary mute/unmute unaffected")

print("\n-- patched: repeat cycles do not latch --")
spk = Speaker(); app = App(spk, patched=True)
for _ in range(3):
    app.shutdown_all(); assert spk.muted
    app.load_user_settings(); assert not spk.muted
check(True, "3x shutdown/resume cycles stay consistent")

print("\n" + (f"FAILED ({fails})" if fails else "PASSED"))
sys.exit(1 if fails else 0)
