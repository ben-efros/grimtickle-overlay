# 7.2.9 patch-set divergences — for review

This records every change made to `files/7.1/` while getting the series to apply to
Linux 7.2.9, plus what is still outstanding and the decisions that are yours to make.
Nothing here changes kernel behaviour except where stated.

## How the series was verified

Not by inspection — by applying the real thing.

```sh
# base == linux 7.2.9
curl -O https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.2.tar.xz
tar xJf linux-7.2.tar.xz                       # linux 7.2.0
# genpatches carry the stable point releases; 1008_linux-7.2.9.patch lands 7.2.9
curl -O https://distfiles.gentoo.org/pub/proj/kernel/genpatches/genpatches-7.2-10.base.tar.xz
curl -O https://distfiles.gentoo.org/pub/proj/kernel/genpatches/genpatches-7.2-10.extras.tar.xz
tar xJf genpatches-7.2-10.base.tar.xz; tar xJf genpatches-7.2-10.extras.tar.xz
for p in $(ls *.patch | sort); do patch -p1 -s < "$p"; done   # -> SUBLEVEL = 9
# then the overlay series, in the ebuild's glob order, strict context
for p in $(ls sys-kernel/cix-sources/files/7.1/*.patch | sort); do
    patch -p1 -F0 --no-backup-if-mismatch -s < "$p"
done
```

`-F0` is deliberate: the ebuild's `eapply` tolerates fuzz 2 and only *warns*, so a patch
can "succeed" with drifted context. Anything that needed fuzz was rebased until it applied
at `-F0`.

**Result:** 81/95 clean before this work, **82/82 clean now** (the 11-patch CIX USB host
chain is deferred, below). The deferred USB work is entangled with the 7.2 cdns3
unification and needs the USB architecture restructure, not a Kconfig patch.

Rebased patches were produced by applying at fuzz, then regenerating with `git diff`
against the committed pre-state, then re-verifying at `-F0`. That preserves the patch's
original intent exactly; it does not invent new behaviour.

## 1. Removed as obsoleted

| Patch | Why | Evidence |
|---|---|---|
| `0029-usb-cdns3-fix-spin-lock-issue-in-suspend-resume.patch` | 7.2's cdns3 unification moved runtime PM into the shared core path. The functions it patches no longer exist. | 7.2.9 `drivers/usb/cdns3/cdnsp-pci.c` contains only `cdnsp_get_second_fun`, `cdnsp_pci_probe`, `cdnsp_pci_remove` — **no** `cdnsp_pci_suspend()`/`cdnsp_pci_resume()` and no `cdns_resume()` call |
| `drm_atomic.c` hunk of `00101-drm-linlondp-merge-updates-from-26q2.patch` | Could not apply, and its effect was nullified by `1009` anyway | see below |
| `drm_atomic.c` hunk of `1009-linlondp-fix-WERROR.patch` | Existed only to undo the hunk above | see below |

**The `00101`/`1009` pair, in detail.** 7.2 refactored
`drm_atomic_crtc_print_state()` from `drm_printf(p, "\t…")` to
`drm_printf_indent(p, 1, "…")`, so the vendor hunks' context is gone. `00101` changed
`plane_mask=%x` → `%llx`; `1009` changed it back to `%x`. Net effect on the built tree was
always `%x`, so dropping **both** hunks is behaviour-preserving and removes a pointless
conflict.

> **Open decision.** Widening `plane_mask` to genuinely support >32 planes is a separate,
> larger change: `struct drm_crtc_state.plane_mask` and `drm_plane_mask()` were never
> widened by these patches, so `00101`'s consumer-side `u32`→`u64` edits do not actually
> achieve it. `srcshelton 7.2.x/70150` supplies the real 3-file change
> (`u64 plane_mask` in `drm_crtc.h`, `u64 drm_plane_mask()` in `drm_plane.h`, `%llx` in
> `drm_atomic.c`). Adopting it means also dropping `00101`'s remaining core-DRM hunks,
> which rewrite `drm_atomic.c`, `drm_atomic_helper.c`, `drm_plane.c`,
> `drm_framebuffer.c`, `drm_mode_config.c`, malidp, komeda, ipuv3 and an amdgpu trace
> header. **Not taken here** — it is a policy decision about carrying vendor rewrites of
> DRM core.

## 2. Rebased onto 7.2.9 (context drift only)

Each was applied at fuzz, regenerated with `git diff`, and re-verified at `-F0`.
No semantic change was made to any of them.

| Patch | Failing file | What drifted |
|---|---|---|
| `0012-irqchip-add-cix-sky1-pdc-driver.patch` | `drivers/irqchip/Makefile` | new entries above the insertion point |
| `0013-DPTSW-26459-sound-hda-rework-cix-ipbloq-based-on-mai.patch` | `sound/hda/codecs/realtek/alc269.c` | quirk-table churn |
| `0033-regulator-add-acpi-support.patch` | `drivers/regulator/core.c` | unrelated upstream rework in a disjoint region |
| `0054-usb-cdns3-fix-TypeC-hotplug-enumerati-on-failure.patch` | `drivers/usb/cdns3/core.c` | 7.2 cdns3 unification |
| `0070-DPTSW-26437-iommu-arm-smmu-v3-fix-IRQ-setup-on-resum.patch` | `drivers/iommu/arm/arm-smmu-v3/arm-smmu-v3.c` | v7.2.6+ replaced `if (ret) goto err_disable;` with `if (ret) { arm_smmu_device_disable(smmu); return ret; }` — the exact drift predicted in the plan |
| `0071-DPTSW-26459-ALSA-hda-realtek-suppress-auto-mic-on-CI.patch` | `sound/hda/codecs/realtek/alc269.c` | same region as `0013` |

Note `0013` and `0071` both touch `alc269.c` and both had to be rebased; `0013` is applied
first (glob order) and `0071` stacks on it. Verified in that order.

## 3. `0088` — new patch, regenerated

`0088-usb-typec-rts5453-ack-shared-irq-when-ara-silent.patch` was authored from the live
MS-R1 diagnosis, then found **malformed** by the harness (four hunks had wrong line
counts, and it did not apply at all). It was rebuilt by editing the post-0078 tree with
verified anchors and emitting the patch with `git diff`, and now applies at `-F0`.

Still **NOT BUILT, NOT BOOT-TESTED**. See `PLAN-7.2.9.md` for the measured evidence and
the test plan.

## 4. Adopted (third-party replacements, with attribution)

Three of the original failures were resolved by adopting the verified third-party
replacements. Provenance is in `NOTICE.md`, and each adopted patch carries a `Source:`
header; where the upstream file had a `From:`/`Subject:` preamble it was preserved verbatim.

| Was | Now | Source |
|---|---|---|
| `0003` SCMI (12/44) | `0003-firmware-arm_scmi-add-acpi-support-to-SCMI.patch` | ncz `0075` (forward-port; documents and preserves the fwnode reference-counting a naive rebase loses) |
| — | `0003-mailbox-fix-acpi-driver-data-type-confusion.patch` | ncz `0085` |
| `0008` pmdomain (2/4) | `0008-pmdomain-add-acpi-support-to-cix-soc.patch` | ncz `0077` |
| `0041` pmdomain | `0041-pmdomain-fix-dev_pm_domain_attach_by_name-for-sky1-m.patch` | ncz `0078` |
| `0011` panthor (+`0038`/`0040`/`0087`) | `0011-drm-panthor-add-sky1-acpi-support.patch` | srcshelton `7.2.x/0011` |

Removed: `0038`, `0040`, `0087` — subsumed by the adopted panthor patch, which also fixes
`gpu_clk_stacks` and the `selected_coherency` UAPI regression found live on MS-R1.

> **Panthor caveat — needs an on-device test.** The adopted `0011` changes the GPU power-on
> path (ACPI `PowerResource` instead of the raw SMC SCMI) and makes coherency `_CCA`-driven
> instead of forced ACE-Lite. It applies cleanly, but GPU bring-up must be re-verified on
> MS-R1 before this is called done.

## 5. Deferred — the whole CIX USB host chain (11 patches)

The vendor USB host support is one atomic unit, not two patches. `0025` **creates** the
vendor split driver (`cdnsp-plat.c`/`cdnsp-sky1.c`) and its Kconfig/Makefile, and nine more
patches modify those files or stack on changes they make. Deferring only `0025` made those
nine fail (their target files no longer exist), so the entire chain is deferred to keep the
tree buildable.

Deferred as `.deferred` (same convention as `0083` and the xhci-plat patch):
`0025`, `0054`, `0061`, `0062`, `0065`, `0068`, `0075`, `0077`, `0081`, `0084`, `0086`.

**Consequence for the boot test:** the kernel builds and brings up GPU + Type-C PD (rts5453,
including `0088`), but the CIX USB *data* host driver is absent — only mainline cdns3
(`cdns3-plat.c`) remains. Build-time note: keep `CONFIG_I2C_SMBUS=y` and
`CONFIG_TYPEC_RTS5453=y` in the config (they are set on the live box); `0084` normally
selects `I2C_SMBUS`, but it is deferred.

| Patch | Role in the chain |
|---|---|
| `0025` | creates the vendor `cdnsp-plat.c`/`cdnsp-sky1.c` + Kconfig/Makefile |
| `0054`, `0061`, `0062`, `0065`, `0068`, `0075`, `0077`, `0081`, `0086` | patch those files / stack on their changes |
| `0084` | Kconfig umbrella; its `cdns3/Kconfig` hunks target `USB_CDNSP_SKY1` |

**Open decision (unchanged):** the correct fix is the 7.2-native restructure
(`srcshelton 7.2.x/0025` + `0027` + `60010`, re-targeting the deferred patches), not a
Kconfig-only patch — the vendor split predates 7.2's cdns3 unification and even references
`USB_CDNSP_GADGET`, which 7.2 does not define.

## 6. Reproducing this

The harness lives in `.patchwork/` (gitignored, ~2 GB) and is rebuilt by the commands at
the top of this document. Two helpers were used:

- `reset.sh` — `git reset --hard` to the committed base plus `git clean -fd`
- `test-patches.sh <dir> [fuzz]` — reset, then apply the series in glob order, reporting
  failures and fuzz

A useful gotcha the harness caught: `git checkout <sha>` refuses on a dirty tree, so a
reset helper must use `reset --hard`, not `checkout`.
