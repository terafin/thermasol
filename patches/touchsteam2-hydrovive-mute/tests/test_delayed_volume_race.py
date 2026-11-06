#!/usr/bin/env python3
"""The delayed-volume race.

Utils.toggleMusicAndSource() sets a 2000 ms delay when the music source
changes, then delayMusicVolume() spawns a detached thread that sleeps and calls
OverheadLight.setMasterVolume(). That B6 unmutes the ceiling unit.

Two windows matter:
  A) shutdown -> user resumes within 2 s -> flag cleared -> stale B6 fires into
     a LIVE session (unmutes what the user is listening to: harmless but wrong)
  B) a thread spawned during shutdown waking AFTER a later shutdown began
Both must be inert with the patch.
"""
import sys

MUTE, UNMUTE = "B5:01", "B5:00"
fails = 0
def check(c, w):
    global fails
    print(("ok   " if c else "FAIL ") + w)
    if not c: fails += 1


class Spk:
    def __init__(self): self.muted = False; self.bus = []
    def mute(self):   self.muted = True;  self.bus.append(MUTE)
    def unmute(self): self.muted = False; self.bus.append(UNMUTE)
    def volume(self, v): self.muted = False; self.bus.append(f"B6:{v:02X}")


class App:
    def __init__(self, spk, patched):
        self.spk, self.patched = spk, patched
        self.flag = False
        self.pending = []                      # (delay, volume) threads

    def ol_unmute(self):
        if self.patched and self.flag: return
        self.spk.unmute()

    def ol_volume(self, v):
        if self.patched and self.flag: return
        self.spk.volume(v)

    def delay_music_volume(self, v, d):
        if self.patched and self.flag:
            return                             # do not spawn
        self.pending.append((d, v))

    def wake(self):
        """Every spawned thread reaches its setMasterVolume call."""
        woke = []
        for d, v in sorted(self.pending):
            if self.patched and self.flag:
                continue                       # guarded at wake
            self.ol_volume(v); woke.append(v)
        self.pending.clear()
        return woke

    def shutdown(self):
        if self.patched: self.flag = True
        self.spk.mute()
        self.spk.mute()
        self.ol_unmute()
        self.delay_music_volume(15, 2000)
        self.spk.mute()
        if self.patched: self.spk.mute()

    def resume(self):
        if self.patched: self.flag = False
        self.ol_volume(10)
        self.ol_unmute()
        self.delay_music_volume(15, 2000)


print("-- window A: shutdown, resume inside the 2 s delay --")
# The question is HOW MANY threads are pending: shutdown must contribute none.
spk = Spk(); app = App(spk, patched=False)
app.shutdown(); app.resume()
check(len(app.pending) == 2, f"UNPATCHED: shutdown AND resume each queued one: {app.pending}")
woke = app.wake()
check(15 in woke, f"UNPATCHED stale B6 fires into the live session: woke={woke}")

spk = Spk(); app = App(spk, patched=True)
app.shutdown(); app.resume()
check(len(app.pending) == 1, f"PATCHED: only resume's own volume is queued: {app.pending}")
woke = app.wake()
check(woke == [15], f"PATCHED: exactly one B6, from resume, not shutdown: woke={woke}")
check(app.spk.bus.count("B5:01") == 4, f"shutdown's mutes all present: {app.spk.bus}")
check(not app.flag, "flag cleared on resume")

print("\n-- window B: thread spawned before shutdown, wakes during it --")
spk = Spk(); app = App(spk, patched=False)
app.delay_music_volume(15, 2000)          # spawned in a live session
app.shutdown()                             # shutdown begins before it wakes
bus_before = list(spk.bus)
woke = app.wake()
check(15 in woke, f"UNPATCHED: the pre-shutdown thread still fires: woke={woke}")

spk = Spk(); app = App(spk, patched=True)
app.delay_music_volume(15, 2000)
app.shutdown()
woke = app.wake()
check(not woke, f"PATCHED: guarded at wake while flag set: woke={woke}")
check(spk.muted, "PATCHED: remains muted after the delayed wake")

print("\n-- patched: shutdown with no resume leaves it muted --")
spk = Spk(); app = App(spk, patched=True)
app.shutdown(); app.wake()
check(spk.muted, "still muted")
check(UNMUTE not in spk.bus, f"no unmute on the bus: {spk.bus}")

print("\n" + (f"FAILED ({fails})" if fails else "PASSED"))
sys.exit(1 if fails else 0)
