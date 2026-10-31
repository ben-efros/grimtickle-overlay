# 08 — Armbian patch evaluation for cix-sources-7.3.1-r1

Evaluated: 2026-10-31, against
`https://github.com/armbian/build` @ `f982a43` ("bsp: hibernation: keep
the page cache out of the image", 2026-10-30).

Question: does Armbian carry CIX Sky1 / MS-R1 patches that
`sys-kernel/cix-sources-7.3.1-r1` should adopt, and are there Armbian
fixes for the kernel we ship?

## 1. What Armbian actually supports

| Armbian family | Kernel branch | Patch dir | Boot model |
|---|---|---|---|
| `cix-p1` (`config/sources/families/cix-p1.conf`) | `current` = 6.18, `edge` = 7.1 | `patch/kernel/archive/cix-6.18/`, `cix-7.1/` | CIX vendor kernel, **ACPI** |
| `uefi-arm64-dt` | `edge` = 7.3 (mainline) | `patch/kernel/archive/uefi-arm64-dt-7.3/` | generic UEFI + **DT** (stubble), Sky1 DTB `cix/sky1-orion-o6.dtb` |

So Armbian's newest *CIX vendor/ACPI* patch set is **7.1**; its 7.3
support is a mainline-DT Orion O6 path, not a 7.3 CIX/ACPI kernel. The
MS-R1 image described by the NPU hack is `cix-p1`/6.18 (kernel
`6.18.25-current-arm64`). There is therefore **no Armbian 7.3 CIX ACPI
series to diff against**; the useful comparison is:

* Armbian `cix-7.1` vs our `files/7.3` vendor baseline (older baseline;
  finds backports we may have missed), and
* Armbian `cix-6.18` (contains the newest CIX gpio-cadence PCIe fix),
* Armbian `uefi-arm64-dt-7.3` (two Sky1 DT patches that apply to our base
  tree).

## 2. Patch-by-patch disposition

### 2.1 `uefi-arm64-dt-7.3` (applies to our 7.3.1 base)

| Armbian patch | Disposition | Evidence / reasoning |
|---|---|---|
| `1001-sky1-pcie-x2-fix.patch` — fix `pcie_x2_rc` `rcsu_strap`/`rcsu_status` `reg` addresses (`0x0a0600340` → `0x0a060340`, `0x0a0600440` → `0x0a060440`) | **ADOPTED** as `0183-arm64-dts-cix-fix-sky1-pcie-x2-rcsu-addresses.patch` | The typo exists verbatim in our base `arch/arm64/boot/dts/cix/sky1.dtsi:664`; DT-only, does not affect the MS-R1 ACPI boot, but is plainly wrong and the fix is a two-line register-address correction. |
| `1002-pci-sky1-gpio.patch` — add `cix,sky1-gpio` compatible + a `skip_init` quirk to the *mainline* `gpio-cadence` driver | **REJECTED** (not applicable) | This targets the unmodified mainline driver for DT boot. Our `0017-gpio-add-acpi-support-to-cadence-driver.patch` rewrites `gpio-cadence.c` and removes the `cdns_gpio_quirks`/`skip_init` mechanism entirely (it uses `device_get_match_data()` only as a Sky1-PDC boolean). The two designs conflict; re-introducing `skip_init` would mean re-porting the whole vendor ACPI rewrite. The MS-R1 boots ACPI, where `0017` is the active path. |
| `0001`/`0002` (qcom SFA14 DTS + SCM allowlist) | REJECTED (unrelated hardware) | Not CIX. |

### 2.2 `cix-6.18` (Armbian's 6.18 CIX ACPI series)

| Armbian patch | Disposition | Evidence / reasoning |
|---|---|---|
| `2001-gpio-gpio-cadence-fix-crashing-pcie-on-cix-p1-acpi-s.patch` — (a) mask IRQ register writes to `ngpio`, (b) add `preserve_firmware_config` and skip direction/output/bypass programming on ACPI Sky1 | **PARTIALLY ADOPTED** as `0182-gpio-cadence-mask-irq-writes-to-implemented-width.patch` | (a) is an unambiguous width bug also present in our `0017` (live MS-R1 has 10- and 17-GPIO banks); adopted. (b) is **not** adopted — see §3. |
| `2002-drm-linlon-dp-remove-existing-drivers-that-may-own-t.patch` | REJECTED (already superseded) | Our 7.3 vendor display series (`00100`, `00101`, `00102`, `1001`-`1008`) already handles the mainline driver ownership/replacement problem for 7.3; the Armbian patch targets the 6.18 tree's older DRM layout. Nothing in it applies cleanly to our tree, and the MS-R1 display path is covered by the vendor patches. |
| `0005`/`0006`/`0010`/`0011`/`0013`/`0022` (old split names: clk, reset, linlon-dp, panthor ACPI, HDA, ASoC) | REJECTED (superseded by 7.3 vendor baseline) | Our 7.3 set carries the newer CIX versions: `00052`/`00053`/`00054` + `00061`/`00062` (clock/reset), `00100`-`00102` + `1001`-`1008` (display), `00111`-`00116` (panthor), `0013` (HDA), `00220`-`00222` (ASoC). Armbian's are the same work at an older revision. |
| `0001`-`0004`, `0007`-`0009`, `0012`, `0014`-`0021`, `0023`-`0028`, `2003`, `2004` | NOT UNIQUE | Same CIX patches as ours modulo 6.18 vs 7.3 context (`0001`-`0004` ACPI/SCMI, `0007` resource lookup, `0008` pmdomain, `0012` PDC, `0017` gpio ACPI, `0024`-`0027` USB/PHY, `2003`/`2004` firmware back-compat). No content in them is absent from our 7.3 baseline; we did not merge the 6.18 variants because forward-porting the 7.3 vendor versions is the supported direction. |

### 2.3 `cix-7.1` (Armbian's older CIX ACPI series, 86 patches)

This is essentially the same vendor lineage we already forward-ported to
7.3. `comm` of file names shows only these are Armbian-only:

| Armbian-only file | Disposition | Reasoning |
|---|---|---|
| `00050`/`00051`/`00060` (audss CRU bindings + clocks + auxiliary resets) | SUPERSEDED | Our `00052`-`00054`, `00061`-`00062` are the 7.3 CIX versions of the same audss clock/reset work. |
| `0022-sound-soc-add-cix-soc-support.patch` | SUPERSEDED | Our `00220`/`00221`/`00222` are the 7.3 revisions (plus DP-audio fix). |
| `0066-add-cix_dst-driver.patch` | DELIBERATELY NOT CARRIED (already our policy) | Unused by the reference config and never part of our `files/7.1` either; the 7.3 port keeps it excluded. |
| `1009-linlondp-fix-WERROR.patch` | SUPERSEDED | Every hunk is present in the 7.3 vendor display baseline (verified during the 7.3 resync); `00102` covers the one differing `plane_mask` format. |

The remaining 80 same-named files differ only by the 7.1-vs-7.3 vendor
rebase; no Armbian-only fix was found in them that our 7.3 baseline
lacks.

### 2.4 Armbian configuration observations

From `config/sources/families/cix-p1.conf` and
`config/kernel/linux-cix-p1-{current,edge}.config`:

* `CONFIG_PCI_SKY1_HOST=y`, `CONFIG_PCI_SKY1_HOST_CIX=y`,
  `CONFIG_GPIO_CADENCE=y`, `CONFIG_PINCTRL_SKY1=y` (edge; current has
  `GPIO_CADENCE` but not `PINCTRL_SKY1`) — matches our finding that
  `GPIO_CADENCE` must not be gated on `PINCTRL_SKY1`
  (see `audit/README.md` "Corrections").
* Kernel cmdline: `efi=noruntime clk_ignore_unused nowatchdog
  watchdog_dev.handle_boot_enabled=0`. The `clk_ignore_unused` is
  consistent with our `0175-clk-cix-remap-clkt-bridge-on-scmi-clocks-bind`
  workaround and the CLKT-bridge ordering issue.
* `MODULES_BLACKLIST="armchina_npu aipu"` — Armbian currently blacklists
  the NPU module on this family (same root cause as the
  ms-r1-npu-hack); it installs NPU/VPU DKMS from the `EvilOlaf` forks.
  This does not change our decision to keep NPU/VPU out-of-tree.
* Armbian's `cix-6.18`/`cix-7.1` configs do **not** list
  `CONFIG_CIX_ACPI_RESOURCE_LOOKUP`; it defaults to `y` via
  `default ARCH_CIX`. Our MS-R1 config explicitly sets it `=y`; that is
  the safer, explicit form.

## 3. Why `preserve_firmware_config` was not adopted

The Armbian `2001` patch also stops `gpio-cadence` from programming
direction/output-enable/bypass on ACPI Sky1, to preserve firmware pin
state that controls PCIe slot power/PERST#. Reasons for not taking it:

1. **Different driver branch.** `2001` is based on the CIX 6.18
   `gpio-cadence` ACPI patch, whose probe still honours a
   `skip_init`-style quirk set. Our `0017` is a different rewrite that
   deliberately programs the bank at probe and has no quirk plumbing;
   adopting only half of `2001` would leave a partial state.
2. **Armbian does not carry it on their own closest branch.** `2001`
   exists only in `cix-6.18`; Armbian's `cix-7.1` set — the one nearest
   our 7.3 ACPI kernel — keeps the same non-preserving probe as our
   `0017`.
3. **The MS-R1 is known-good with the current behaviour.** During the
   7.3.1 test boot the PCIe reset/power GPIOs were still requested and
   driven by `pci-sky1-cix` (`gpioinfo` shows `reset` lines, PCIe
   endpoints enumerate); the current non-preserving probe did not break
   PCIe on this board.
4. **Behavioural risk is asymmetric.** Preserving firmware `bypass`/
   direction can leave a pin muxed to a peripheral when a consumer later
   requests it as GPIO. That needs a per-board pin audit and a boot on
   an affected board; it is not a mechanical correctness fix like the
   width masking.

Decision: keep the width fix, drop the preserve change; revisit if a
board is found where the current probe actually disturbs PCIe (the
Armbian patch is the reference implementation for that case).

## 4. Conclusion

Armbian's 7.3 work is DT/mainline, not CIX/ACPI, so only the two
`uefi-arm64-dt-7.3` patches apply to the 7.3.1 base. One is a clear DT
address bug (adopted), the other conflicts with our ACPI gpio rewrite
(rejected). The one genuinely transferable ACPI fix — the gpio IRQ-width
masking from `cix-6.18/2001` — has been adopted; the behavioural half of
that patch was evaluated and deliberately deferred.
