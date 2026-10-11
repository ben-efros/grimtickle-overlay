# Third-party patch provenance

This file records the source of patches in this package that were adopted from
other projects during the 7.2.9 forward-port. All are GPL-2.0 kernel-derivative
works; each patch file retains (or now carries) a `Source:` header naming its
origin. Authorship is preserved as found; where an upstream file had no in-file
author, that is stated explicitly.

## ncz-os / meta-cix (Jason Perlow <jperlow@gmail.com>)

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

## srcshelton / gentoo-ebuilds

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

## Why these replaced the originals

- `0003` (SCMI ACPI) failed 12 of 44 hunks on 7.2.9; ncz's version is a clean
  forward-port that also documents and preserves the fwnode reference-counting
  that a naive hand-rebase loses.
- `0008`/`0041` (pmdomain) failed on 7.2.9; ncz's versions add the `if (np)`
  guards around 7.2's `of_genpd_add_child_ids()`/`of_genpd_remove_child_ids()`.
- `0011`/`0038`/`0040`/`0087` (panthor) were superseded by the vendor
  `00111`-`00116` rework; the srcshelton version is the working 7.2.9 form and
  additionally fixes the `gpu_clk_stacks` lookup and the `selected_coherency`
  UAPI regression.
