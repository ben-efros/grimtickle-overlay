# Third-party patch provenance

This file records the source of patches in this package that were adopted from
other projects. All are GPL-2.0 kernel-derivative works; each patch file
retains (or now carries) a `Source:` header naming its origin. Authorship is
preserved as found; where an upstream file had no in-file author, that is
stated explicitly.

This overlay carries two parallel forward-ports of the vendor CIX kernel:
`cix-sources-7.2.9` (`files/7.2`) and `cix-sources-7.3.1` (`files/7.3`). The
7.3.1 local/adopted patch set (`0163`-`0176`) is itself a rebase of most of
the 7.2.9 round's local/adopted content onto the 7.3.1 CIX-native USB/PHY
hardening work (`0150`-`0162`); see "## cix-sources-7.3.1 (files/7.3)" below
for the mapping and for what was intentionally not carried forward.

## cix-sources-7.2.9 (files/7.2)

### ncz-os / meta-cix (Jason Perlow <jperlow@gmail.com>)

Yocto BSP layer for the "nclawzero" distro on CIX Sky1 / Minisforum MS-R1.
Canonical repository: <https://gitlab.com/ncz-os/meta-cix>.

| Overlay patch | Source |
|---|---|
| `0003-firmware-arm_scmi-add-acpi-support-to-SCMI.patch` | `linux-cix-sky1-ncz-7.2/patches-7.2/0075-firmware-arm_scmi-add-acpi-support-to-SCMI-NCZ-0003-.patch` |
| `0003-mailbox-fix-acpi-driver-data-type-confusion.patch` | `…/patches-7.2/0085-firmware-arm_scmi-mailbox-fix-acpi-driver-data-type-confusion.patch` |
| `0008-pmdomain-add-acpi-support-to-cix-soc.patch` | `…/patches-7.2/0077-pmdomain-add-acpi-support-to-cix-soc-NCZ-0008-forwar.patch` |
| `0041-pmdomain-fix-dev_pm_domain_attach_by_name-for-sky1-m.patch` | `…/patches-7.2/0078-pmdomain-fix-dev_pm_domain_attach_by_name-for-sky1-m.patch` |
| `0092-drm-panthor-sky1-power-on-via-raw-smc-scmi.patch` | `…/patches-7.2/0186-drm-panthor-sky1-power-on-GPU-via-raw-SMC-SCMI-before-first-MMIO.patch` |
| `0093-regulator-cix-fix-stale-prot-limit-found.patch` | `…/patches-7.2/0181-regulator-cix-handle-unsupported-pmic-constraints-quietly.patch` |
| `0098-iommu-smmu-v3-sky1-pcie-bypass-ste.patch` | `…/patches-7.2/0100-iommu-smmu-v3-sky1-pcie-bypass-ste-ats-override.patch` |
| `0099-net-r8169-skip-hw-tally-rtl8127-sky1.patch` | `…/patches-7.2/0110-net-r8169-skip-hw-tally-rtl8127-sky1.patch` |
| `0100-pci-cix-force-clock-pm-off-sky1-endpoints.patch` | `…/patches-7.2/0109-pci-cix-force-clock-pm-off-sky1-endpoints.patch` |
| `0101-clocksource-sky1-defer-on-missing-timer-clocks.patch` | `…/patches-7.2/0166-clocksource-sky1-defer-on-missing-timer-clocks.patch` |
| `0104-clk-cix-remap-clkt-bridge-on-scmi-clocks-bind.patch` | adapted from `…/patches-7.2/0168-clk-cix-sky1-remap-clkt-bridge-on-scmi-clocks-bind.patch` (simplified: no mapped_list dedup) |

### srcshelton / gentoo-ebuilds

A sibling Gentoo overlay. Repository: <https://github.com/srcshelton/gentoo-ebuilds>.

| Overlay patch | Source |
|---|---|
| `0011-drm-panthor-add-sky1-acpi-support.patch` | `sys-kernel/cix-sources/files/7.2.x/0011-drm-panthor-add-sky1-acpi-support.patch` |
| `0025-usb-cdns3-add-audited-sky1-platform-support.patch` | `sys-kernel/cix-sources/files/7.2.x/0025-usb-cdns3-add-audited-sky1-platform-support.patch` |
| `0089-usb-cdns3-sky1-declare-phy-dependency.patch` | `sys-kernel/cix-sources/files/7.2.x/60010-usb-cdns3-sky1-declare-phy-dependency.patch` |
| `0094-topology-has-missing-cpufreq-ref.patch` | `files/20050-topology-has-missing-cpufreq-ref.patch` |
| `0095-platform-acpi-resolve-named-irq-resources.patch` | `files/7.2.x/40042-platform-acpi-resolve-named-irq-resources.patch` |
| `0096-scmi-hwmon-no-of-thermal-zones-on-acpi.patch` | `files/30090-scmi-hwmon-do-not-use-of-thermal-zones-on-acpi.patch` |
| `0097-scmi-perf-rational-frequency-conversion.patch` | `files/30195-firmware-arm-scmi-use-rational-perf-frequency-conversion.patch` |

The panthor patch's upstream file carries **no in-file author, `Source:`, or
`Signed-off-by`**; the overlay it came from pins the vendor base
(`cixtech/cix-linux-main`, commit `bc078a383042a6c14b05c56e12390e422f893088`)
and consumes its `patches-7.1`. That pinned commit is the preferred-form source
of the underlying vendor work.

### Why these replaced the originals

- `0003` (SCMI ACPI) failed 12 of 44 hunks on 7.2.9; ncz's version is a clean
  forward-port that also documents and preserves the fwnode reference-counting
  that a naive hand-rebase loses.
- `0008`/`0041` (pmdomain) failed on 7.2.9; ncz's versions add the `if (np)`
  guards around 7.2's `of_genpd_add_child_ids()`/`of_genpd_remove_child_ids()`.
- `0011`/`0038`/`0040`/`0087` (panthor) were superseded by the vendor
  `00111`-`00116` rework; the srcshelton version is the working 7.2.9 form and
  additionally fixes the `gpu_clk_stacks` lookup and the `selected_coherency`
  UAPI regression.

## cix-sources-7.3.1 (files/7.3)

### ncz-os / meta-cix (Jason Perlow <jperlow@gmail.com>)

Yocto BSP layer for the "nclawzero" distro on CIX Sky1 / Minisforum MS-R1.
Canonical repository: <https://gitlab.com/ncz-os/meta-cix>.

| Overlay patch (7.3) | 7.2.9 patch | Source |
|---|---|---|
| `0165-regulator-cix-fix-stale-prot-limit-found.patch` | `0093` | `linux-cix-sky1-ncz-7.2/patches-7.2/0181-regulator-cix-handle-unsupported-pmic-constraints-quietly.patch` |
| `0170-iommu-smmu-v3-sky1-pcie-bypass-ste.patch` | `0098` | `…/patches-7.2/0100-iommu-smmu-v3-sky1-pcie-bypass-ste-ats-override.patch` |
| `0171-net-r8169-skip-hw-tally-rtl8127-sky1.patch` | `0099` | `…/patches-7.2/0110-net-r8169-skip-hw-tally-rtl8127-sky1.patch` |
| `0172-pci-cix-force-clock-pm-off-sky1-endpoints.patch` | `0100` | `…/patches-7.2/0109-pci-cix-force-clock-pm-off-sky1-endpoints.patch` |
| `0173-clocksource-sky1-defer-on-missing-timer-clocks.patch` | `0101` | `…/patches-7.2/0166-clocksource-sky1-defer-on-missing-timer-clocks.patch` |
| `0175-clk-cix-remap-clkt-bridge-on-scmi-clocks-bind.patch` | `0104` | adapted from `…/patches-7.2/0168-clk-cix-sky1-remap-clkt-bridge-on-scmi-clocks-bind.patch` (simplified: no mapped_list dedup); hunk 1 context regenerated for the 7.3 baseline's extra `#include <dt-bindings/clock/cix,sky1.h>` line |

### srcshelton / gentoo-ebuilds

A sibling Gentoo overlay. Repository: <https://github.com/srcshelton/gentoo-ebuilds>.

| Overlay patch (7.3) | 7.2.9 patch | Source |
|---|---|---|
| `0166-topology-has-missing-cpufreq-ref.patch` | `0094` | `files/20050-topology-has-missing-cpufreq-ref.patch` |
| `0167-platform-acpi-resolve-named-irq-resources.patch` | `0095` | `files/7.2.x/40042-platform-acpi-resolve-named-irq-resources.patch` |
| `0168-scmi-hwmon-no-of-thermal-zones-on-acpi.patch` | `0096` | `files/30090-scmi-hwmon-do-not-use-of-thermal-zones-on-acpi.patch` |
| `0169-scmi-perf-rational-frequency-conversion.patch` | `0097` | `files/30195-firmware-arm-scmi-use-rational-perf-frequency-conversion.patch` |

### Not carried forward from the 7.2.9 lineage

These 7.2.9-era local/adopted patches are intentionally **not** present in
`files/7.3`:

- `0089` (`usb-cdns3-sky1-declare-phy-dependency`, srcshelton): specific to the
  7.2.9 round's temporary `cdns3-plat.c`/`cdns3-sky1.c` mainline-cdns3-based
  USB host workaround. CIX's final `patches-7.3` restored the native
  split-driver `cdnsp-plat.c`/`cdnsp-sky1.c` model that `0150`-`0162` already
  target; this patch does not apply to that model and is unneeded.
- `0090` (rts5453/phy ACPI dependency restoration, meant to offset content
  that 7.2.9 had to drop): fully redundant here — `0160`
  (`soc-cix-add-cix-sky1-usb-kconfig-umbrella.patch`) already contains the
  equivalent `select I2C_SMBUS` / `depends on USB_ROLE_SWITCH` / `depends on
  ACPI || OF` wiring.
- `0092` (`drm-panthor-sky1-power-on-via-raw-smc-scmi`, ncz-os): superseded —
  CIX's own vendor `patches-7.3` (`00111`-`00116`) already natively implements
  `sky1_gpu_power_on()`/`sky1_hw_power_on()`/`sky1_resets_init()` in
  `panthor_sky1.c`/`.h`, fully wired into `panthor_device.c`.
- `0105` (drm display-stack atomic-API port): superseded — CIX's vendor 7.3
  patches already port the display stack to the modern atomic API; applying
  this against the 7.3 baseline reports nearly every hunk already applied.

### Why these replaced the originals (7.2.9 context, retained for history)

- `0003` (SCMI ACPI) failed 12 of 44 hunks on 7.2.9; ncz's version is a clean
  forward-port that also documents and preserves the fwnode reference-counting
  that a naive hand-rebase loses. (Not applicable to `files/7.3`: CIX's vendor
  `patches-7.3` already ships SCMI ACPI support natively.)
- `0008`/`0041` (pmdomain) failed on 7.2.9; ncz's versions add the `if (np)`
  guards around 7.2's `of_genpd_add_child_ids()`/`of_genpd_remove_child_ids()`.
  (Not applicable to `files/7.3` for the same reason.)
- `0011`/`0038`/`0040`/`0087` (panthor) were superseded by the vendor
  `00111`-`00116` rework; see `0092` above — the vendor 7.3 patches are now the
  working form directly, so none of the 7.2.9 panthor patches were carried
  forward.

## cix-sources-7.3.1-r1 — local review patches (0177-0184)

These patches are not from a third-party patch set; they are local
fixes written for this overlay after the 7.3.1 PCIe/Sky1 review
(`audit/06-7.3.1-pci-sky1-review.md`). Each is GPL-2.0, matching the
kernel.

| Overlay patch | Origin |
|---|---|
| `0177-pci-sky1-cix-fix-aer-root-command-write-address.patch` | local |
| `0178-pci-sky1-cix-guard-ep-lookup-against-missing-bus.patch` | local |
| `0179-pci-sky1-cix-check-each-aer-irq-request.patch` | local |
| `0180-pci-sky1-cix-unlock-on-pwren-timeout.patch` | local |
| `0181-pci-sky1-cix-propagate-clk-lookup-failures.patch` | local |
| `0182-gpio-cadence-mask-irq-writes-to-implemented-width.patch` | adapted from Armbian `patch/kernel/archive/cix-6.18/2001-gpio-gpio-cadence-fix-crashing-pcie-on-cix-p1-acpi-s.patch` (CIX original author: Jianfeng Liu); width-masking half only |
| `0183-arm64-dts-cix-fix-sky1-pcie-x2-rcsu-addresses.patch` | adapted from Armbian `patch/kernel/archive/uefi-arm64-dt-7.3/1001-sky1-pcie-x2-fix.patch` |
| `0184-pci-sky1-acpi-name-pdev-after-vendor-driver.patch` | local |

The Armbian-derived patches are GPL-2.0 (kernel); see
`audit/08-armbian-patch-evaluation.md` for the evaluation and the
rationale for taking only the noted halves.
