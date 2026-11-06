#!/usr/bin/env python3
"""Model the installed app's power-off, resume and timer sequences.

Replays the call order recovered from the 2026-11-06 CAN capture and the
decompiled com.thermasol.touchsteam2 sources, and asserts which B5/B6 frames
reach the bus under three implementations:

  none   the installed app (the bug)
  latch  the first candidate: one boolean set by ShutdownAll and cleared only
         by loadUserSettings(). Rejected -- see the resume test below.
  gen    the shipped candidate: sInShutdown scoped to the bluetooth teardown,
         plus sAudioGen to invalidate timers scheduled before the power-off.

Frame semantics are from the ceiling-unit firmware:
  B5 01 -> DM 0x07 := 0        (mute)
  B5 00 -> DM 0x07 := 1.0      (unmute)
  B6 xx -> unmute, then DM 0x08 := table[xx & 0x7f]   (0x173c calls 0x1714(0))

The resume path matters. loadUserSettings() is reachable only from the two
user-profile buttons (UserFragment) and the dead external-login path, so it is
NOT how a user resumes after a power-off. MusicController, MenusMgr, the
external-app launcher and external-app teardown all resume through
toggleMusicAndSource(). That is the path the patch must leave working.
"""
import sys

MUTE, UNMUTE = "B5:01", "B5:00"
NONE, LATCH, GEN = "none", "latch", "gen"


class Speaker:
    def __init__(self):
        self.muted = False
        self.volume = 10
        self.bus = []

    def mute(self):
        self.muted = True
        self.bus.append(MUTE)

    def unmute(self):
        self.muted = False
        self.bus.append(UNMUTE)

    def set_master_volume(self, v):
        self.muted = False            # firmware unmutes first
        self.volume = v
        self.bus.append(f"B6:{v:02X}")


class App:
    """Mirrors Utils/OverheadLight from the installed touchsteam2 APK."""

    def __init__(self, spk, mode):
        self.spk = spk
        self.mode = mode
        self.in_shutdown = False      # sInShutdown  (scoped to the teardown)
        self.gen = 0                  # sAudioGen
        self.latched = False          # the rejected design's flag
        self.pending = []             # (delay, volume, gen-at-spawn)

    # -- OverheadLight -----------------------------------------------------
    def ol_mute(self):
        self.spk.mute()

    def _suppressed(self):
        if self.mode == LATCH:
            return self.latched
        if self.mode == GEN:
            return self.in_shutdown
        return False

    def ol_unmute(self):
        if self._suppressed():
            return
        self.spk.unmute()

    def ol_set_master_volume(self, v):
        if self._suppressed():
            return
        self.spk.set_master_volume(v)

    # -- Utils.delayMusicVolume -------------------------------------------
    def delay_music_volume(self, volume, delay):
        if self._suppressed():
            return                       # do not spawn
        self.pending.append((delay, volume, self.gen))

    def wake(self):
        """Every spawned timer reaches its setMasterVolume call."""
        woke = []
        for delay, volume, stamp in sorted(self.pending):
            if self.mode == GEN and stamp != self.gen:
                continue                 # shutdown happened after scheduling
            if self.mode == LATCH and self.latched:
                continue
            self.ol_set_master_volume(volume)
            woke.append(volume)
        self.pending.clear()
        return woke

    # -- Utils.toggleMusicAndSource ---------------------------------------
    def toggle_music_and_source(self, delay=2000):
        self.ol_mute()
        self.ol_unmute()                 # waitForHardwareReaction between them
        self.delay_music_volume(15, delay)

    # -- Utils.KillBluetooth / PersistPauseAndKillBluetooth ----------------
    def persist_pause_and_kill_bluetooth(self):
        self.toggle_music_and_source()

    # -- Utils.ShutdownAll ------------------------------------------------
    def shutdown_all(self):
        if self.mode == GEN:
            self.gen += 1                # invalidate timers already scheduled
        if self.mode == LATCH:
            self.latched = True
        self.ol_mute()                   # line 480
        self.ol_mute()                   # line 498
        prev, self.in_shutdown = self.in_shutdown, True
        try:
            self.persist_pause_and_kill_bluetooth()   # line 501
        finally:
            self.in_shutdown = prev
        self.toggle_bluetooth(False)     # line 503 -- no audio calls

    def toggle_bluetooth(self, on):
        pass                             # no unmute/volume on this path

    # -- resume paths ------------------------------------------------------
    def resume_via_music(self, delay=2000):
        """MusicController / MenusMgr / external-app launch."""
        self.toggle_music_and_source(delay)

    def resume_via_user_select(self):
        """Utils.loadUserSettings -- user-profile buttons only."""
        self.set_routed_volume(10)
        self.toggle_music_and_source(0)

    def set_routed_volume(self, v):
        self.ol_set_master_volume(max(0, min(15, v)))


fails = 0
def check(cond, what):
    global fails
    print(("ok   " if cond else "FAIL ") + what)
    if not cond:
        fails += 1


def powered_off(mode):
    """Power off, let every timer the shutdown scheduled reach its call, and
    report what was scheduled before any of them woke."""
    spk = Speaker()
    app = App(spk, mode)
    app.shutdown_all()
    scheduled = list(app.pending)
    app.wake()
    return spk, app, scheduled


print("-- baseline: the installed app reproduces the captured power-off --")
spk, _, _ = powered_off(NONE)
check(spk.bus.count(MUTE) == 3, f"three mutes, as captured: {spk.bus}")
check(UNMUTE in spk.bus, f"an explicit unmute follows them: {spk.bus}")
check("B6:0F" in spk.bus, f"B6 volume 15 follows that: {spk.bus}")
check(not spk.muted, "ends AUDIBLE -- this is the buzz")

for mode in (LATCH, GEN):
    print(f"\n-- {mode}: power-off must be silent --")
    spk, app, scheduled = powered_off(mode)
    check(UNMUTE not in spk.bus, f"no unmute: {spk.bus}")
    check("B6:0F" not in spk.bus, f"no B6 volume frame: {spk.bus}")
    check(spk.muted, "ends MUTED")
    check(spk.bus[-1] == MUTE, f"last frame is a mute: {spk.bus[-1]}")
    check(scheduled == [], f"shutdown scheduled no timer: {scheduled}")

print("\n-- the rejected latch strands audio on the real resume path --")
spk, app, _ = powered_off(LATCH)
spk.bus.clear()
app.resume_via_music()               # what MusicController does
app.wake()
check(spk.muted, f"LATCH: still silent after a music resume: {spk.bus}")
check(UNMUTE not in spk.bus and spk.bus == [MUTE],
      f"LATCH: every restore call was swallowed: {spk.bus}")

print("\n-- the shipped design restores audio from every resume path --")
for label, resume in (("music controller", lambda a: a.resume_via_music()),
                      ("user select", lambda a: a.resume_via_user_select())):
    spk, app, _ = powered_off(GEN)
    spk.bus.clear()
    resume(app)
    check(UNMUTE in spk.bus, f"{label}: sends the unmute: {spk.bus}")
    woke = app.wake()
    check(bool(woke) or spk.volume == 10, f"{label}: volume restored: {woke}")
    check(not spk.muted, f"{label}: ends AUDIBLE")

print("\n-- ordinary audio is untouched outside a shutdown --")
spk = Speaker(); app = App(spk, GEN)
app.ol_mute(); app.ol_unmute()
check(not spk.muted and UNMUTE in spk.bus, "mute/unmute unaffected")
spk.bus.clear()
app.ol_set_master_volume(7)
check(spk.bus == ["B6:07"], f"volume unaffected: {spk.bus}")

print("\n-- repeated power-off / resume cycles do not latch --")
spk = Speaker(); app = App(spk, GEN)
for i in range(3):
    app.shutdown_all(); app.wake()
    assert spk.muted, f"cycle {i}: shutdown not silent"
    spk.bus.clear()
    app.resume_via_music(); app.wake()
    assert not spk.muted, f"cycle {i}: resume did not restore audio"
check(True, "3x shutdown/resume cycles stay consistent")

print("\n" + (f"FAILED ({fails})" if fails else "PASSED"))
sys.exit(1 if fails else 0)
