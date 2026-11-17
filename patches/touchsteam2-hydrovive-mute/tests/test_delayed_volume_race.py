#!/usr/bin/env python3
"""The delayed-volume race.

Utils.toggleMusicAndSource() sets a 2000 ms delay when the music source
changes, then delayMusicVolume() spawns a detached thread that sleeps and calls
OverheadLight.setMasterVolume(). That B6 unmutes the ceiling unit.

Two windows matter:
  A) a timer scheduled in a live session, then power off, then a resume before
     the timer wakes  -> the timer is from the OLD session and must be dropped
  B) a thread spawned before shutdown waking AFTER a later resume -> same
Both must be inert under the shipped (gen) design. The rejected latch design
handled B by suppressing forever, which is what stranded audio.
"""
import sys

MUTE, UNMUTE = "B5:01", "B5:00"
LATCH, GEN, NONE = "latch", "gen", "none"
fails = 0
def check(c, w):
    global fails
    print(("ok   " if c else "FAIL ") + w)
    if not c: fails += 1


class Spk:
    def __init__(self): self.muted = False; self.volume = 10; self.bus = []
    def mute(self):      self.muted = True;  self.bus.append(MUTE)
    def unmute(self):    self.muted = False; self.bus.append(UNMUTE)
    def set_volume(self, v): self.muted = False; self.volume = v; self.bus.append(f"B6:{v:02X}")


class App:
    def __init__(self, spk, mode):
        self.spk, self.mode = spk, mode
        self.in_shutdown = False
        self.gen = 0
        self.latched = False
        self.pending = []                       # (delay, volume, gen-at-spawn)

    def _suppressed(self):
        return self.latched if self.mode == LATCH else (self.in_shutdown if self.mode == GEN else False)

    def ol_unmute(self):
        if self._suppressed(): return
        self.spk.unmute()

    def ol_volume(self, v):
        if self._suppressed(): return
        self.spk.set_volume(v)

    def delay_music_volume(self, v, d):
        if self._suppressed(): return           # do not spawn
        self.pending.append((d, v, self.gen))

    def wake(self):
        woke = []
        for d, v, stamp in sorted(self.pending):
            if self.mode == GEN and stamp != self.gen:
                continue                        # stale: a shutdown intervened
            if self.mode == LATCH and self.latched:
                continue
            self.ol_volume(v); woke.append(v)
        self.pending.clear()
        return woke

    def toggle_music_and_source(self, d=2000):
        self.spk.mute(); self.ol_unmute(); self.delay_music_volume(15, d)

    def shutdown(self):
        if self.mode == GEN: self.gen += 1
        if self.mode == LATCH: self.latched = True
        self.spk.mute(); self.spk.mute()
        prev, self.in_shutdown = self.in_shutdown, True
        try:
            self.toggle_music_and_source()      # via KillBluetooth
        finally:
            self.in_shutdown = prev

    def resume(self):
        self.toggle_music_and_source()


print("-- window A: timer scheduled, power off, resume, timer wakes --")
spk = Spk(); app = App(spk, NONE)
app.toggle_music_and_source()      # user changes source; timer scheduled
app.shutdown(); app.resume()
woke = app.wake()
check(woke.count(15) >= 2, f"UNPATCHED: stale timers fire into the session: woke={woke}")

spk = Spk(); app = App(spk, GEN)
app.toggle_music_and_source()      # timer stamped with the live generation
app.shutdown()                     # generation moves on
app.resume()                       # new session schedules its own timer
woke = app.wake()
check(woke == [15], f"PATCHED: only the post-resume timer fires: woke={woke}")
check(not spk.muted, "PATCHED: resume still restores audio")
check(spk.volume == 15, f"PATCHED: volume applied once: {spk.volume}")

print("\n-- window B: timer spawned before shutdown, wakes while powered off --")
for mode in (NONE, GEN):
    spk = Spk(); app = App(spk, mode)
    app.delay_music_volume(15, 2000)   # spawned in a live session
    app.shutdown()                     # power off before it wakes
    woke = app.wake()
    if mode == NONE:
        check(15 in woke, f"UNPATCHED: pre-shutdown timer still fires: woke={woke}")
    else:
        check(woke == [], f"PATCHED: stale timer dropped: woke={woke}")
        check(spk.muted, "PATCHED: remains muted")
        check(UNMUTE not in spk.bus and "B6:0F" not in spk.bus,
              f"PATCHED: nothing unmuting on the bus: {spk.bus}")

print("\n-- a fresh timer after a resume is still honoured --")
spk = Spk(); app = App(spk, GEN)
app.shutdown()
app.resume()
woke = app.wake()
check(woke == [15], f"post-resume timer fires exactly once: woke={woke}")
check(not spk.muted, "audio is live")

print("\n-- the shutdown teardown itself never schedules a timer --")
spk = Spk(); app = App(spk, GEN)
app.shutdown()
check(app.pending == [], f"no timer queued by shutdown: {app.pending}")

print("\n" + (f"FAILED ({fails})" if fails else "PASSED"))
sys.exit(1 if fails else 0)
