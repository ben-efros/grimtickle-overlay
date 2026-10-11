# 04 — Compile/link risk audit of patch-changed files

Tree: `/root/grimtickle-overlay/.patchwork/base` (Linux 7.2.9 + genpatches + 85 glob-applied patches).
Scope: the 270 files listed by `grep '^+++ b/' .../7.2/*.patch`.
Method: read changed files, then resolve every external reference (function call, struct/enum
tag, member access, `#include`, Kconfig/Makefile symbol) against this tree only. Version-gated
blocks (`#if LINUX_VERSION_CODE < KERNEL_VERSION(a,b,c)`) were evaluated for 7.2.9
(`LINUX_VERSION_CODE = 7*65536+2*256+9`); `#ifdef CONFIG_*` branches were evaluated against the
Kconfig symbol set. Toolchain in this environment is GCC 16, where implicit function
declarations and incompatible pointer types are hard errors (they are also link errors/constraint
violations on older GCC for the cases below).

Known-fixed items confirmed gone (not re-reported): `drivers/acpi/thermal.c` has no
`free_memory` label/goto (0 matches); `alc269_fixups[]` braces balance (checked by brace match
over the array body).

---

## CERTAIN

### 1. `struct drm_atomic_state` was renamed to `struct drm_atomic_commit`; the CIX display driver still uses the old type

- Affected files:
  - `drivers/gpu/drm/cix/linlon-dp/linlondp_kms.c`
  - `drivers/gpu/drm/cix/linlon-dp/linlondp_kms.h`
  - `drivers/gpu/drm/cix/linlon-dp/linlondp_crtc.c`
  - `drivers/gpu/drm/cix/linlon-dp/linlondp_plane.c`
  - `drivers/gpu/drm/cix/linlon-dp/linlondp_pipeline.h`
  - `drivers/gpu/drm/cix/linlon-dp/linlondp_pipeline_state.c`
  - `drivers/gpu/drm/cix/linlon-dp/linlondp_pm.c`
  - `drivers/gpu/drm/cix/dptx/trilin_dptx.h`, `trilin_drm.c`, `trilin_drm_mst.c`
- Missing/incorrect symbols (representative, not exhaustive):
  - `drm_atomic_state_put` — called at `linlondp_kms.c:483, 517, 561, 571` and
    `linlondp_pm.c:200`. No declaration/definition anywhere in the tree.
  - `state->dev` / `old_state->dev` / `state->acquire_ctx` — dereference of the incomplete type
    `struct drm_atomic_state` at `linlondp_kms.c:300, 327, 504, 507`.
  - Incompatible pointer conversions, e.g. `linlondp_kms.c:394`
    (`struct drm_atomic_state *state = crtc_st->state;`), `trilin_drm_mst.c:625, 649, 784`,
    and the callback assignments at `linlondp_kms.c:347`
    (`.atomic_commit_tail = linlondp_kms_commit_tail`), `trilin_drm.c:588, 1295, 1296`.
- Evidence:
  - 7.2 defines `struct drm_atomic_commit` at `include/drm/drm_atomic.h:480`, and the refcount
    helper is `drm_atomic_commit_put()` at `include/drm/drm_atomic.h:708`.
  - No definition of `struct drm_atomic_state` exists: `grep -rn 'struct drm_atomic_state[^_]'`
    matches only the CIX files (63 hits), and the tag is only forward-declared at
    `drivers/gpu/drm/cix/linlon-dp/linlondp_pipeline.h:557`.
  - `grep -rn 'drm_atomic_state_put' .` matches only the 5 call sites above; no declaration,
    no macro, no `#define` alias.
  - DRM vtables now take the new type (`include/drm/drm_modeset_helper_vtables.h:1533`
    `void (*atomic_commit_tail)(struct drm_atomic_commit *state);`), so the CIX callback
    signatures are incompatible.
- Confidence: **CERTAIN** (incomplete-type dereference + undeclared call → compile/link error).

### 2. `drm_panel_init()` is gone from the public DRM panel API

- File:line: `drivers/gpu/drm/cix/dptx/cix_edp_panel.c:693`
  ```c
  drm_panel_init(&panel->base, dev, &cix_edp_panel_funcs, DRM_MODE_CONNECTOR_eDP);
  ```
- Missing symbol: `drm_panel_init`.
- Evidence:
  - `grep -rn '\bdrm_panel_init\b'` over the whole tree returns only:
    `drivers/gpu/drm/drm_panel.c:49` (doc comment), `:59`
    (`static void drm_panel_init(...)`), `:451` (internal call), and this call site.
    The symbol is file-static and there is no declaration in any header.
  - `include/drm/drm_panel.h` has no `drm_panel_init`; the 7.2 allocation/init API is
    `__devm_drm_panel_alloc()` (`include/drm/drm_panel.h:297`) with macro
    `devm_drm_panel_alloc()` (`:318`).
- Confidence: **CERTAIN** (implicit function declaration; would also be an undefined reference).

### 3. Kconfig selects a symbol that is defined nowhere

- File:line: `drivers/gpu/drm/cix/dptx/Kconfig:9`
  ```
  select DRM_DP_AUX_CHARDEV
  ```
- Missing symbol: `DRM_DP_AUX_CHARDEV`.
- Evidence: `grep -rn 'DRM_DP_AUX' --include='Kconfig*' .` returns only this select line. The
  real 7.2 symbol is `DRM_DISPLAY_DP_AUX_CHARDEV`, defined at
  `drivers/gpu/drm/display/Kconfig:35` (guards `drm_dp_aux_dev.o` in
  `drivers/gpu/drm/display/Makefile:28`).
- Impact: Kconfig warning ("select of undefined symbol"); the intended aux-chardev object is not
  built. No code in `drivers/gpu/drm/cix/dptx/` calls `drm_dp_aux_dev_*`, so this is a Kconfig
  defect rather than a link failure by itself.
- Confidence: **CERTAIN** (symbol resolution).

---

## UNSURE (config-guard anomalies; no hard build failure as written)

### 4. CIX RTC suspend hooks are behind an undefined CONFIG symbol

- Files:lines:
  - `drivers/rtc/rtc-rx8900.c:54` — `#include <linux/soc/cix/cix_suspend.h>` inside
    `#ifdef CONFIG_SOC_CIX`
  - `drivers/rtc/rtc-rx8900.c:270` — `suspend_warning_set(...)`
  - `drivers/rtc/rtc-rx8900.c:976` — `suspend_warning_clear()`
- Evidence: `CONFIG_SOC_CIX` is defined by no Kconfig (`grep -rn 'config SOC_CIX'` → nothing;
  only unrelated `SND_SOC_CIX` exists). The header does not exist either:
  `include/linux/soc/cix/` contains only `cix-acpi-resource-lookup.h`, and tree-wide grep for
  `suspend_warning_set|suspend_warning_clear|SUSPEND_WARN_TYPE_ABORTED` matches only these
  RTC lines.
- Why not CERTAIN: include and both calls are all inside `#ifdef CONFIG_SOC_CIX`, so the branch
  is never compiled in this tree (dead code). It becomes a hard failure only if that config is
  ever defined (or the guard removed) — then the missing header and undeclared helpers fail.
  `RTC_DRV_RX8900` is a `bool` with no `depends on`, so it is user-selectable.
- Confidence: **UNSURE** for compile impact; the absent config/header/symbols are CERTAIN.

### 5. `trilin_dptx.c` uses an undefined CONFIG guard

- File:line: `drivers/gpu/drm/cix/dptx/trilin_dptx.c:3607` — `#ifdef CONFIG_ARCH_CIX_EMU_FPGA`.
- Evidence: `ARCH_CIX_EMU_FPGA` is defined by no Kconfig. Dead branch; no build failure.
- Confidence: **UNSURE** for compile impact.

---

## Checked and cleared (no hard failure found)

- **Missing headers**: every quoted `#include` in the changed files resolves via the relevant
  Makefile `-I` (e.g. `sound/hda/controllers/Makefile:7`, `drivers/gpu/drm/cix/linlon-dp/Makefile`,
  `drivers/gpu/drm/amd/amdgpu/Makefile:39`). The only missing header is the dead
  `cix_suspend.h` above.
- **Version-gated 7.1-era APIs** were *not* reported because the 7.2 branch is taken and is
  correct: `from_timer` (`linlondp_crtc.c:285`, guarded `< 6.16`, else `timer_container_of`),
  `.lastclose`/`drm_fb_helper_lastclose` (`linlondp_kms.c:283`, guarded `< 6.12`),
  `register_syscore_ops`/`unregister_syscore_ops` (`pci-sky1-cix.c:2387/2587`, guarded
  `< 6.19`, else `register_syscore`), `drm_dp_remove_payload` (`trilin_drm_mst.c:677`, guarded
  `< 6.7`), `drm_fbdev_generic_setup`/`drm_fbdev_ttm_setup` (`linlondp_drv.c`,
  `linlondp_cluster.c`, guarded `< 6.13`).
- **Macro/token-paste false positives** verified as resolvable:
  `scmi_base_register` … `scmi_pinctrl_unregister` (generated by
  `DEFINE_SCMI_...`/`DECLARE_SCMI_REGISTER_UNREGISTER` in
  `drivers/firmware/arm_scmi/protocols.h:368-394`); `panthor_{gpu,job,mmu}_irq_*` and
  `panthor_request_*_irq` (generated in `panthor_device.h:587-639`); `GCAP`
  (`AZX_REG_ ## reg` via `include/sound/hdaudio.h:492`); panthor `PANTHOR_EXCEPTION(...)`
  token pasting.
- **Struct/enum tags**: no other renamed tag found. `struct panthor_csf`,
  `panthor_csf_ctx`, `panthor_perfcnt` are only forward-declared and never used;
  `radix_tree_root`/`raw_spinlock`/`ww_acquire_ctx` are macro-generated aliases.
- **Struct members**: a tree-wide member check over all changed `.c`/`.h` files found no
  member absent from its type's definition.
- **Arity**: curated signature comparison for 70+ evolving APIs (`thermal_zone_device_register*`,
  `devfreq_cooling_*`, `dev_pm_opp_*`, `devm_pm_domain_attach_list`, `fwnode_property_*`,
  `pci_host_*`, `cdns_pcie_*`, `snd_soc_*`, `arm_smmu_*`, `em_dev_*`, …) found no arity mismatch.
- **Duplicates/files**: no file is created by more than one patch; no duplicate global function
  definitions across changed files; no duplicate `EXPORT_SYMBOL`.
- **Kconfig/Makefile**: no `obj-$(CONFIG_X)` in a changed Makefile refers to an undefined
  symbol; the only undefined Kconfig reference is finding 3.
