// SPDX-License-Identifier: GPL-2.0
#include <linux/clk.h>
#include <linux/clk-provider.h>
#include <linux/cpu_pm.h>
#include <linux/cpumask.h>
#include <linux/device.h>
#include <linux/hrtimer.h>
#include <linux/init.h>
#include <linux/io.h>
#include <linux/kernel.h>
#include <linux/ktime.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/pci.h>
#include <linux/platform_device.h>
#include <linux/pm.h>
#include <linux/pm_domain.h>
#include <linux/pm_qos.h>
#include <linux/pm_runtime.h>
#include <linux/pm_wakeup.h>
#include <linux/regulator/consumer.h>
#include <linux/smp.h>
#include <linux/soc/qcom/qcom_aoss.h>
#include <linux/suspend.h>
#include <linux/tick.h>
#include <asm/arch_timer.h>
#include <asm/sysreg.h>

#define FAR_TICKS (1ULL << 44)
#define CTL_EN    ARCH_TIMER_CTRL_ENABLE
#define CTL_MASK  ARCH_TIMER_CTRL_IT_MASK

static int wake_after_sec = 0;
module_param(wake_after_sec, int, 0644);

static int sync_all_suppliers = 1;
module_param(sync_all_suppliers, int, 0644);

static bool in_s2idle;
static u64 s2idle_fallback_cval;

/* 1. Regulators vreg_l2j_1p2 and vreg_l3j_0p8 kept on (usbc-ldo-always-on) */
static struct regulator *reg_l2j;
static struct regulator *reg_l3j;

static void honor_hold_usbc_ldos(void)
{
	struct device *dev = bus_find_device_by_name(&platform_bus_type, NULL, "fd9000.phy");

	if (!dev)
		return;

	reg_l2j = regulator_get(dev, "vdda12");
	if (!IS_ERR(reg_l2j)) {
		if (regulator_enable(reg_l2j) == 0)
			pr_info("honor_deep_sleep_fix: enabled vreg_l2j_1p2 (vdda12) always-on hold\n");
	} else {
		reg_l2j = NULL;
	}

	reg_l3j = regulator_get(dev, "vdd");
	if (!IS_ERR(reg_l3j)) {
		if (regulator_enable(reg_l3j) == 0)
			pr_info("honor_deep_sleep_fix: enabled vreg_l3j_0p8 (vdd) always-on hold\n");
	} else {
		reg_l3j = NULL;
	}

	put_device(dev);
}

static void honor_release_usbc_ldos(void)
{
	if (reg_l3j) {
		regulator_disable(reg_l3j);
		regulator_put(reg_l3j);
		reg_l3j = NULL;
	}
	if (reg_l2j) {
		regulator_disable(reg_l2j);
		regulator_put(reg_l2j);
		reg_l2j = NULL;
	}
}

/* 2. Wrap qcom_geni_serial PM ops for a98000.serial (BT UART) force_suspend/resume */
static struct device_driver *geni_drv;
static const struct dev_pm_ops *orig_geni_pm;
static struct dev_pm_ops honor_geni_pm;

static int honor_geni_suspend(struct device *dev)
{
	int ret = 0;

	if (orig_geni_pm && orig_geni_pm->suspend) {
		ret = orig_geni_pm->suspend(dev);
		if (ret)
			return ret;
	}
	ret = pm_runtime_force_suspend(dev);
	pr_info("honor_deep_sleep_fix: %s pm_runtime_force_suspend ret=%d\n",
		dev_name(dev), ret);
	return ret;
}

static int honor_geni_resume(struct device *dev)
{
	int ret = 0;

	ret = pm_runtime_force_resume(dev);
	if (ret)
		return ret;

	if (orig_geni_pm && orig_geni_pm->resume)
		ret = orig_geni_pm->resume(dev);

	pr_info("honor_deep_sleep_fix: %s pm_runtime_force_resume ret=%d\n",
		dev_name(dev), ret);
	return ret;
}

static void honor_hook_geni_serial(void)
{
	struct device *dev = bus_find_device_by_name(&platform_bus_type, NULL, "a98000.serial");

	if (!dev)
		return;

	if (dev->driver && dev->driver->pm && dev->driver->pm != &honor_geni_pm) {
		geni_drv = dev->driver;
		orig_geni_pm = geni_drv->pm;
		honor_geni_pm = *orig_geni_pm;
		honor_geni_pm.suspend = honor_geni_suspend;
		honor_geni_pm.resume = honor_geni_resume;
		geni_drv->pm = &honor_geni_pm;
		pr_info("honor_deep_sleep_fix: hooked qcom_geni_serial PM ops for force_suspend/resume\n");
	}
	put_device(dev);
}

static void honor_unhook_geni_serial(void)
{
	if (geni_drv && orig_geni_pm) {
		geni_drv->pm = orig_geni_pm;
		geni_drv = NULL;
		orig_geni_pm = NULL;
	}
}

/* 3. EL1 Timer Mirroring (CNTV -> CNTP with CTL_MASK) */
static void park_cntp(void)
{
	write_sysreg(__arch_counter_get_cntpct() + FAR_TICKS, cntp_cval_el0);
	write_sysreg(CTL_EN | CTL_MASK, cntp_ctl_el0);
	isb();
}

static int el1tmr_cpu_pm(struct notifier_block *nb, unsigned long action, void *v)
{
	u64 ctl, cval;

	switch (action) {
	case CPU_PM_ENTER:
		ctl = read_sysreg(cntv_ctl_el0);
		if ((ctl & CTL_EN) && !(ctl & CTL_MASK))
			cval = read_sysreg(cntv_cval_el0);
		else
			cval = __arch_counter_get_cntpct() + FAR_TICKS;

		if (READ_ONCE(in_s2idle) && wake_after_sec > 0 &&
		    s2idle_fallback_cval > 0 && cval > s2idle_fallback_cval) {
			cval = s2idle_fallback_cval;
		}

		write_sysreg(cval, cntp_cval_el0);
		write_sysreg(CTL_EN | CTL_MASK, cntp_ctl_el0);
		isb();
		break;
	case CPU_PM_ENTER_FAILED:
	case CPU_PM_EXIT:
		park_cntp();
		break;
	}
	return NOTIFY_OK;
}

static struct notifier_block el1tmr_nb = { .notifier_call = el1tmr_cpu_pm };

static void honor_enable_pcie_bridge_d3(void);
static void honor_sync_remaining_suppliers(void);

static int honor_pm_notify(struct notifier_block *nb, unsigned long mode, void *unused)
{
	switch (mode) {
	case PM_SUSPEND_PREPARE:
		honor_enable_pcie_bridge_d3();
		honor_sync_remaining_suppliers();
		if (wake_after_sec > 0) {
			u64 rate = read_sysreg(cntfrq_el0);
			u64 now = __arch_counter_get_cntpct();
			s2idle_fallback_cval = now + rate * (u64)wake_after_sec;
			pr_info("honor_deep_sleep_fix: armed fallback timer for +%ds\n",
				wake_after_sec);
		} else {
			s2idle_fallback_cval = 0;
		}
		WRITE_ONCE(in_s2idle, true);
		break;
	case PM_POST_SUSPEND:
		WRITE_ONCE(in_s2idle, false);
		s2idle_fallback_cval = 0;
		break;
	}
	return NOTIFY_OK;
}

static struct notifier_block honor_pm_nb = {
	.notifier_call = honor_pm_notify,
};

static void init_cntp(void *info)
{
	park_cntp();
}

static void clear_cntp(void *info)
{
	write_sysreg(0, cntp_ctl_el0);
	isb();
}

/* 4. Unprepare unused syscon bi_tcxo clocks */
static const char * const syscon_devs[] = {
	"1fc0000.syscon",
	"1fd3000.syscon",
	"b22000.syscon",
};

static void honor_fix_syscon_clks(void)
{
	int i;

	for (i = 0; i < ARRAY_SIZE(syscon_devs); i++) {
		struct device *dev = bus_find_device_by_name(&platform_bus_type, NULL, syscon_devs[i]);
		struct clk *clk;

		if (!dev)
			continue;

		clk = of_clk_get(dev->of_node, 0);
		if (!IS_ERR(clk)) {
			if (__clk_is_enabled(clk))
				clk_disable(clk);
			clk_unprepare(clk);
			pr_info("honor_deep_sleep_fix: unprepared bi_tcxo on %s\n", syscon_devs[i]);
			clk_put(clk);
		}
		put_device(dev);
	}
}

/* 5. AOSS QMP sleep_mode: cxsd */
static void honor_set_aoss_cxsd(void)
{
	struct device *rsc_dev = bus_find_device_by_name(&platform_bus_type, NULL, "17500000.rsc");
	struct qmp *qmp;

	if (!rsc_dev)
		return;

	qmp = qmp_get(rsc_dev);
	if (!IS_ERR(qmp)) {
		int ret = qmp_send(qmp, "{class: aoss, res: sleep_mode, val: cxsd}");
		pr_info("honor_deep_sleep_fix: sent AOSS sleep_mode: cxsd (ret=%d)\n", ret);
		qmp_put(qmp);
	}
	put_device(rsc_dev);
}

/* 6. Disable wakeup on USB controllers */
static const char * const usb_wake_devs[] = {
	"a200000.usb",
	"a400000.usb",
	"a600000.usb",
	"a800000.usb",
};

static void honor_disable_usb_wakeup(void)
{
	int i;

	for (i = 0; i < ARRAY_SIZE(usb_wake_devs); i++) {
		struct device *dev = bus_find_device_by_name(&platform_bus_type, NULL, usb_wake_devs[i]);
		if (!dev)
			continue;
		if (device_may_wakeup(dev)) {
			device_set_wakeup_enable(dev, false);
			pr_info("honor_deep_sleep_fix: disabled wakeup on %s\n", usb_wake_devs[i]);
		}
		put_device(dev);
	}
}

/* 7. System-sleep-only governor on power-domain-system */
static struct generic_pm_domain *sys_pd;
static struct dev_power_governor *orig_sys_gov;
static struct dev_power_governor honor_sys_gov;

static bool honor_never_power_down_ok(struct dev_pm_domain *pd)
{
	return false;
}

static void honor_setup_system_sleep_only(void)
{
	struct device *dev = bus_find_device_by_name(&platform_bus_type, NULL, "17500000.rsc");
	if (!dev)
		return;

	if (dev->pm_domain) {
		struct generic_pm_domain *gpd = pd_to_genpd(dev->pm_domain);
		if (gpd && gpd->gov && gpd->gov != &honor_sys_gov) {
			sys_pd = gpd;
			orig_sys_gov = gpd->gov;
			honor_sys_gov = *orig_sys_gov;
			honor_sys_gov.power_down_ok = honor_never_power_down_ok;
			gpd->gov = &honor_sys_gov;
			pr_info("honor_deep_sleep_fix: installed system-sleep-only governor on %s\n",
				gpd->name);
		}
	}
	put_device(dev);
}

/* 8. Force bridge_d3 = 1 on PCIe root port 0004:00:00.0 (same as pcie_port_pm=force) */
static void honor_enable_pcie_bridge_d3(void)
{
	struct pci_dev *rp = pci_get_domain_bus_and_slot(4, 0, 0);

	if (rp) {
		rp->bridge_d3 = 1;
		pr_info("honor_deep_sleep_fix: enabled bridge_d3=1 on PCIe RP 0004:00:00.0\n");
		pci_dev_put(rp);
	}
}

/* 9. Sync remaining interconnect & clock-controller genpd providers */
static const char * const icc_sync_devs[] = {
	"1700000.interconnect",
	"interconnect-1",
};

static const char * const genpd_sync_devs[] = {
	"100000.clock-controller",
	"3d90000.clock-controller",
};

static void honor_sync_remaining_suppliers(void)
{
	int i;

	if (!sync_all_suppliers)
		return;

	for (i = 0; i < ARRAY_SIZE(icc_sync_devs); i++) {
		struct device *dev = bus_find_device_by_name(&platform_bus_type, NULL, icc_sync_devs[i]);
		if (dev) {
			if (dev->driver && dev->driver->sync_state) {
				pr_info("honor_deep_sleep_fix: calling sync_state on %s\n", icc_sync_devs[i]);
				dev->driver->sync_state(dev);
			}
			put_device(dev);
		}
	}

	for (i = 0; i < ARRAY_SIZE(genpd_sync_devs); i++) {
		struct device *dev = bus_find_device_by_name(&platform_bus_type, NULL, genpd_sync_devs[i]);
		if (dev) {
			if (dev->of_node) {
				pr_info("honor_deep_sleep_fix: calling of_genpd_sync_state on %s\n", genpd_sync_devs[i]);
				of_genpd_sync_state(dev->of_node);
			}
			put_device(dev);
		}
	}
}

static int __init honor_deep_sleep_init(void)
{
	int ret;

	pr_info("honor_deep_sleep_fix: initializing X1E80100 deep sleep fixes\n");

	honor_setup_system_sleep_only();
	honor_hold_usbc_ldos();
	honor_hook_geni_serial();
	honor_enable_pcie_bridge_d3();

	on_each_cpu(init_cntp, NULL, 1);

	ret = register_pm_notifier(&honor_pm_nb);
	if (ret)
		return ret;

	ret = cpu_pm_register_notifier(&el1tmr_nb);
	if (ret) {
		unregister_pm_notifier(&honor_pm_nb);
		return ret;
	}

	honor_fix_syscon_clks();
	honor_set_aoss_cxsd();
	honor_disable_usb_wakeup();
	honor_sync_remaining_suppliers();

	return 0;
}

static void __exit honor_deep_sleep_exit(void)
{
	cpu_pm_unregister_notifier(&el1tmr_nb);
	unregister_pm_notifier(&honor_pm_nb);
	on_each_cpu(clear_cntp, NULL, 1);
	honor_unhook_geni_serial();
	honor_release_usbc_ldos();
	if (sys_pd && orig_sys_gov)
		sys_pd->gov = orig_sys_gov;
	pr_info("honor_deep_sleep_fix: unloaded\n");
}

module_init(honor_deep_sleep_init);
module_exit(honor_deep_sleep_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Honor MagicBook Art 14 X1E80100 Deep Sleep Fixes");
