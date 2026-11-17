#!/usr/bin/env python3
# Static safety tests for tt_reboot_pin. No device, no network, no root.
#   RED  (module missing): TT_SRC=/nonexistent/tt_reboot_pin.c python3 -I test_tt_reboot_pin.py  -> must FAIL
#   GREEN (built module):                                    python3 -I test_tt_reboot_pin.py
import os, re, sys, unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT = HERE / 'tt_reboot_pin.c'
WRITES = ('iowrite32(', 'writel(', 'writew(', 'writeb(', 'writesl(')

def source():
    return Path(os.environ.get('TT_SRC', DEFAULT)).read_text()

def code_only(s):
    s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
    return re.sub(r'//[^\n]*', '', s)

def body_of(s, header_re):
    # Strip comments first: prose in a comment must not satisfy or defeat an order check.
    s = code_only(s)
    m = re.search(header_re + r'.*?\n\{(.*?)\n\}', s, re.S)
    return m.group(1) if m else ''

class RebootPinGuardTests(unittest.TestCase):
    # 1 -- load/unload must not move the pad.
    def test_1_no_mmio_write_at_load_or_unload(self):
        s = source()
        for name, hdr in (('__init', r'static int __init tt_reboot_pin_init\(void\)'),
                          ('__exit', r'static void __exit tt_reboot_pin_exit\(void\)')):
            b = body_of(s, hdr)
            self.assertTrue(b, 'no %s body' % name)
            for w in WRITES:
                self.assertNotIn(w, b, '%s writes %s: a pad change at load/unload' % (name, w))

    # 2 -- the pin moves on SYS_RESTART and on nothing else, at priority 255.
    def test_2_notifier_fires_only_on_sys_restart(self):
        s = source()
        b = body_of(s, r'static int tt_reboot_notify\(struct notifier_block')
        self.assertTrue(b, 'no notify body')
        self.assertIn('SYS_RESTART', b, 'no SYS_RESTART gate')
        self.assertIn('NOTIFY_DONE', b, 'other actions are not rejected')
        self.assertRegex(b, r'action\s*!=\s*SYS_RESTART', 'gate is not an action != SYS_RESTART test')
        self.assertRegex(s, r'\.priority\s*=\s*255\b', 'notifier priority is not 255')

    # 3 -- unregister before unmap, or a late call dereferences a freed mapping.
    def test_3_unregister_before_iounmap(self):
        b = body_of(source(), r'static void __exit tt_reboot_pin_exit\(void\)')
        self.assertTrue(b, 'no __exit body')
        u = b.find('unregister_reboot_notifier'); m = b.find('iounmap')
        self.assertGreaterEqual(u, 0, 'exit never unregisters the notifier')
        self.assertGreaterEqual(m, 0, 'exit never iounmaps')
        self.assertLess(u, m, 'iounmap before unregister_reboot_notifier')

    # 4 -- exactly two MMIO write sites, at two distinct registers.
    def test_4_exactly_two_mmio_targets(self):
        outs = re.findall(r'iowrite32\s*\(([^,]+),\s*([^)]+)\)', code_only(source()))
        self.assertEqual(len(outs), 2, 'expected exactly 2 iowrite32 sites, got %d' % len(outs))
        targets = {t.strip() for _, t in outs}
        self.assertEqual(len(targets), 2, 'the two writes must hit two distinct registers')
        self.assertTrue(any('TT_PAD_OFF' in t for t in targets), 'no pad register write')
        self.assertTrue(any('TT_MUX_OFF' in t for t in targets), 'no mux register write')

    # 5 -- only the GPIO1_IO02 mux/pad; never GPIO, WDOG, IRQ, timer, poll or input.
    def test_5_only_gpio1_io02_pad_and_mux(self):
        c = code_only(source())
        self.assertIn('0x30330000', c, 'IOMUXC base missing')
        for bad in ('0x30200000', '0x30280000', '0x30290000', '0x302a0000'):
            self.assertNotIn(bad, c, 'reaches a GPIO/WDOG register block (%s)' % bad)
        for bad in ('request_irq', 'devm_request_irq', 'timer_setup', 'mod_timer', 'hrtimer',
                    'input_register', 'poll_wait', 'gpiod_', 'gpio_request', 'writel('):
            self.assertNotIn(bad, c, 'uses %s; must stay write-on-SYS_RESTART only' % bad)

    # 6 -- the module alias is declared once and collides with nothing.
    def test_6_alias_unique(self):
        self.assertEqual(code_only(source()).count('MODULE_ALIAS("tt_reboot_pin")'), 1,
                         'tt_reboot_pin alias must be declared exactly once')
        for c in HERE.glob('*.c'):
            if c.name == 'tt_reboot_pin.c':
                continue
            self.assertNotIn('tt_reboot_pin', c.read_text(), 'alias collides in %s' % c.name)

if __name__ == '__main__':
    del sys.argv[1:]
    unittest.main(verbosity=2)
