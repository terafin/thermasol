// SPDX-License-Identifier: GPL-2.0
/*
 * Experimental reboot handoff for the boot-owned touch-IRQ trial.
 * No pin changes at load/unload. On SYS_RESTART only, restore the original
 * GPIO1_IO02 WDOG1_B mux/pad before firmware performs the reset.
 * This does not establish that the touch trial fixes IRQ delivery.
 */
#include <linux/io.h>
#include <linux/module.h>
#include <linux/notifier.h>
#include <linux/reboot.h>

/* IOMUXC, from the i.MX8MM address map. Only the pad and mux of GPIO1_IO02 are addressed. */
#define TT_IOMUXC_BASE	0x30330000
#define TT_IOMUXC_SIZE	0x1000
#define TT_MUX_OFF	0x030	/* SW_MUX_CTL_PAD_GPIO1_IO02 */
#define TT_PAD_OFF	0x298	/* SW_PAD_CTL_PAD_GPIO1_IO02 */
#define TT_MUX_WDOG_B	0x1	/* ALT1 == WDOG1_WDOG_B */
#define TT_PAD_WDOG_B	0xc6	/* pad ctl value the WDOG_B consumer expects */

static void __iomem *tt_iomuxc;

static int tt_reboot_notify(struct notifier_block *nb, unsigned long action, void *data)
{
	u32 pad, mux;

	if (action != SYS_RESTART)
		return NOTIFY_DONE;

	iowrite32(TT_PAD_WDOG_B, tt_iomuxc + TT_PAD_OFF);
	pad = ioread32(tt_iomuxc + TT_PAD_OFF);
	iowrite32(TT_MUX_WDOG_B, tt_iomuxc + TT_MUX_OFF);
	mux = ioread32(tt_iomuxc + TT_MUX_OFF);

	pr_info("tt_reboot_pin: WDOG_B restored, pad 0x%08x mux 0x%08x\n", pad, mux);
	return NOTIFY_OK;
}

static struct notifier_block tt_reboot_nb = {
	.notifier_call	= tt_reboot_notify,
	.priority	= 255,	/* front of the chain: flip the mux before anything else runs */
};

static int __init tt_reboot_pin_init(void)
{
	int ret;

	/* Map only; deliberately no register access here -- the pad must not move at load. */
	tt_iomuxc = ioremap(TT_IOMUXC_BASE, TT_IOMUXC_SIZE);
	if (!tt_iomuxc)
		return -ENOMEM;

	ret = register_reboot_notifier(&tt_reboot_nb);
	if (ret) {
		iounmap(tt_iomuxc);
		tt_iomuxc = NULL;
		return ret;
	}

	pr_info("tt_reboot_pin: armed on SYS_RESTART\n");
	return 0;
}

static void __exit tt_reboot_pin_exit(void)
{
	/* Unregister first: after the iounmap a late notifier call would use a freed mapping. */
	unregister_reboot_notifier(&tt_reboot_nb);
	iounmap(tt_iomuxc);
	tt_iomuxc = NULL;
}

module_init(tt_reboot_pin_init);
module_exit(tt_reboot_pin_exit);

/* Unique anchor: init and any hotplug match this module by this exact name, never a look-alike. */
MODULE_ALIAS("tt_reboot_pin");
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Restore GPIO1_IO02/WDOG1_WDOG_B on the normal reboot path only");
