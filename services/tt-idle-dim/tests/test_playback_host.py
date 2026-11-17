#!/usr/bin/env python3
"""End-to-end HOST test of the media-aware idle suppression in tt-idle-dim.

No hardware, no device. Builds the daemon for the host and drives the REAL
daemon against temp regular files standing in for the backlight sysfs nodes.
The evdev listener is a FIFO held open (so the daemon believes a touchscreen is
attached and will dim), and the parent playback controller is a PIPE on the
daemon's stdin that this test writes PLAYING/IDLE to exactly as a Java sender
would, once a second.

Each case asserts panel brightness AND the daemon's own status file, so a
"passing" test cannot be a daemon that merely stopped writing.
"""
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.dirname(HERE)
CC = os.environ.get("CC", "cc")
IDLE_S = 3                    # daemon --idle-seconds: dim 3 s after last activity
DIM = 8
BRIGHT = 71


class PlaybackHostTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp(prefix="tt-pb-host-")
        cls.bin = os.path.join(cls.tmp, "tt_idle_dim_host")
        r = subprocess.run([CC, "-O2", "-Wall", "-o", cls.bin,
                            os.path.join(SRC, "idle_dim.c"),
                            os.path.join(SRC, "idle_logic.c"),
                            os.path.join(SRC, "playback_control.c"),
                            os.path.join(SRC, "hv_can.c")],
                           capture_output=True, text=True)
        if r.returncode != 0:
            raise unittest.SkipTest("host build failed:\n" + r.stderr)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def setUp(self):
        self.d = tempfile.mkdtemp(prefix="run-", dir=self.tmp)
        self.br = os.path.join(self.d, "brightness")
        self.mx = os.path.join(self.d, "max_brightness")
        self.st = os.path.join(self.d, "status")
        self.write(self.mx, "255")
        self.set_bright(BRIGHT)
        self.in_fifo = os.path.join(self.d, "input")
        os.mkfifo(self.in_fifo)
        self.holder = os.open(self.in_fifo, os.O_RDWR | os.O_NONBLOCK)
        self.rfd, self.wfd = os.pipe()
        self.proc = None

    def tearDown(self):
        self.stop()
        try:
            os.close(self.holder)
        except OSError:
            pass
        for fd in (self.rfd, self.wfd):
            if fd is None:
                continue
            try:
                os.close(fd)
            except OSError:
                pass
        shutil.rmtree(self.d, ignore_errors=True)

    # ---- helpers ----
    @staticmethod
    def write(p, s):
        with open(p, "w") as f:
            f.write(s)

    @staticmethod
    def read(p):
        with open(p) as f:
            return f.read().strip()

    def set_bright(self, v):
        self.write(self.br, str(v))

    def bright(self):
        return self.read(self.br)

    def status(self):
        txt = self.read(self.st)
        return dict(re.findall(r"^(\w+)=(.*)$", txt, re.M))

    def start(self, playback=True, extra=()):
        args = [self.bin, "--input", self.in_fifo, "--brightness", self.br,
                "--status", self.st, "--idle-seconds", str(IDLE_S), "--dim", str(DIM)]
        if playback:
            args.append("--playback-stdin")
        args += list(extra)
        self.proc = subprocess.Popen(args, stdin=self.rfd,
                                     stdout=subprocess.DEVNULL,
                                     stderr=subprocess.DEVNULL)

    def stop(self):
        if self.proc is not None:
            try:
                self.proc.send_signal(signal.SIGTERM)
                self.proc.wait(timeout=5)
            except Exception:
                self.proc.kill()
                self.proc.wait()
            self.proc = None

    def send(self, line):
        os.write(self.wfd, line.encode())

    def close_stdin(self):
        os.close(self.wfd)
        self.wfd = None

    def feed(self, line, seconds, period=0.5):
        """Send `line` every `period` s for `seconds` (ticks the heartbeat)."""
        end = time.time() + seconds
        while time.time() < end:
            self.send(line + "\n")
            time.sleep(period)

    def await_bright(self, want, seconds):
        end = time.time() + seconds
        while time.time() < end:
            try:
                if self.bright() == str(want):
                    return True
            except IOError:
                pass
            time.sleep(0.2)
        return False

    def await_status(self, key, want, seconds):
        end = time.time() + seconds
        while time.time() < end:
            try:
                if self.status().get(key) == want:
                    return True
            except IOError:
                pass
            time.sleep(0.2)
        return False

    def learn_boot_id(self):
        """Run once (playback silent) just to observe the recorded boot id."""
        self.start(playback=True)
        boot = None
        end = time.time() + 4.0
        while time.time() < end and not boot:
            try:
                boot = self.status().get("boot_id")
            except IOError:
                pass
            time.sleep(0.2)
        self.stop()
        os.close(self.wfd)
        self.wfd = None
        # a fresh pipe for the next run
        self.rfd, self.wfd = os.pipe()
        self.assertIsNotNone(boot, "daemon never wrote a status file")
        return boot

    # ================= the protocol cases =================

    def test_playing_prevents_dim(self):
        """A parent reporting PLAYING keeps the panel lit past the idle timeout."""
        self.start()
        self.feed("PLAYING", IDLE_S + 3)
        self.assertEqual(self.bright(), str(BRIGHT),
                         "PLAYING must suppress the idle dim")
        self.assertEqual(self.status().get("playback"), "playing")
        self.assertNotEqual(self.status().get("state"), "dim")

    def test_idle_dims_after_timeout(self):
        """A known IDLE hands the panel back to the normal idle/tap logic."""
        self.start()
        self.feed("IDLE", IDLE_S + 3)
        self.assertTrue(self.await_bright(DIM, 6.0),
                        "a known IDLE must allow the idle dim; status: %s" % self.status())
        self.assertEqual(self.status().get("playback"), "idle")

    def test_playing_while_dim_restores(self):
        """PLAYING arriving while we own the dim must restore immediately."""
        self.start()
        self.feed("IDLE", IDLE_S + 3)
        self.assertTrue(self.await_bright(DIM, 6.0), "never dimmed first")
        self.feed("PLAYING", 3.0)
        self.assertTrue(self.await_bright(BRIGHT, 5.0),
                        "PLAYING while dimmed must restore the panel")
        self.assertEqual(self.status().get("playback"), "playing")

    def test_eof_unknown_restores(self):
        """Parent death (stdin EOF) is a fault, not an IDLE: restore and inhibit."""
        self.start()
        self.feed("IDLE", IDLE_S + 3)
        self.assertTrue(self.await_bright(DIM, 6.0), "never dimmed first")
        self.close_stdin()                       # the parent is gone
        self.assertTrue(self.await_bright(BRIGHT, 6.0),
                        "EOF must restore the panel, not leave it dimmed")
        self.assertTrue(self.await_status("playback", "unknown", 4.0),
                        "EOF must degrade to UNKNOWN; status: %s" % self.status())
        # and it must NOT have adopted its own dim value as the thing to restore
        self.assertEqual(self.status().get("restore_bright"), str(BRIGHT),
                         "the restore target must be the pre-dim brightness, never 8")

    def test_initial_unknown_never_dims(self):
        """No word from the parent at all: never dim (fail safe over live video)."""
        self.start()
        time.sleep(IDLE_S + 4)                   # silence, pipe still open
        self.assertEqual(self.bright(), str(BRIGHT),
                         "with no trusted parent the panel must stay lit")
        self.assertEqual(self.status().get("playback"), "unknown")
        self.assertNotEqual(self.status().get("state"), "dim")

    def test_heartbeat_expiry_degrades_to_unknown(self):
        """Silence past the 5 s heartbeat window is UNKNOWN even without EOF."""
        self.start()
        self.feed("PLAYING", 2.0)                # establish PLAYING, then fall silent
        self.assertEqual(self.status().get("playback"), "playing")
        self.assertTrue(self.await_status("playback", "unknown", 8.0),
                        "a stale heartbeat must degrade to UNKNOWN")
        self.assertEqual(self.bright(), str(BRIGHT), "and must not dim")

    def test_status_reports_fresh_heartbeat(self):
        """The status carries a fresh CLOCK_MONOTONIC heartbeat to gate on."""
        self.start()
        self.feed("PLAYING", 2.5)
        st = self.status()
        self.assertEqual(st.get("playback"), "playing")
        for k in ("heartbeat_ms", "playback_heartbeat_ms", "boot_id"):
            self.assertIn(k, st, "status is missing %s: %s" % (k, st))
        age = int(st["heartbeat_ms"]) - int(st["playback_heartbeat_ms"])
        self.assertGreaterEqual(age, 0)
        self.assertLessEqual(age, 5000,
                             "the parent gates on a <=5 s old heartbeat")

    def test_unknown_does_not_adopt_own_zero(self):
        """A restart into UNKNOWN must restore the cached brightness, not the dim value."""
        boot = self.learn_boot_id()
        self.set_bright(DIM)                     # killed while still dimmed
        self.write(self.st, "state=dim\nrestore_bright=%d\ndim_bright=%d\n"
                            "max_bright=255\nboot_id=%s\n" % (BRIGHT, DIM, boot))
        self.start(playback=True)                # initial UNKNOWN, silent stdin
        self.assertTrue(self.await_bright(BRIGHT, 6.0),
                        "an owned dim under UNKNOWN must restore the real brightness")
        self.assertEqual(self.status().get("restore_bright"), str(BRIGHT))

    def test_disabled_flag_keeps_legacy_behaviour(self):
        """Without --playback-stdin the daemon dims exactly as it always did."""
        self.start(playback=False)
        self.assertTrue(self.await_bright(DIM, IDLE_S + 5),
                        "the legacy idle dim must still fire when the feature is off")
        self.assertEqual(self.status().get("playback"), "disabled")


if __name__ == "__main__":
    sys.argv = [sys.argv[0]]
    unittest.main(verbosity=2)
