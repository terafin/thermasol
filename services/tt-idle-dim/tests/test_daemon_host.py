#!/usr/bin/env python3
"""End-to-end HOST test of the tt-idle-dim daemon. No hardware, no device.

Builds the daemon for the host with the system cc and drives the REAL daemon
against temp regular files standing in for the backlight sysfs nodes, with an
--input-name that cannot exist so the evdev listener never opens.

Why this exists: the pure-logic tests passed while the real daemon still lost the
brightness. With no input device the listener never opens, so a daemon that knows
it owns a dim must restore IMMEDIATELY -- the existing, already-tested rule is
"listener closed while dimmed -> restore". This test therefore FAILS on a daemon
that merely adopts the value without entering the dimmed state (the 120 s DIM
branch then re-reads the dim value over the real one).
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
NO_SUCH_DEVICE = "tt-no-such-touchscreen-xyz"
RUN = 3.0


class HostDaemonTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp(prefix="tt-idle-host-")
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
        self.set_bright(8)

    def tearDown(self):
        shutil.rmtree(self.d, ignore_errors=True)

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

    def run_daemon(self, seconds):
        p = subprocess.Popen([self.bin, "--input-name", NO_SUCH_DEVICE,
                              "--brightness", self.br, "--status", self.st,
                              "--idle-seconds", "120", "--dim", "8"],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            time.sleep(seconds)
        finally:
            p.send_signal(signal.SIGTERM)
            try:
                p.wait(timeout=5)
            except subprocess.TimeoutExpired:
                p.kill()
                p.wait()

    def learn_boot_id(self):
        """One short run to observe the boot id the daemon records."""
        self.run_daemon(2.0)
        txt = self.read(self.st)
        m = re.search(r"^boot_id=(\w+)$", txt, re.M)
        self.assertIsNotNone(m, "daemon wrote no boot_id; status was:\n" + txt)
        return m.group(1)

    def seed_status(self, boot_id, state, restore, dim):
        self.write(self.st, "state=%s\nrestore_bright=%d\ndim_bright=%d\n"
                            "max_bright=255\nboot_id=%s\n" % (state, restore, dim, boot_id))

    # ---- the bug: a restart while dimmed must recover the real brightness ----
    def test_restart_owned_dim_restores_real_brightness(self):
        boot = self.learn_boot_id()
        self.set_bright(8)                      # still dimmed when we were killed
        self.seed_status(boot, "dim", 71, 8)
        self.run_daemon(RUN)
        self.assertEqual(self.read(self.br), "71",
                         "a restart while dimmed must restore the cached brightness")

    def test_user_changed_brightness_wins(self):
        boot = self.learn_boot_id()
        self.set_bright(50)                     # the user moved it after our dim
        self.seed_status(boot, "dim", 71, 8)
        self.run_daemon(RUN)
        self.assertEqual(self.read(self.br), "50",
                         "a brightness the user changed must not be overridden")

    def test_prior_from_other_boot_ignored(self):
        boot = self.learn_boot_id()
        self.set_bright(8)
        other = ("0" * (len(boot) - 1)) + ("1" if boot[-1] != "1" else "2")
        self.seed_status(other, "dim", 71, 8)
        self.run_daemon(RUN)
        self.assertEqual(self.read(self.br), "8",
                         "a record from another boot says nothing about this panel")

    def test_no_prior_leaves_brightness_alone(self):
        self.set_bright(100)
        self.run_daemon(RUN)
        self.assertEqual(self.read(self.br), "100",
                         "with no prior record the live brightness stands")

    # ---- parent death (PR_SET_PDEATHSIG), real child processes ----
    def _wrapper(self, fifo, parent_death):
        args = [self.bin]
        if parent_death:
            args.append("--parent-death")
        args += ["--input", fifo, "--brightness", self.br, "--status", self.st,
                 "--idle-seconds", "2", "--dim", "8"]
        w = os.path.join(self.d, "wrapper.py")
        with open(w, "w") as f:
            f.write("import subprocess, time\n"
                    "subprocess.Popen(%r)\n"
                    "time.sleep(300)\n" % (args,))
        return w

    def _daemon_pid(self):
        m = re.search(r"^pid=(\d+)$", self.read(self.st), re.M)
        return int(m.group(1)) if m else None

    @staticmethod
    def _alive(pid):
        try:
            os.kill(pid, 0)
            return True
        except OSError:
            return False

    def _parent_death_case(self, parent_death, expect_dead):
        fifo = os.path.join(self.d, "input")
        os.mkfifo(fifo)
        holder = os.open(fifo, os.O_RDWR | os.O_NONBLOCK)
        self.set_bright(71)
        wrapper = subprocess.Popen([sys.executable, "-I", self._wrapper(fifo, parent_death)])
        try:
            self.assertTrue(self._await_status("state=dim", 15.0),
                            "daemon never dimmed; status:\n" + self.read(self.st))
            pid = self._daemon_pid()
            self.assertIsNotNone(pid, "no daemon pid in the status")
            self.assertEqual(self.read(self.br), "8")
            wrapper.kill()                     # SIGKILL the daemon's parent
            wrapper.wait(timeout=5)
            end = time.time() + 8.0
            while time.time() < end and self._alive(pid):
                time.sleep(0.2)
            self.assertEqual(self._alive(pid), not expect_dead,
                             "parent death not propagated (parent_death=%s)" % parent_death)
            if expect_dead:
                self.assertEqual(self.read(self.br), "71",
                                 "the daemon must restore the brightness as it dies")
        finally:
            try:
                wrapper.kill()
            except Exception:
                pass
            pid = self._daemon_pid()
            if pid and self._alive(pid):
                os.kill(pid, signal.SIGKILL)
            os.close(holder)

    def test_parent_death_kills_and_restores(self):
        self._parent_death_case(True, True)

    def test_without_parent_death_the_daemon_survives(self):
        self._parent_death_case(False, False)

    # ---- an external write while we own the dim is adopted, not fought ----
    def _start_attached(self, fifo):
        """Run the daemon on a FIFO so the listener is OPEN -- the only state in
        which it will dim. The holder keeps a writer on the pipe so the daemon's
        reader never sees EOF."""
        self.holder = os.open(fifo, os.O_RDWR | os.O_NONBLOCK)
        self.proc = subprocess.Popen(
            [self.bin, "--input", fifo, "--brightness", self.br, "--status", self.st,
             "--idle-seconds", "6", "--dim", "8"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def _stop_attached(self):
        try:
            self.proc.send_signal(signal.SIGTERM)
            self.proc.wait(timeout=5)
        except Exception:
            self.proc.kill()
            self.proc.wait()
        os.close(self.holder)

    def _await_status(self, needle, seconds):
        end = time.time() + seconds
        while time.time() < end:
            try:
                if needle in self.read(self.st):
                    return True
            except IOError:
                pass
            time.sleep(0.2)
        return False

    def _external_write_case(self, value):
        fifo = os.path.join(self.d, "input")
        os.mkfifo(fifo)
        self.set_bright(71)
        self._start_attached(fifo)
        try:
            self.assertTrue(self._await_status("state=dim", 15.0),
                            "the daemon never dimmed; status:\n" + self.read(self.st))
            # the framework theme change / user write lands under our dim
            self.set_bright(value)
            self.assertTrue(self._await_status("state=active", 6.0),
                            "an external write while dimmed must be adopted: " + self.read(self.st))
            self.assertEqual(self.read(self.br), str(value),
                             "the adopted value must not be overwritten (no fight)")
        finally:
            self._stop_attached()

    def test_external_write_while_dim_is_adopted(self):
        self._external_write_case(71)

    def test_user_intent_while_dim_is_adopted(self):
        self._external_write_case(50)

    # ---- the named device must never be substituted by the path fallback ----
    def test_never_dims_with_no_matching_input_device(self):
        self.set_bright(200)
        self.run_daemon(RUN)
        self.assertEqual(self.read(self.br), "200",
                         "with no matching input device the panel is never dimmed")
        txt = self.read(self.st)
        self.assertIn("input_open=0", txt)
        self.assertNotIn("state=dim", txt)


if __name__ == "__main__":
    sys.argv = [sys.argv[0]]
    unittest.main(verbosity=2)
