# cix-sources 7.2.9 plan

Status: proposed, nothing implemented. Drafted 2026-10-10.

## Context
- gentoo-sources is at 7.2.9 (7.2.7-7.2.9 available) after emerge-webrsync. Running kernel: 7.1.5-cix.
- Overlay has cix-sources 7.0.14 and 7.1.5 only. `files/7.1` has 98 files: the CIX set plus local fixes (0072-0087, TODO, .deferred).
- Upstream cixtech/cix-linux-main is at 6d69935 (2026-08-26). It has patches-7.1 but no patches-7.2.
- The local CIX clone (CIX/cix-linux-main) was behind (19f2947). It has been fetched to origin/main.
- Reference config: 16K pages, 48-bit VA, ARCH_CIX=y, gcc 16.1.1. All CIX symbols in use are provided by patches already in files/7.1.

## Task 0 (gate): research rts5453 / IRQ-151 and USB4/USB5 IRQ routing
Must complete before tasks 1-8 start. Claims to verify (reported, unverified):
- The stock rts5453 Type-C PD driver hangs boot due to an IRQ-151 conflict (reported to have bricked boards during bring-up).
- Community installers (e.g. ncz-os) blacklist typec_rts5453 and rts5453 on every boot command line, as a deliberate workaround as of mid-2026.
- The Sept 2026 USB3/USBSSP series fixes DT nodes for USB4/USB5 that were missing a fourth interrupt cell, so their IRQs could not be resolved.
Questions: is the IRQ-151 conflict real, where is it tracked, what is the root cause (ACPI GSI vs SMBus ARA vs PDC wake-mux), does local 0026/0078 (smbus-ara-irq-group-dispatch) already address it, and should rts5453 be blacklisted or built out in the 7.2.9 config/cmdline? Also check whether the missing interrupt cell affects the ACPI path used here.
Outputs: findings added below, and tasks 1-8 adjusted accordingly.

### Task 0 findings (2026-10-10, research complete)
- IRQ-151 / blacklist: confirmed as history only. Source: ncz-os/cix-installer docs/ENGINEERING-EFFORT.md (commit 7a90bafa0). `module_blacklist=typec_rts5453,rts5453` is described as inert and retained as history. The wedge was on an earlier kernel. On 7.2 with the driver built in (`CONFIG_TYPEC_RTS5453=y`) it does not reproduce, and rts5453 binds and works on O6N. Root cause is not documented anywhere found (shared IRQ vs ACPI GSI vs SMBus ARA vs PDC wake-mux).
- USB4/USB5 missing fourth interrupt cell: contradicted. The v4 DTS patch (lore 20260906032440.470788-5) already uses 4-cell GIC specifiers. It is also a DT patch, not used on the ACPI boot path.
- Local patches 0076 and 0078 are not in cixtech/cix-linux-main; they are local-only. 0078 replaces a shared-IRQ owner election with SMBus ARA dispatch (MS-R1 wires two RTS5453 chips to one IRQ, ACPI describes each as Exclusive GpioInt). Whether 0078 is the real fix for the wedge is unverified.
- Current state: /tmp/config has `CONFIG_TYPEC_RTS5453=y`, and /etc/kernel/cmdline has no module_blacklist. Keep built-in, do not blacklist.
- Action: boot-test 0078 on 7.2.9 with rts5453 built in. Check dmesg for `register partner` on both ports and for IRQ errors. If the wedge appears, retest without 0078.

### Overlap review of local patches (2026-10-10)
- 0087 (panthor named gpu_clk_core) is likely obsolete: CIX's new 00112-drm-panthor-Sky1-CIXH5000-ACPI-bring-up already looks up "gpu_clk_core" by name with an unnamed fallback. Drop 0087 and verify by build plus a /dev/dri/renderD* check.
- 0040 matches CIX's renamed 00113 (unchanged content).
- Stacked edits to the same file, keep order: phy-cix-usb3.c (0072, 0073, 0082 on CIX 0024); cix-acpi-resource-lookup.c (0072, 0074, 0085 on CIX 0007); cdnsp-sky1.c (0075, 0081, 0086 on CIX 0025, 0054, 0061, 0062, 0068); rts5453.c (0076, 0078 on CIX 0026).
- 0084 (Kconfig umbrella) conflicts if CIX 0066 is added, since both edit drivers/soc/cix/Kconfig.
- 0086 force-disables SuperSpeedPlus as a workaround. 0083 and the xhci-plat patch are .deferred. TODO-0075 has open follow-ups.

## Tasks
1. Sync files/7.1 with upstream patches-7.1 (6d69935):
   - Remove 0011-drm-panthor-add-acpi-support-for-cix-p1 and 0038-gpu-panthor-fix-suspend-resume-for-sky1.
   - Add the replacements: panthor ACPI CIXH5000 platform binding, Sky1 ACPI bring-up, ACE-Lite/ACE-NONE bus coherency rework, scmi_perf_domain_freq_get helper, SCMI DVFS via perf-genpd.
   - Refresh revised patches: 0003 SCMI ACPI, 0012 pdc (IS_ERR), 0045 gpt timer (ERR_PTR ioremap), 0048 pinctrl (dbg_show early return), 0063 GPU energy model.
   - Pick up the transport-probe infinite-recursion fix.
2. Re-test the local patches against the reworked panthor: 0040 and 0087 (named gpu_clk_core lookup). Rebase or drop them.
3. Create files/7.2 from the synced 7.1 set. Run patch --dry-run against gentoo-sources 7.2.9 and rebase failures. Likely areas: linlondp (1001-1009), panthor, thermal IPA, SMMUv3, SCMI, cdns3/typec.
4. Create cix-sources-7.2.9.ebuild from 7.1.5. Bump K_GENPATCHES_VER, keep K_NO_VERSION_CHECK, and fix HOMEPAGE.
5. Decide on 0066-add-cix_dst-driver. It only adds drivers/soc/cix/cix_dst and is unused by the reference config. Default: leave it out.
6. Regenerate the Manifest (ebuild ... manifest).
7. Run make olddefconfig with the reference config and review new or renamed symbols.
8. Build, install with kernel-install (see /root/rebuild-ramdisk.sh), and reboot. Keep the 7.1.5 UKI as a fallback.

## Optional / later
- Review Sky1-Linux/linux-sky1 bugfixes (HDMI/DP audio ELD, hotplug, PWM suspend, build warnings) for cherry-picking. Unofficial, last verified against 6.19 / 7.0-rc1.
- MS-R1 NPU: firmware DSDT lacks _HID on the NPU children. Needs an ACPI SSDT override, not a kernel patch.
- Watch for upstream merges (AUDSS clk/reset, USB cdns3/PHY, ASoC cdns I2S, DMA350) so those patches can be dropped.
