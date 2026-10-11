# Vendor coverage audit: files/7.1 (95 patches) -> files/7.2 (85 patches)

Scope: every patch in `sys-kernel/cix-sources/files/7.1/` mapped to its disposition
in `sys-kernel/cix-sources/files/7.2/`. Coverage judged by symbol/function/HID/string
grep against the whole 7.2 set, not by filename. Cross-checked against the applied
7.2 tree at `.patchwork/base/` (has `drivers/usb/cdns3/cdns3-sky1.c`,
`USB_CDNS3_SKY1`) where a hunk was in doubt.

Totals: **79 CARRIED (same filename) / 16 REPLACED / 0 DROPPED.**

Method note: for every 7.1 patch I extracted its added code lines (trimmed, >15 chars,
comments/headers excluded) and tested each for verbatim presence anywhere in `7.2/*.patch`
(the `.patchwork` per-command `/tmp` is ephemeral, so this was run inline). This finds
rewrites; every residual miss was then read in context and judged by symbol.

---

## 1. Disposition table

### 1a. REPLACED (16) — no same-name file; superseded by a differently-named patch

| Vendor patch (7.1) | Disposition | Evidence |
|---|---|---|
| 0011-drm-panthor-add-acpi-support-for-cix-p1.patch | REPLACED -> 7.2/0011-drm-panthor-add-sky1-acpi-support.patch | `grep -cn 'CIXH5000\|gpu_clk_core\|DPM_FLAG_NO_DIRECT_COMPLETE\|panthor_device_resume' 7.2/0011-...` = 9; lines 288-292 `acpi_dev_hid_uid_match(..., "CIXH5000", NULL)`, 391-395 `gpu_clk_core` named lookup, 452-454 `DPM_FLAG_NO_DIRECT_COMPLETE` |
| 0038-gpu-panthor-fix-suspend-resume-for-sky1.patch | REPLACED -> 7.2/0011 | `grep -n 'panthor_sky1_hw_prepare\|gpu_reset\|QCHANNEL' 7.2/0011` : 361 `panthor_sky1_hw_prepare()`, 369-380 `reset_control_assert/deassert(gpu_reset)` + `usleep_range`, 384 `RCSU_QCHANNEL_ENABLE`; called from resume at 505. The 7.1 `*_noirq` ops are folded into the resume path. |
| 0040-panthor-set-DPM_FLAG_NO_DIRECT_COMPLETE-for-STR-on-s.patch | REPLACED -> 7.2/0011 | `grep -n 'DPM_FLAG_NO_DIRECT_COMPLETE' 7.2/0011` : line 454 (inside `panthor_is_cix_sky1()` guard) |
| 0087-drm-panthor-restore-named-gpu_clk_core-acpi-clock-lookup.patch | REPLACED -> 7.2/0011 | `grep -n 'gpu_clk_core' 7.2/0011` : 395 `devm_clk_get(ptdev->base.dev, "gpu_clk_core")`; 404 `gpu_clk_stacks`. 7.1 used `devm_clk_get_optional`; semantics preserved (core clock is required, fallback named lookup). |
| 0025-usb-add-usb-cdns3-driver-for-cix-soc.patch | REPLACED -> 7.2/0025-usb-cdns3-add-audited-sky1-platform-support.patch | `grep -cn 'CIXH2030\|CIXH2031\|cix_usb_clk_names\|sky1_program_controller\|cdnsp_sky1_assert_resets' 7.2/0025` = 10. Base glue is rewritten from `cdnsp-sky1.c` into `cdns3-sky1.c` (new file mode at patch line 460) + `cdns3-sky1.h` (1345). |
| 0029-usb-cdns3-fix-spin-lock-issue-in-suspend-resume.patch | REPLACED -> 7.2/0025 | `cdns3_controller_resume()` in 7.2/0025 lines 363-373: `ret = cdns_resume(cdns);` runs **outside** the lock, then `spin_lock_irqsave(&cdns->lock, flags); cdns->in_lpm = false; spin_unlock...`. The "`cdns_resume()` may sleep" fix is preserved (and made error-checked). |
| 0054-usb-cdns3-fix-TypeC-hotplug-enumerati-on-failure.patch | REPLACED -> 7.2/0025 | **PARTIAL — see GAP G2.** `grep -rn 'platform_reset\|cdns_role_set' 7.2/*.patch` = NONE. `cdns_role_set()` in the applied tree (`.patchwork/base/drivers/usb/cdns3/core.c:348-383`) does `cdns_role_stop(); cdns_role_start();` with no controller reset. |
| 0061-DPTSW-24991-usb-fix-SError-during-poweroff-by-releas.patch | REPLACED -> 7.2/0025 | **PARTIAL — see GAP G3.** `grep -rn 'device_release_driver' 7.2/*.patch` hits only 0031 (PCI) and 0078/0088 (I2C), never USB cdns3. 7.2 `cdnsp_sky1_shutdown()` (line 1271) just calls `hw_stop()` and comments that children shut down first. |
| 0062-DPTSW-25423-usb-cdns3-sky1-disabled-IRQ-before-disab.patch | REPLACED -> 7.2/0025 | **PARTIAL — see GAP G3.** `grep -rn 'HCD_FLAG_HW_ACCESSIBLE\|disable_irq(hcd->irq)' 7.2/*.patch` = NONE. |
| 0065-usb-cdns3-fix-cdnsp-timeout-at-resume.patch | REPLACED -> 7.2/0025 | `grep -n 'cdns3_restore_platform\|platform_restore\|readl(&cdns->otg_regs->cmd)' 7.2/0025` : 336-343 `cdns3_restore_platform()`, 394-395 `cdns->phys_reinit_pending = true`, drd.c hunk line 1544 `readl(&cdns->otg_regs->cmd)` posted-write flush. Full re-init after power loss preserved via `cdnsp_sky1_hw_init`. |
| 0068-DPTSW-26453-usb-cdns3-sky1-add-phy-dep-check-at-prob.patch | REPLACED -> 7.2/0025 + 0089 | `grep -n 'EPROBE_DEFER' 7.2/0025` : 837/851 `phy = ERR_PTR(-EPROBE_DEFER)`, 952; `device_link_add(dev, phy_dev, DL_FLAG_PM_RUNTIME\|...)` at 855. 7.2/0089 adds `select PHY_CIX_USBDP if ARCH_CIX` + `MODULE_SOFTDEP("pre: phy-cix-usbdp")`. |
| 0075-usb-cdns3-sky1-defer-probe-acpi-race-add-reset-diag.patch | REPLACED -> 7.2/0025 (+0085) | **PARTIAL — see GAP G5.** `grep -rn 'cix_acpi_resource_lookup_defer' 7.2/*.patch` hits only 0072 (PHY) and 0074, never the USB patch. Reset lookups use `devm_reset_control_get_exclusive` (1117/1122), which defers generically. |
| 0077-usb-cdns3-propagate-role-set-reset-failure.patch | REPLACED -> 7.2/0025 | **PARTIAL — see GAP G2.** Same grep as 0054: no `platform_reset`, no error propagation in `cdns_role_set()`. |
| 0081-usb-cdns3-sky1-fix-acpi-otg-detection-fwnode.patch | REPLACED -> 7.2/0025 | **PARTIAL — see GAP G4.** Detection itself preserved: `grep -n 'cdnsp_sky1_has_role_switch' 7.2/0025` : 1079 definition using `device_for_each_child_node()`/`fwnode_property_present(child,"usb-role-switch")`, 1201 use. The `runtime_pm_allow_otg` safety gate is gone. |
| 0084-soc-cix-add-cix-sky1-usb-kconfig-umbrella.patch | REPLACED -> 7.2/0089 + 0090 + 0025 Kconfig | **PARTIAL — see GAP G6.** `select PHY_CIX_USBDP` restored in 0089; TYPEC_RTS5453 `depends on USB_ROLE_SWITCH/ACPI\|OF` + `select I2C_SMBUS` + PHY_CIX `ACPI\|OF` restored in 0090. The `CIX_SKY1_USB` umbrella itself is intentionally not recreated. |
| 0086-usb-cdns3-sky1-force-disable-superspeedplus.patch | REPLACED -> 7.2/0025 | **GAP — see G1.** `grep -rn 'ssp_disable = true' 7.2/*.patch` = NONE. 7.2/0025 line 1150 only reads the ACPI property. |

### 1b. CARRIED (79) — same filename present in 7.2

All 79 filenames exist verbatim in `files/7.2/`. Verbatim-line retention was measured
for each; **75 of 79 retained 100% of added code lines**. The four with residuals were
each inspected and closed:

| Vendor patch (7.1) | Disposition | Evidence for the residual |
|---|---|---|
| 0003-firmware-arm_scmi-add-acpi-support-to-SCMI.patch | CARRIED | 3/98 added lines absent: `device_set_node(&scmi_dev->dev, np)`, `fwnode_handle_get(fwnode)`, `fwnode_handle_put(cinfo->dev->fwnode)`. **Documented intentional drop** in the 7.2 patch header lines 11-30: upstream v7.2.6 removed the `of_node_get/put` refcounting at those 3 `driver.c` sites, so reintroducing the fwnode equivalent would reverse an upstream cleanup. The `bus.c` reference is kept. Not a gap. |
| 00101-drm-linlondp-merge-updates-from-26q2.patch | CARRIED | 1/985 absent: `drm_printf(p, "\tplane_mask=%llx\n", ...)`. Known-intentional: cancelled against 1009's `%x` revert. Both `drm_atomic.c` hunks dropped elsewhere in 7.2; no functional change. |
| 1009-linlondp-fix-WERROR.patch | CARRIED | 1/27 absent: `drm_printf(p, "\tplane_mask=%x\n", ...)` — the counterpart of the above. Same intentional disposition. |
| 0052-add-thermal-IPA-support.patch | CARRIED | 1/169 absent: `goto free_memory;`. 7.2 has `if (result) return result;` instead. `acpi_thermal_get_sustainable_power()` and `tzp.sustainable_power` are both present (7.2/0052 lines 335, 349, 398, 433). Functionality kept; only the error-path cleanup target differs (`grep -rn free_memory 7.2/*.patch` = none). Minor, not a gap. |

Explicitly re-verified known-intentional keeps:
- **0024 (vendor PHY) CARRIED** — 100% line retention; `typec orientation switch` handler present in both 7.1 and 7.2 (`grep -c` = 3 each).
- **0027 (vendor scan handler) CARRIED** — 100% line retention.
- **0008 / 0041 pmdomain CARRIED**; 7.2 additionally has a new `0003-mailbox-fix-acpi-driver-data-type-confusion.patch` (7.2-only).

---

## 2. FUNCTIONALITY GAPS

### G1 — HIGH: SuperSpeedPlus force-disable lost (`0086`)
- **Affected patch / driver / symbol:** `0086-usb-cdns3-sky1-force-disable-superspeedplus.patch` -> `cdnsp_sky1_probe()`, `struct cdnsp_sky1::ssp_disable`, `XEC_CFG_3XPORT_MODE` bit 31.
- **Vendor fix:** unconditionally `data->ssp_disable = true;` at probe, regardless of the `ssp-disable` ACPI `_DSD` property, because sustained 10 Gbps traffic on the MS-R1 cdnsp/cix-usbdp stack produced periodic device resets under load.
- **7.2 state:** absent. `grep -rn 'ssp_disable = true' 7.2/*.patch` returns nothing; 7.2/0025 line 1150 is `data->ssp_disable = device_property_read_bool(dev, "ssp-disable");` and the only consumer is line 656 `} else if (data->ssp_disable) {`. Confirmed in the applied tree: `.patchwork/base/drivers/usb/cdns3/cdns3-sky1.c:686` and `:192`.
- **Why it matters:** on firmware that does not set `ssp-disable`, the 7.2.9 kernel re-enables 10 Gbps Gen2, reinstating the exact instability the vendor patch worked around. Affects USB storage reliability on USB-C/SSP ports; a USB-booted or USB-rooted MS-R1 can lose its device under load.

### G2 — MEDIUM/HIGH: controller reset on Type-C role change lost (`0054` + `0077`)
- **Affected patch / driver / symbol:** `0054` + `0077` -> `cdns3_platform_data::platform_reset`, `cdnsp_platform_reset()`, `cdns_role_set()` in `drivers/usb/cdns3/core.c`.
- **Vendor fix:** `0054` added a `platform_reset` hook wired to `cdnsp_sky1_drd_init()` and called it from `cdns_role_set()` before `cdns_role_start()`, "critical for Type-C hotplug where orientation flip needs to be re-applied to PHY registers". `0077` propagated a reset failure so `cdns_role_start()`/xHCI does not start on an undefined controller.
- **7.2 state:** `grep -rn 'platform_reset\|cdns_role_set' 7.2/*.patch` = NONE; 7.2/0025 does not touch `cdns_role_set()` at all. Applied tree `core.c:348-383` confirms `cdns_role_stop(); ret = cdns_role_start(cdns, role);` with no reset and no failure short-circuit. The rewrite introduced `platform_restore` and `cdnsp_sky1_hw_init()`, but these are only invoked from probe and resume-after-power-loss, never from the role path.
- **Why it matters:** Type-C hotplug / cable-flip enumeration can fail or start the controller in a stale-PHY state — the failure mode `0054` fixed. Note the PHY (`0024`, present in both sets) has its own `typec_orientation_switch` handler, so orientation may be partly re-applied at PHY level; the controller reset and error propagation are nonetheless gone. Medium confidence that this is a net functional regression.

### G3 — LOW/MEDIUM: explicit shutdown quiesce lost (`0061` + `0062`)
- **Affected patch / driver / symbol:** `0061` `device_release_driver(gadget_dev)` / `cdnsp_sky1_find_gadget_match()`; `0062` `disable_irq(hcd->irq)` + `synchronize_irq()` + `clear_bit(HCD_FLAG_HW_ACCESSIBLE, &hcd->flags)`.
- **7.2 state:** `grep -rn 'device_release_driver\|HCD_FLAG_HW_ACCESSIBLE' 7.2/*.patch` finds only unrelated PCI (0031) and I2C (0078) uses. 7.2 `cdnsp_sky1_shutdown()` (0025 line 1271) only locks and calls `cdnsp_sky1_hw_stop()`, relying on the comment "Child CDNSP/xHCI shutdown callbacks run first through device links."
- **Assessment:** the substitute is plausible — children register after the wrapper so `device_shutdown()`'s reverse order runs them first, and `cdnsp_sky1_hw_stop()` asserts the controller resets before gating clocks — but it is an ordering assumption, not the explicit IRQ/gadget quiesce the vendor added for an observed SError-during-poweroff panic. Not proven equivalent; verify with a poweroff stress test.

### G4 — MEDIUM: runtime-PM D3 safety gate removed (`0081`)
- **Affected patch / driver / symbol:** `cdnsp_sky1_runtime_pm_allow_otg` module param, `CDNS3_DEFAULT_PM_RUNTIME_ALLOW` quirk.
- **Vendor fix:** corrected the ACPI child detection (kept in 7.2 as `cdnsp_sky1_has_role_switch()`), but deliberately kept every controller out of runtime PM D3 (`module_param runtime_pm_allow_otg`, default `N`) until wake-from-D3 via rts5453 was storage-stress validated.
- **7.2 state:** `grep -rn 'runtime_pm_allow_otg' 7.2/*.patch` = NONE. 7.2/0025 lines 1201-1202 unconditionally set `data->pdata.quirks = CDNS3_DEFAULT_PM_RUNTIME_ALLOW` whenever a `usb-role-switch` child exists. This is the opposite of the vendor's conservative default.
- **Why it matters:** enables an unvalidated runtime-PM D3 suspend/resume path on the OTG/USB-C controller during boot-time USB-storage use — exactly the combination `0081` was written to avoid.

### G5 — LOW: USB-specific ACPI reset-lookup defer/diagnostics lost (`0075`)
- `grep -rn 'cix_acpi_resource_lookup_defer' 7.2/*.patch` hits only 0072 (PHY) and 0074; the USB patch's conversion of `PTR_ERR(data->reset/preset)` and its reset assert/deassert diagnostics are not present. 7.2 obtains resets with `devm_reset_control_get_exclusive()` (0025 lines 1117/1122) which defers generically, and `0085` (carried) bounds the lookup driver's readiness wait, so the underlying race is addressed elsewhere. Diagnostics only; no known functional loss.

### G6 — LOW: `CIX_SKY1_USB` Kconfig umbrella reduced to 2 explicit selects (`0084`)
- Of the 22 `select`s in 0084, only `PHY_CIX_USBDP` (0089) and `I2C_SMBUS` (0090) are re-expressed. Verified benign against pristine 7.2 Kconfig (`.patchwork/base/drivers/usb/cdns3/Kconfig`): `USB_CDNS_SUPPORT` already does `select USB_ROLE_SWITCH` and `select USB_XHCI_PLATFORM if USB_XHCI_HCD`, so those umbrella selects were redundant. Still unselected by any 7.2 patch: `CIX_ACPI_RESOURCE_LOOKUP`, `CIX_ACPI_USB_SCAN`, `I2C_CADENCE`, `PHY_CIX_USB2/USB3`, `TYPEC_RTS5453`, `PHY_CIX_USBDP`. Note 0090 converts the RTS5453/PHY requirements into `depends on` (not `select`), which is weaker: it no longer force-enables them, it only hides the option when unmet. `USB_CDNSP*` selects are obsolete because 7.2 uses the `USB_CDNS3` IP path (`USB_CDNSP_SKY1` no longer exists). Operator must enable the child drivers manually; not a runtime regression if the distro config already does.

### Non-gaps verified (for completeness)
- `0065` resume re-init: `cdns3_restore_platform()` -> `cdnsp_sky1_hw_init()` on `cdns_power_is_lost()`. Covered.
- `0068` PHY dependency: `-EPROBE_DEFER` in `cdnsp_sky1_get_phy()` + `device_link_add()` + 0089 `select`/`MODULE_SOFTDEP`. Covered.
- `0029` spinlock: `cdns_resume()` outside `cdns->lock`. Covered.
- panthor `0011/0038/0040/0087`: `CIXH5000`, gpu reset assert/deassert, RCSU qchannel, `gpu_clk_core`, `DPM_FLAG_NO_DIRECT_COMPLETE` all present in 7.2/0011. Covered.

---

## 3. Confidence notes

- **High confidence** in all 79 CARRIED filenames, the 16 REPLACED classifications, and G1 (`ssp_disable = true` is unambiguously absent from both the patch set and the applied tree).
- **High confidence** in G4 (gate string absent; 7.2 code enables the quirk unconditionally).
- **Medium confidence on G2** — the vendor's `platform_reset` hook is definitively gone, but I could not rule out that the `0024` PHY typec-orientation switch compensates for the lost controller reset on cable flip. `0024` is present in *both* sets, so it is not a 7.2 substitute introduced by the rewrite.
- **Medium confidence on G3** — I verified the explicit IRQ/gadget quiesce is absent, but did not boot-test whether reverse registration order plus reset-first `hw_stop()` is sufficient. This needs a poweroff/`-f` test on hardware.
- **Not determined:** whether the missing Kconfig `select`s in G6 cause a real build/config gap on a default `cix-sources` config; I verified the symbol relationships in pristine Kconfig but did not run a full `menuconfig` dependency resolution for the overlay's shipped defconfig.
- **Caveat on method:** the verbatim-line retention scan is a heuristic; a rewrite that renames every symbol could in principle hide a gap. Every 0%-retention patch (the 16 REPLACED) and every residual miss was manually read in context, so I believe this did not mask anything.
