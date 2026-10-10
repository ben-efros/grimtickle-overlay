# cix-sources 7.2.9 plan

Status: proposed, nothing implemented. Drafted 2026-10-10.
Revised 2026-10-10 after a full review of the patch set against the ncz-os 7.2 corpus
and mainline v7.2.9. Corrections to the first draft are marked **[corrected]**.

## Context

- gentoo-sources 7.2.9 exists upstream (verified in the Gentoo tree and
  `linux-7.2.9.tar.xz` on kernel.org). **The local tree is a stale snapshot** (max
  7.2.8); `emerge --sync`/webrsync is required before task A3 can use 7.2.9.
- Overlay has cix-sources 7.0.14 and 7.1.5 only. `files/7.1` has 98 entries:
  95 applied `*.patch` + 2 `*.patch.deferred` + 1 TODO.
- Vendor `cixtech/cix-linux-main` HEAD is `6d69935` — **[corrected]** author date
  2026-08-14, committer date 2026-08-26 (the first draft quoted the commit date).
  It has `patches-7.1` (86 files) and no `patches-7.2`.
- **[corrected]** Vendor `patches-7.1` is one revision behind its own `patches-7.0`:
  `6d69935` fixed a malformed SCMI `0003` **only** in `patches-7.0`. Both overlay
  copies of `0003` remain malformed. The same four refreshes (`0003`, `0012`,
  `0045`, `0048`) are also stale in `files/7.0`.
- **[corrected]** Baseline for "what changed": compare **v7.1.5 → v7.2.9**, not
  v7.1 → v7.2. The panthor register-header split was backported into stable 7.1.y,
  so the v7.1 baseline overstates panthor churn.
- **[corrected]** AUDSS clk/reset merged for **7.3**, not 7.2, and is DT-only —
  `drivers/clk/cix/` is 404 at v7.2.9, present on master. The overlay's
  `00050`-`00053` / `00060`-`00062` stay out-of-tree and required.
- Reference config: 16K pages, 48-bit VA, ARCH_CIX=y, gcc 16.1.1.

## Where each phase runs **[corrected: new section]**

The first draft mixed work that can run anywhere with work that needs the target.
This container is **x86_64** (Proxmox host `handbrake`, kernel `7.0.14-8-rebar1-pve`,
profile `default/linux/amd64/23.0/systemd`). It is **not** the CIX Sky1 ARM64 machine.
There is no `/tmp/config`, no `/root/rebuild-ramdisk.sh`, and no `/usr/src/*` here.

- **Phase A (patch/ebuild preparation)** — host-independent, runs anywhere.
- **Phase B (build, install, boot test)** — **must** run on the ARM64 target.

## Reference implementation: `srcshelton/gentoo-ebuilds` **[corrected: new section]**

A **sibling Gentoo overlay has already completed this forward-port**. It consumes the
same vendor base (`cixtech/cix-linux-main` `patches-7.1`, pinned at
`bc078a383042a6c14b05c56e12390e422f893088` — the vendor panthor-rework commit).

- `sys-kernel/cix-sources/cix-sources-7.2.9.ebuild` (931 lines; also 7.2.7, 7.2.8, 6.18.54/55)
- `files/7.2.x/` — 88 audited patches, replacing vendor ordinals by name
- `files/` top level — 54 `.patch` files (50 numbered `20050`…`90098`) plus ASL and Kconfig
  tooling; the ordered `post_vendor_patches` array holds 97 active entries drawn from both
  `files/` and `files/7.2.x/`
- `files/acpi-table-upgrade/` — 28 SSDT/DSDT/IORT ASL sources
- It answers task A4 directly: `K_WANT_GENPATCHES="base extras experimental"`,
  `K_GENPATCHES_VER="10"`, `K_NO_VERSION_CHECK=0`, `KEYWORDS="arm arm64"`.
- It uses a **fully custom `src_prepare()`** (a `cix_apply_patch()` case statement
  plus an ordered `post_vendor_patches` array), so it does **not** use this overlay's
  `${KV_MAJOR}.${KV_MINOR}` glob and is unaffected by the glob-order hazard below.

**This is not a drop-in.** Its policy is more conservative: it quarantines `.files/7.1/0033`
(regulator) as unsafe and skips vendor `0030/0031/0032/0035/0037/0039/0045/0046/0047/0049/0050/0051/0052/0053/0055/0057/0059/0063/0064/0066/0070`, replacing some with safer post-vendor
patches. Adopting it wholesale would remove capabilities this overlay currently ships.

Adoption cost, licensing and per-subsystem divergence are under investigation; the
outcome should be recorded here before A3 starts. **Evaluate before hand-authoring
`files/7.2`.**

## Task 0 (gate): rts5453 / IRQ routing — verdicts

The first draft's findings were partly wrong. Corrected verdicts:

| Claim | Verdict |
|---|---|
| `module_blacklist=typec_rts5453,rts5453` is inert | **CONFIRMED.** Mechanism is sound: `module_blacklist` only gates module loading, and the vendor defconfig itself sets `CONFIG_TYPEC_RTS5453=y` (`config-7.1.defconfig:2752`). Note: if it is ever flipped to `=m`, the blacklist line becomes live and would silently disable PD. |
| The reported boot wedge on "IRQ-151" | **UNVERIFIABLE.** Single-source (ncz `docs/ENGINEERING-EFFORT.md`); an earlier revision of that same document gives no IRQ number — the "151" was added later as recollection. No DSDT, boot log or tracker. On ARM64 GICv3+ACPI a Linux virq is a dynamic `irq_domain` mapping, so the number could be a virq, a GSI, or a DT GIC id. Treat the three candidate mechanisms (SMBus/alert semantics, shared-GpioInt/`IRQF_SHARED` fragility, PDC wake-mux) as labelled inference, not fact. |
| Two RTS5453 on one IRQ, each ACPI-described as **Exclusive** GpioInt, is the conflict | **[corrected] WRONG CAUSAL MODEL.** Linux does not enforce `Exclusive` on the GpioInt→IRQ path. `shareable` is read in exactly one place — `acpi_gpio_adr_space_handler()` (`gpiolib-acpi-core.c:1125`/v7.2 `:1155`), and only for an OperationRegion. Sharing is enforced **solely** by `IRQF_SHARED` (`kernel/irq/manage.c:1627`). The vendor driver's failure was requesting the IRQ *without* `IRQF_SHARED`, so the second chip got `-EBUSY` and the old code swallowed it. |
| The Sept-2026 USB3/USBSSP series fixed a missing fourth interrupt cell | **[corrected] CONFIRMED, not contradicted.** The CIX v3 cover letter (2026-09-03) states it verbatim: Sky1's GICv3 uses 4 cells, the fourth was missing, and `platform_get_irq_byname()` returned `-ENXIO`. Added in **v3**, retained in v4. The first draft was right that v4 has 4 cells and right that it is a **DT-path** fix irrelevant to ACPI boot — but wrong to call the claim contradicted, and its message-id `…470788-5` is v4 patch 4/4 (the series has no `-5`); the fix belongs to v3 `…2064986-6`. |
| `0078` is the fix for the wedge | **UNVERIFIED** — only a boot test settles it. |
| `0086` force-disables SuperSpeedPlus | **[corrected] NOT SUPPORTED BY THE DIFF.** Vendor `0025` defines `CFG_3XPORT_MODE_DIS_SSP (~(1 << 31))` and writes `v0 & CFG_3XPORT_MODE_DIS_SSP` to `XEC_CFG_3XPORT_MODE` (base+0x2040) — i.e. it clears **bit 31 only** and leaves every other bit. `0086` merely makes that branch unconditional (and it is a no-op entirely if firmware sets `u3-port-disable`, because of the `if/else if`). It cannot be shown to disable SSP; the commit message is unsupported. Obtain the register definition before shipping; consider making it opt-in. |

### New risk introduced by `0078`

`0078` **removes the last line-masking escape hatch**. The old driver did
`-ESHUTDOWN` → `disable_irq_nosync()`, which at least stopped a storm; the ARA design
has no equivalent, grouping means no single member can mask the line, and
`smbus_alert()` returns `IRQ_HANDLED` **unconditionally** — so the kernel's
"nobody cared" backstop cannot engage. If the ARA read NAKs while a chip holds the line
low, the result is a permanent IRQ storm.

The assumption needing hardware proof: reading ARA (`0x0C`) must **deassert** the chip's
alert output. Linux's `smbus_alert()` trusts this completely; the ChromeOS EC driver for
the same RTS54xx silicon additionally loops `while (any_irq_gpio_asserted())`, implying
it is not universally safe. If the board wires a generic INT rather than the
SMBALERT#/ARA-arbitrating output, the level-low `IRQF_ONESHOT` handler re-fires forever.
`0078`'s `irq_get_type() != IRQ_TYPE_LEVEL_LOW` warning checks a different, weaker property.

**Boot-test protocol:** keep `CONFIG_TYPEC_RTS5453=y`, do not blacklist. Watch for the ARA
client banner, `register partner` on both ports, absence of `irq N: nobody cared`, and
absence of a storm. If the wedge appears, retest without `0078`.

## Phase A — prepare (host-independent)

**A1. Sync `files/7.1` with vendor `patches-7.1` (6d69935).**
- Remove `0011` and `0038`; add `00111`-`00116` (the audited `00113` is byte-identical to
  the existing `0040`, so drop `0040` and keep `00113`).
- Refresh `0003`, `0012`, `0045`, `0048`, `0063` from the vendor — **`0063` must be taken
  from the vendor, not hand-rebased**, because it now consumes `scmi_perf_domain_freq_get()`
  added by `00115`.
- Pick up the transport-probe infinite-recursion fix.
- Apply the same four refreshes (`0003`, `0012`, `0045`, `0048`) to `files/7.0`.
- Note `00113` is a *rename of `0040`*: dropping `0040` without adding `00113` silently
  loses the `DPM_FLAG_NO_DIRECT_COMPLETE` STR fix.

**A2. Resolve the `0066` question and the `A1`/`A5` contradiction.**
Task 1 as first written says "sync with upstream", which objectively **adds `0066`**;
task 5 says leave `0066` out. As written these contradict — pick a sync-then-delete or
exclude-during-sync. (Static analysis suggests `0084`-vs-`0066` is probably *not* a hard
hunk conflict, contrary to the first draft, but `0066` is a ~98-file strategic fork that
deletes `cix-acpi-resource-lookup.c` and rewrites `drivers/soc/cix/Kconfig` wholesale, so
it should be excluded on policy grounds regardless.)

**A3. Create `files/7.2` and rebase to 7.2.9.**
- Build the dry-run base correctly: the patches apply **after** genpatches, so the base is
  **linux-7.2.9 + genpatches-7.2-10**, not vanilla `gentoo-sources`.
- **Verify with `-F0`.** Portage's `eapply` uses `patch -p1 -f -g0 --no-backup-if-mismatch`
  and **tolerates fuzz (default 2) with only a warning** (`/usr/lib/portage/python3.14/phase-helpers.sh`).
  A `--dry-run` that "succeeds" may have drifted context.
- Verified failures on 7.2.9 that must be rebased:

| Overlay patch | 7.2.9 failure | Fix |
|---|---|---|
| `0003` SCMI | **12/44 hunks fail** (macro pair `__of_match`/`__acpi_match`, `of_node_get/put` sites upstream deleted) | **Replace with ncz `0075`** (+ `0085`), which applies 0-failure. Do **not** hand-resolve: the obvious resolution loses a fwnode ref per child device (`device_set_node(&scmi_dev->dev, np)` vs `fwnode_handle_get(np)`). |
| `0011` panthor | fails (`panthor_device.c`, `panthor_gem.c`) | vendor `00111`/`00113`/`00116` apply clean; `00112`/`00114` **do not** (coherency init moved to `panthor_gpu.c`, `should_map_wc()` re-signed) |
| `0038` panthor suspend/resume | fails (depends on `0011`) | do not drop without a rebased `00112` |
| `0070` SMMU IRQ | **hunk 6/6 fails**; v7.2.6+ replaced `if (ret) goto err_disable;` with `{ arm_smmu_device_disable(smmu); return ret; }` | rebase the context only |
| `0008`, `0041` pmdomain | fail | **Reuse ncz `0077` + `0078` verbatim** — content-identical to the overlay's patches plus the `if (np)` guards for v7.2's `of_genpd_add_child_ids()` |

- **linlondp needs an authored fix-up, not a rebase.** Mainline 7.2 renamed
  `struct drm_atomic_state` → `struct drm_atomic_commit` treewide (**no alias**; v7.2.9
  `drm_atomic.h` has 0 vs 58 hits) and removed `drm_panel_init()` from the public header
  (1 hit at v7.1.5, 0 at v7.2.9). Measured rename surface in the overlay: **82 type
  occurrences across 12 files, plus 7 `drm_atomic_state_put` call sites**. Write a single
  `1010-linlondp-add-api-fix-up-to-v7.2.patch` carrying only: the rename +
  `drm_atomic_commit_put()`, `devm_drm_panel_alloc(...)` replacing the
  `devm_kzalloc` + `drm_panel_init` pair, and `-I $(src)` in the linlon-dp Makefile.
  Roughly 80% of ncz `0081` is already covered by the overlay's version-guarded
  `1003`/`1005`/`1007`/`1008` layers — **do not re-apply `0081` wholesale**.
- **Adopt ncz `0228` and drop `00101`'s core-DRM hunks.** `00101` patches core DRM plus four
  other drivers to widen plane masks `u32`→`u64` (cap 64); v7.2 still enforces 32 in
  `drm_plane.c` and still returns `u32` from `drm_plane_mask()`. Carrying a vendor patch
  that rewrites DRM core is a large upstream-drift liability for no benefit.

**A4. Create `cix-sources-7.2.9.ebuild` from 7.1.5.** **[corrected]**
- `K_GENPATCHES_VER="10"` (upstream gentoo-sources-7.2.9 uses 10; `genpatches-7.2-10.base`
  and `.extras` are confirmed available). This is `8` → `10` from 7.1.5.
- Decide explicitly whether to adopt `K_WANT_GENPATCHES="base extras experimental"`
  (upstream 7.2.9 does; 7.1.5 omits `experimental`, so the current base already differs
  from gentoo-sources at the same version).
- `KEYWORDS`: **`"arm arm64"` or `~arm64`**, not the inherited full-arch list. The sibling
  overlay uses `"arm arm64"` with `H_SUPPORTEDARCH="arm arm64"`; the overlay's own
  `cix-npu-driver`/`cix-vpu-driver` correctly use `~arm64`.
- **[corrected] Drop "fix HOMEPAGE"** — it is already correct in both existing ebuilds.
- Add the one-line `drivers/acpi/thermal.c` fix: `goto free_memory;` → `return result;`
  (7.2's devres conversion deleted the label). It is a single hunk inside ncz `0079`; extract
  that hunk, do not port `0079`.

**A5. External cross-package impact — not previously considered.**
The overlay's out-of-tree modules will be built against a 7.2 tree:
`sys-kernel/cix-npu-driver` (tag `p1_7.0_v6.2.0`) and `sys-kernel/cix-vpu-driver`
(tag `p1_v2.0.0`) both declare `MODULES_KERNEL_MIN="6.6"` and **no `MODULES_KERNEL_MAX`
anywhere in the overlay**. Add explicit bounds/revalidation, or Portage will attempt
7.0-era modules against 7.2 unguarded. Also port these verified fixes into the OOT sources:
- NPU: drop `IRQF_ONESHOT`; `dev_id = irq_obj`; NULL `pd_core` guard; force-D0.
- VPU: vb2 `q->lock`; deassert reset before `enable_irq`; `<linux/string.h>` + `strncpy`→`strscpy`;
  missing-firmware error propagation; workqueue drain order.

**A6. Regenerate the Manifest** (`ebuild ... manifest`) and run `pkgcheck scan`.

**A7. Decide the `gpu_clk_stacks` gap.** Neither the overlay nor the ncz corpus handles the
Sky1 shader-stack clock: `0087` fixes only `gpu_clk_core` and leaves
`devm_clk_get_optional(dev, "stacks")` untouched, while the DSDT registers
`gpu_clk_stacks` (vendor `00112` sets both). Reported symptom is `SHADER_PWRON` wedging in
`SHADER_PWRTRANS`. This is a gap in *both* corpora and needs an authored fix.

**A8. Audit the known live defects found during review.**
- `0011` deletes all three `gpu_info.selected_coherency` references and adds none, leaving
  the mainline UAPI field zero-initialised = `ACE_LITE` (0) while `NONE` is 31. Every
  non-coherent part therefore misreports as coherent. Any replacement must set it explicitly.
- `00100` calls `clk_put(pipe->pxlclk)` unconditionally at destroy time, but `pxlclk` is
  acquired by `devm_clk_get()` on the ACPI path — a double-free that faults in
  `hlist_del()` and kills the aggregate DRM device (no `/dev/dri`, console freeze).
  Only put the clock on the DT path (`of_clk_get_by_name`).

## Phase B — build and verify (on the ARM64 target)

**B1.** `make olddefconfig` against the reference config; review new/renamed symbols.
**B2.** Build, install via `kernel-install`, reboot. Keep the 7.1.5 UKI as fallback.
**B3.** Checks: `/dev/dri/renderD*` exists (panthor); `clk_get_rate()` non-zero for the GPU
clocks and no SError in `panthor_hw_init`; ARA client banner + no IRQ storm on the Type-C
ports; TC ports enumerate; NVMe present (a clockless apb/pclk path shows up as missing NVMe).
**B4.** If the SMMU event-queue storm is observed, evaluate the bypass-STE/ATS approach
(ncz `0100`, verified 7.2.9-clean) rather than disabling the event queue blindly.
**B5.** Validate the VA-API stack per the section above — by inspecting decoded frames, not
by exit status or dropped-frame counters.

## QA / mechanics notes **[corrected: new section]**

- **Apply order is lexical, not numeric.** The ebuild's `eapply "${FILESDIR}/7.1/"*.patch`
  sorts `00050`-`00062` and `00100`/`00101` **before** `0007`-`0009` and `0011`. No current
  patch breaks, but any 7.2 set that assumes numeric order is fragile.
- `sta_quirk.o` is added by both the overlay's `2004` and ncz `0061` — apply one, not both,
  or the object is added twice.
- ncz `0028` (regulator) and `0040` (RTC) must **not** be imported: `0028` carries a stale
  `regulator/core.c` hunk referencing an include removed in 7.2, and `0040` adds
  `#include <linux/of_gpio.h>`, which no longer exists (gone since 7.1); the overlay's
  `0033`/`0049` are already correct.
- `0028`/`0040`/`0013` etc. exist under different ordinals in the ncz corpus — ncz numbering
  does **not** correspond to this overlay's. Match by kernel file, never by number.
- ncz `0070` and `0073` mutually cancel on `sound/pci/hda/hda_cix_ipbloq.c`; any tooling that
  filters by file instead of replaying the ordered series will mis-reconstruct the tree.

## VA-API / hardware transcode (cross-package) **[added 2026-10-10]**

Jellyfin hardware transcode on Sky1 is real but **less mature than it looks**, and it is
**not part of `cix-sources`** — it is a userspace stack (VA-API driver + libva + ffmpeg)
sitting on a kernel VPU/V4L2 path. It is tracked here so it cannot be forgotten, but it must
not be dropped into `files/7.2` without first establishing which side of the boundary the
patches belong to.

Measured capability:

| Codec | Status |
|---|---|
| H.264 1080p decode (ffmpeg VA-API) | works |
| H.264 encode | works |
| HEVC encode | works |
| VP9 | works |
| AV1 decode | works via a **separate V4L2 path**, not VA-API |
| **HEVC decode** | **inconclusive / untested** — this matters, HEVC is the common 4K codec |

**Hard dependency — a gate, not an optimisation: six `cix-vaapi` patches are required.
Without them hardware decode does not work at all.**

**Provenance is unresolved and must be settled before this task is called done.**
A search for `vaapi` finds **nothing** in this overlay, in the ncz 7.2 corpus, or in the
srcshelton overlay. The only VA-API artefact located is ncz's `cix-vaapi_1.0.0.bb`, which
packages a **closed-source vendor `.deb`**:

```
LICENSE = "CLOSED"
LICENSE_FLAGS = "commercial_cix-mm"
SRC_URI = "file:///mnt/.../cix-mm-1.0.0.tar.gz"   # local SDK tarball, not public
```

and ncz's own multimedia README marks the whole slice **DEFERRED** ("No recipes shipped").
So:
- Locate the six patches, record their origin, and establish their licence.
- If they touch closed-source vendor binaries they must **not** go into this public
  repository. Keep them local, or gate them behind a USE flag / a separate local overlay,
  the way ncz gates its vendor stack behind `LICENSE_FLAGS_ACCEPTED`.
- Decide which side of the boundary each patch belongs to: **kernel-side** (V4L2 / `amvx`)
  patches belong in `files/7.2` and should be listed here; **userspace** patches belong in a
  `cix-vaapi` / ffmpeg package, not in `cix-sources`.

**Kernel-side dependency.** VA-API needs a working VPU kernel path — this overlay's
`sys-kernel/cix-vpu-driver` (out-of-tree `amvx`) plus V4L2 plumbing. The VPU is the least
settled part of the CIX stack: ncz shipped an **SError-masking workaround** (DAIF masking +
`ESB` around every VPU/RCSU MMIO access) rather than a root cause, and left a trail of
abandoned power/clock attempts. Budget for the VPU path on 7.2.9 and do not assume the
existing out-of-tree driver is sufficient.

**Validation must check output correctness, not just "it ran".** Every observed failure was
**silent** — including one that produced **flat green video at full framerate with zero
dropped frames**. Any pass/fail gate based on ffmpeg exit status, transcode completion, or
dropped-frame counters will report success on broken output. Verify per codec by decoding a
known clip and inspecting actual frames, on real 4K HEVC content.

## Optional / later

- ncz `0168` (re-map the CLKT bridge when the late SCMI "clocks" device binds) — the one real
  structural gap in the overlay's otherwise-identical bridge. Author says compile-verified
  only; needs a console boot test.
- ncz `0166`/`0158`/`0165`/`0095` — `-ENOENT`→`-EPROBE_DEFER` for the timer, PWM, i2c and
  PHY `pclk` lookups. Mechanical, low risk. (`0019`/`0045` are unaffected by the overlay's
  local PHY patches, which do not cover those paths.)
- ncz `0177` — skip absent optional pin groups instead of aborting the ACPI pin-group walk
  (a functional bug, not just console noise).
- ncz `0224` — `card-utils.c` correctness fixes (uninitialised `status` deref, leaked
  `kstrdup`, sysclk fallthrough). The ACPI device-link rewrite in it is larger and
  metal-gated; the overlay's ACPI DP-audio path hard-codes the topology and assumed
  HDMI-codec instance numbers, which ncz abandoned on real hardware.
- ncz `0110` (r8169 RTL8127A tally skip), `0183`/`0209` (SCMI perf OPP dedupe),
  `0218` (rtw89 ACPI _DSM preflight), `0213` (hwmon CIX fan), `0202` (platform named-IRQ
  resolution), `0200` (rpmsg ratelimit — the flood is caused by `0009`'s forced polling).
- SMMUv3 system-sleep support is **not** in 7.2.9 (`arm_smmu_suspend`/`resume` absent); a v11
  series is in review targeting 7.3, which would obsolete `0037`/`0070`.
- MS-R1 NPU: firmware DSDT lacks `_HID` on the NPU children; needs an ACPI SSDT override, not
  a kernel patch. A kernel-side `_STA` quirk (ncz `0122`+`0124`) is complementary, giving a
  probing-but-degraded NPU, not full per-core power management.
- Watch for upstream merges (AUDSS clk/reset, USB cdns3/PHY, ASoC cdns I2S, DMA350) so those
  patches can be dropped.

## Open questions

- Is `srcshelton/gentoo-ebuilds` `files/7.2.x/` to be adopted, adapted, or only used as a
  reference? (Investigation in progress.)
- What is bit 31 of `XEC_CFG_3XPORT_MODE` (0x2040)? Needed before `0086` can be trusted.
- Does MS-R1's DSDT actually omit the SCMI protocol children, or the QCOM/PHY reset names?
  This decides several "optional" patches and the NPU SSDT question.
- Does the reference config already set `CONFIG_TYPEC_RTS5453=y` and keep
  `CONFIG_USB_CDNS3_PCI_WRAP`/`USB_CDNSP_PCI` unset? (The wrapper's match table is
  `PCI_VDEVICE(CDNS, 0x0100)` and Sky1 root ports enumerate as `17cd:0100`; binding it
  NULL-derefs in `cdns3_pci_probe`.)
- **Where are the six `cix-vaapi` patches, what licence are they under, and are they
  kernel-side or userspace?** They are not in this overlay, the ncz 7.2 corpus, or the
  srcshelton overlay. This blocks the VA-API/transcode task and must be settled before it
  can be scheduled.
