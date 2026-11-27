#!/usr/bin/env python3
"""Host tests for imgcheck.py's A/B-record and U-Boot-environment checks (no images needed)."""
import os, struct, subprocess, sys, tempfile, zlib, unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.join(HERE, "imgcheck.py")


def run(*args):
    p = subprocess.run([sys.executable, "-I", TOOL, *args], capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def ab_record(pa, ta, sa, pb, tb, sb, crc_ok=True):
    body = b"\0AB0" + bytes([1, 0, 0, 0]) + bytes([pa, ta, sa, 0, pb, tb, sb, 0]) + bytes(12)
    crc = zlib.crc32(body) & 0xffffffff
    if not crc_ok:
        crc ^= 1
    return (body + struct.pack(">I", crc)).hex(" ")


def env_image(vars_, crc_ok=True):
    data = b"".join(f"{k}={v}".encode() + b"\0" for k, v in vars_) + b"\0"
    data = data.ljust(4096 - 4, b"\0")
    crc = zlib.crc32(data) & 0xffffffff
    if not crc_ok:
        crc ^= 1
    return struct.pack("<I", crc) + data


HOOK = ("setenv autoload no; setenv serverip 192.0.2.1; "
        "if tftpboot ${loadaddr} tt-recover.scr; then source ${loadaddr}; fi")
BOOTARGS = ("init=/init consoleblank=0 androidboot.hardware=freescale androidboot.force_normal_boot=1 "
            "firmware_class.path=/vendor/firmware transparent_hugepage=never androidboot.primary_display=imx-drm")


class ABSelect(unittest.TestCase):
    def test_a_first(self):
        rc, out = run("ab-select", ab_record(15, 0, 1, 14, 0, 1))
        self.assertEqual(rc, 0, out); self.assertIn("first=_a fallback=_b", out)

    def test_b_first(self):
        rc, out = run("ab-select", ab_record(14, 0, 1, 15, 0, 1))
        self.assertEqual(rc, 0, out); self.assertIn("first=_b fallback=_a", out)

    def test_bad_crc_refused(self):
        rc, out = run("ab-select", ab_record(15, 0, 1, 14, 0, 1, crc_ok=False))
        self.assertNotEqual(rc, 0, out); self.assertIn("CRC", out)

    def test_bad_magic_refused(self):
        rec = ab_record(15, 0, 1, 14, 0, 1).replace("00 41 42 30", "00 41 42 31", 1)
        rc, out = run("ab-select", rec)
        self.assertNotEqual(rc, 0, out)


class UbootEnv(unittest.TestCase):
    def check(self, img):
        with tempfile.NamedTemporaryFile(delete=False) as f:
            f.write(img); path = f.name
        try:
            return run("uboot-env", path)
        finally:
            os.unlink(path)

    def test_hook_first(self):
        rc, out = self.check(env_image([("bootcmd", "run tt_nethook; run cmaargs; boota ${fastboot_dev}"),
                                        ("tt_nethook", HOOK), ("bootargs", BOOTARGS)]))
        self.assertEqual(rc, 0, out); self.assertIn("crc=ok", out); self.assertIn("nethook=first", out)

    def test_hook_missing_fails(self):
        rc, out = self.check(env_image([("bootcmd", "run cmaargs; boota ${fastboot_dev}"), ("bootargs", BOOTARGS)]))
        self.assertNotEqual(rc, 0, out)

    def test_bad_crc_fails(self):
        rc, out = self.check(env_image([("bootcmd", "run tt_nethook; boota ${fastboot_dev}"),
                                        ("tt_nethook", HOOK)], crc_ok=False))
        self.assertNotEqual(rc, 0, out)

    def test_no_identifiers_printed(self):
        rc, out = self.check(env_image([("bootcmd", "run tt_nethook; run cmaargs; boota ${fastboot_dev}"),
                                        ("tt_nethook", HOOK), ("bootargs", BOOTARGS),
                                        ("serial#", "DEADBEEF12345678"), ("ethaddr", "02:00:00:00:00:01")]))
        self.assertNotIn("DEADBEEF12345678", out); self.assertNotIn("02:00:00:00:00:01", out)


if __name__ == "__main__":
    unittest.main(verbosity=2)
