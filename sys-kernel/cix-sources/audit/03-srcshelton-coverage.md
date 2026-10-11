# 03 — srcshelton coverage audit: does the sibling 7.2.9 overlay carry fixes our set lacks?

Scope: READ-ONLY comparison of our `sys-kernel/cix-sources/files/7.2/` (85 files) against
`srcshelton/gentoo-ebuilds` local copy:
- `.ncz-review/srcshelton-repo/sys-kernel/cix-sources/files/7.2.x/` (88 patches)
- `.ncz-review/srcshelton-repo/sys-kernel/cix-sources/files/` (54 top-level patches)
- index: `.ncz-review/srcshelton-repo/sys-kernel/cix-sources/cix-sources-7.2.9.ebuild`
  (`cix_apply_patch()` vendor-replacement map + `post_vendor_patches[]`)

Hardware filter used for ranking: Minisforum MS-R1 (CIX Sky1 / CP8180, ACPI boot) with
2x Realtek RTL8127 10GbE, Samsung NVMe, Realtek RTS5453 Type-C PD; **no NPU, VPU or
ISP in use**. srcshelton's primary board is the Radxa Orion O6/O6N, so several of its
patches are board-firmware-specific and do not translate to the MS-R1.

## Method / how to read this

1. Built a per-patch file index for both sets and computed, for every srcshelton patch,
   how many of the files it touches are touched by **any** of our 85 patches
   (`coverage_summary.txt` in scratch). `0/N` means our set never modifies that file,
   i.e. our tree there is vanilla 7.2.9 + genpatches.
2. For every candidate, grepped our `files/7.2/*.patch` for the patch's distinctive
   symbols (function names, constants, comments) — decision is never based on filename.
3. Verified hardware match against MS-R1 (e.g. base 7.2.9 `r8169_main.c` already carries
   RTL8127).
4. Confirmed true absence by checking the surrounding code in the base tree
   (`.patchwork/base`, HEAD = linux-7.2 + genpatches-7.2-10) where useful.

Scratch/evidence: `.ncz-review/audit/tmp/coverage/` (`srcshelton_index.txt`,
`ours_index.txt`, `coverage_summary.txt`, `usbdp.diff`, `shl-vs-vendor-rts.diff`).

## Ranked gap list

Legend: **ADOPT** = bring in; **DEFER** = real but needs validation/hardware check;
**REJECT** = do not take (covered elsewhere, policy conflict, or wrong hardware).

### Tier 1 — boot / ACPI-enumeration relevant, MS-R1 likely affected

#### 1. 20050-topology-has-missing-cpufreq-ref — ADOPT
Boot-time WARNING on Sky1 ACPI because `capacity_freq_ref` is 0 when `cppc_cpufreq`
fast-switches. Evidence:

> `WARNING: CPU: ... at drivers/base/arch_topology.c:140 topology_set_freq_scale()`

`drivers/base/arch_topology.c` is **absent** from our 270-file touch union; grepping our
patches for `capacity_freq_ref`, `init_cpu_capacity_callback`, `topology_update_freq_ref`
gives **0 hits**. Our only `cppc_cpufreq.c` changes (0052/0064) are thermal-IPA, not this.
Adopt the arch-topology notifier fix; it is narrow, fixes a real boot warning, and
restores correct frequency invariance on ACPI.

#### 2. 40042-platform-acpi-resolve-named-irq-resources — ADOPT (verify DSDT)
Generic `drivers/base/platform.c` fix for named ACPI IRQ resources that are found before
their GSI is mapped:

> "Named lookup can find an ACPI IRQ resource before its GSI has been mapped. Translate
> the named resource to its IRQ ordinal, then delegate mapping, trigger setup, and error
> handling to `platform_get_irq_optional()`. This is a bounded correction for observed
> CIX ACPI runtime failures."

`drivers/base/platform.c` is **absent** from our union (`0/1`). Our vendor 0007 does map
a disabled IRQ resource with `acpi_irq_get()` at injection time (quoted:
`if ((res->flags & IORESOURCE_IRQ) && (res->flags & IORESOURCE_DISABLED)) acpi_irq_get(...)`)
but only eagerly, and it has no fallback if the GSI is not yet available. This can turn
into -EINVAL at `platform_get_irq_byname()` and fail driver probe at boot. High value if
the MS-R1 DSDT exposes disabled/named IRQ resources; adopt after a DSDT check.

#### 3. 90045-cix-close-platform-driver-dependencies — ADOPT (GPIO part only)
Smallest real dependency bug we lack:

> `+ depends on !ARCH_CIX || PINCTRL_SKY1` (config GPIO_CADENCE)

Our union touches only **1 of 6** files in this patch, and `PINCTRL_SKY1` appears in our
tree only as a header guard inside 0048 — never as a Kconfig `depends`. Our own 0090
declares PHY/TYPEC ACPI deps but not this. Without it GPIO_CADENCE can be built with
PINCTRL_SKY1 off and the Cadence GPIO driver cannot get its pinctrl provider. The
NPU/VPU/fan/RPMsg scoping halves are N/A for us (we carry no NPU/VPU/fan).

#### 4. 30195-firmware-arm-scmi-use-rational-perf-frequency-conversion — ADOPT
`drivers/firmware/arm_scmi/perf.c` is absent from our union (`sustained_freq_hz` = 0
hits). The vendor code emits a boot warning and loses frequency accuracy:

> `dev_warn(ph->dev, "multiplier for domain %d rounded\n", ...)`
> "The current code truncates the multiplier once and then reuses that truncated value,
> accumulating small frequency errors and warning even though the firmware-provided ratio
> is coherent."

Directly relevant to MS-R1 ACPI CPU DVFS (SCMI perf domains). Adopt.

#### 5. 30090-scmi-hwmon-do-not-use-of-thermal-zones-on-acpi — ADOPT
`drivers/hwmon/scmi-hwmon.c` absent from our union; `scmi_thermal_sensor_register` = 0
hits. On ACPI the driver registers every SCMI temperature sensor as a broken OF thermal
zone:

> "ACPI does not provide those OF thermal-zone phandles, so the OF helper returns
> -ENOTSUPP and the driver reports every temperature sensor as a misconfigured thermal
> zone. Only attempt OF thermal-zone registration when the SCMI device has an OF node."

One-line fix (`if (!dev->of_node) return 0;`). Adopt.

#### 6. 80070-pci-disable-aspm-for-sky1-smmu-faulting-endpoints — DEFER / conditional
`drivers/pci/quirks.c` absent from our union (`0/1`). It suppresses ASPM/ClockPM on
Samsung `144d:a809` NVMe and Realtek `10ec:8126` only when MCFG OEM is
`CIXTEK/SKY1EDK2`, because:

> "enabling PCIe ASPM correlated with repeatable arm-smmu-v3 F_TRANSLATION events from
> the Samsung 144d:a809 NVMe and Realtek 10ec:8126 Ethernet endpoints ... The same system
> did not show the event storm with pcie_aspm=off."

MS-R1 has a Samsung NVMe (model needs confirming) but **RTL8127 (0x8127), not 8126** —
that leg of the quirk would not match. Adopt only if the MS-R1 shows the SMMU fault
storm and the NVMe ID is a809; if so, extend the ID table to the 8127 endpoint. Do not
apply blind.

### Tier 2 — runtime / device-specific, MS-R1 hardware present (or gated)

#### 7. 90040-hwmon-cix-add-safe-acpi-fan-control — DEFER / adopt if CIXHA024 present
Our set has **no hwmon driver at all**; `CIXHA024` = 0 hits, patch file coverage `0/3`.
The driver explicitly supports *generic CIX firmware* (two-argument getter, 0..100) in
addition to Radxa's private EC format, so it is plausibly the MS-R1 fan interface:

> "Radxa Orion firmware uses a no-argument private EC getter ... while generic CIX
> firmware uses a two-argument getter with a 0..100 result and 0xffffffff sentinel."

A mini-PC with active cooling could otherwise have no OS fan control. Verify the MS-R1
DSDT exposes `CIXHA024`, then adopt; otherwise defer.

#### 8. 7.2.x/0024 audited USB/DP combo PHY — DEFER (selective port, do not replace)
Our 0024 is the full vendor import (`phy-cix-pcie.c`, `phy-cix-usb2.c`, `phy-cix-usb3.c`,
`phy-cix-usbdp.c`, 3195 lines); srcshelton's 0024 is an audited rewrite of **only**
`phy-cix-usbdp.c` (1712 lines) that drops the PCIe/USB2/USB3 providers ("PCIe, USB2 and
USB3 remain separate deferred workstreams"). We already closed several of the same
fail-path bugs independently (0072/0073/0082), and 0083 (deferred) is the PLL-ready
polling. However srcshelton's version has real runtime fixes we lack, e.g. it stops
poking the PHY mode directly:

- vendor: `udphy->dp_phy->attrs.mode = PHY_MODE_DP;` → srcshelton: `phy_set_mode_ext(udphy->dp_phy, PHY_MODE_DP, 0)`
- refuses an active 4-lane DP→DP+USB transition (`return -EBUSY`) instead of silently
  reconfiguring; guards the GOP-handoff clock against double-enable; validates DP
  lane/voltage config; adds owned PHY-lookup create/remove.

Recommendation: keep our vendor driver (we need the extra PHY providers), cherry-pick
the `phy_set_mode_ext` conversion, the active-transition guard and the lookup lifetime
handling. Not a wholesale adopt.

#### 9. 70195-drm-cix-dptx-fix-mst-lock-leaks — ADOPT (small)
Our `00100` carries `trilin_drm_mst.c` and still leaks `mst_lock` on the
`trilin_dp_prepare()` failure path (confirmed in the extracted vendor file:
`return;` with no `mutex_unlock`). srcshelton:

> "Release the MST serialization mutex on both early enable and disable exits.
> Returning with the mutex held blocked later MST operations."

#### 10. 40055-gpio-pinctrl-enforce-sky1-pad-ownership — DEFER
Our union touches both files (0017, 0048) but has **no** `pinctrl_gpio_request`/
`gpiochip_generic_request`/`cdns_gpio_sky1_add_pin_ranges`. srcshelton routes GPIO
request/free through generic pinctrl ownership and makes Sky1 mux ownership strict.
Correctness fix for pin conflicts; runtime, not boot. Defer pending a pin-use review.

#### 11. 70150-drm-support-up-to-64-planes — ADOPT (revisit earlier defer)
Earlier deferred, but our own 00101 (vendor 26q2 merge) already contains generic-DRM
hunks written for 64-bit masks: `__field(u64, plane_mask)`,
`- unsigned plane_mask; + u64 plane_mask;`, and the comment
`/* plane index is used with 64bit bitmasks (see drm_plane_mask) */`. The conversion is
incomplete because the state field and helper are still 32-bit in our tree:
`u64 plane_mask` appears only in 00101; `1ULL << drm_plane_index` = 0 hits; srcshelton
70150's files (`include/drm/drm_crtc.h`, `include/drm/drm_plane.h`, `drm_atomic.c`) are
absent from our union. This is a small, self-contained generic-DRM fix that completes
vendor intent; adopt unless we can prove ≤32 planes are ever registered.

#### 12. 40093-pci-cix-enable-root-port-io-window-assignment — DEFER
`drivers/pci/probe.c` absent (`0/1`). CIX Sky1 root port `17cd:0100` has its bridge I/O
window left disabled by firmware while the parent bus has a valid I/O aperture, so
endpoints with legacy I/O BARs fail assignment. Only affects I/O-BAR cards (NVMe/10GbE
use MMIO); adopt only if such a card is used.

#### 13. 30129-thermal-cix-add-safe-ipa-support — DEFER
We kept the vendor IPA (0051/0052/0063/0064); srcshelton replaced it with an audited
model that "aggregate[s] one CPU power actor per CPPC policy, and fail[s] closed when
firmware telemetry or a restarted policy no longer satisfies the cached contract".
Thermal safety runtime work, not boot; needs validation against the MS-R1 thermal tables.

#### 14. 40056-soc-cix-add-safe-bus-performance-domain-driver — DEFER
New `cix-bus-perf.c` devfreq consumer for the CI-700 / multimedia fabric SCMI perf
domains (`cix-bus-perf` = 0 hits in our set). Runtime performance, not boot. Adopt only
if bus DVFS is wanted.

#### 15. 50130-spi-cadence-add-audited-cix-acpi-support — DEFER (hardware unknown)
`drivers/spi/spi-cadence.c` absent from our union and we have no `SPI_CADENCE` mention.
Relevant only if the MS-R1 firmware describes an in-use Cadence SPI controller.

#### 16. 20065-cacheinfo-share-global-firmware-ids-across-levels — DEFER
`drivers/acpi/pptt.c` absent. Fixes an "unpredictable value" when one CPU's L2 is shared
as another's L3 (heterogeneous Sky1). Scheduler/cache-topology correctness, not boot.

### Tier 3 — reject (covered, policy conflict, or wrong board/hardware)

- **80030 + 80000/80031/80032/80033/80035 (Realtek r8126) — REJECT.** srcshelton imports
  the RTL8126 *5 GbE* vendor driver, device table only
  `{ PCI_DEVICE(PCI_VENDOR_ID_REALTEK, 0x8126) }`. Base 7.2.9 already drives the MS-R1's
  10 GbE part in-tree: `r8169_main.c` has `{ PCI_VDEVICE(REALTEK, 0x8127) }`,
  `RTL_GIGA_MAC_VER_80 "RTL8127A"`, `FIRMWARE_8127A_1`, and `rtl8127a_1_hw_phy_config`.
  No `8126/8127/RTL812` string exists anywhere in our 85 patches, and none is needed.
- **7.2.x/0026 audited rts5453 — REJECT wholesale.** Different architecture:
  srcshelton keys on `fwnode_usb_role_switch_get()`/`fwnode_typec_switch_get()`/
  `fwnode_typec_mux_get()`; our driver is the vendor import + our ARA shared-IRQ design
  (0078/0088) with `i2c_new_smbus_alert_device()` group dispatch. The RTS5453 is a
  shared-alert controller and our ARA design is the more complete answer; srcshelton's
  per-client model would not gain us anything and would drop the ARA handling. Optional
  micro-cherry-pick: initialise the connector-search result before iteration.
- **7.2.x/0027 ACPI USB model arbitration — REJECT (policy conflict).** Our vendor 0027
  blocks `PNP0D10` so the vendor chain (`CIXH2030` cdnsp + `CIXH2031` cdns3) owns the
  controller; srcshelton does the opposite ("keeping PNP0D10, suppressing vendor USB
  model instead"). Our audited 0025 binds `CIXH2031`/`CIXH2030`, so adopting srcshelton's
  0027 would suppress exactly the devices our driver needs. Mutually exclusive design.
- **40070-soc-cix-arbitrate-acpi-pcie-models — REJECT (policy conflict).** Same split on
  PCIe: our 0030 (`pci-sky1-acpi.c`) blocks generic `PNP0A08` for CIXTEK/SKY1EDK2 so the
  vendor driver (0031/0032/0035/0039) owns it; 40070 registers an early scan handler to
  prefer generic and suppress the vendor companion. Adopt only as part of switching to
  generic PCIe — not a standalone fix.
- **40046-acpi-demote-cix-sky1-ecam-duplicate-reservations — REJECT/defer.** Log
  demotion only (`dev_info` → `dev_dbg` for duplicate `PCI ECAM` reservations); srcshelton
  itself marks it CIX-QUESTIONED-PATCH.
- **30127 / 30128 / 40052 / 90050 / 90060 — REJECT (Orion-board firmware).** Orion O6
  ECTZ/TZN zero-value filtering, O6 camera MCLK de-duplication, `_STR` labels and Radxa
  board profiles are board/firmware specific; the MS-R1 uses different ACPI tables.
- **70990–71160 (MVX VPU), 71500–71710 (ArmChina NPU), 72000–72030 (ArmCB ISP) — REJECT.**
  Drivers are entirely absent from our set (0/N coverage) because the MS-R1 does not load
  NPU/VPU/ISP. Revisit only if those blocks are enabled later.
- **80010/80015/80020 (rtw89/BT), 80025 (Cadence MACB) — REJECT.** No matching Wi-Fi/BT or
  in-use MACB on the MS-R1 hardware list; 80025 is Orion firmware matching.
- **50060 watchdog — REJECT (already covered).** srcshelton scopes the CIX refresh value
  through an ACPI match; our 0055 already does `- writel(0, ...) + writel(1, ...)`, which
  is the same effective fix for Sky1.
- **30196-opp-acpi-only, 10020, 10070, 20060, 30030, 30130, 90096, 90098, 20070,
  73050, 73060, 70130/70135/70140 cosmetics — REJECT/defer.** 30196 only
  fires when `CONFIG_OF=n` (never on this arm64 config); the rest are build-warning,
  log-level, diagnostic or generic-audit changes with no MS-R1 boot impact. 73050/73060
  are runtime audio error-path hardening; our audio set (0009/0013/0021/0022/0071/0089/
  0090) already covers the boot paths.
- **linux-6.18-*, 7.2.x/1009, 10000/10010/10050 —** not part of the 7.2.9 post-vendor
  series or already represented by our own 1007/1008/1009.

## Bottom line

Highest-priority adoptions, in order: **20050** (boot WARNING + freq invariance),
**40042** (ACPI named IRQ probe failures, verify DSDT), **90045** GPIO→PINCTRL_SKY1
dependency, **30195** (SCMI perf frequency accuracy + warning), **30090** (SCMI hwmon on
ACPI), then **70150** (completes the 64-plane conversion our own 00101 already assumes).
Conditional/deferred: **80070** (ASPM/SMMU — NVMe yes, 8127 not 8126), **90040** (fan, if
CIXHA024), selective **0024** cherry-picks, **70195**. The largest *apparent* gap —
Realtek networking — is a non-gap: 7.2.9 `r8169` already supports the MS-R1's RTL8127.
The 0026/0027/40070 divergences are deliberate, mutually exclusive design choices, not
missing functionality.
