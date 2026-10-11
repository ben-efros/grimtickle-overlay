# 7.2.9 forward-port — audit reports

Read-only audits of the assembled 7.2.9 patch set (`files/7.2/`) against the
vendor lineage and the sibling ncz-os / srcshelton patch sets, plus a
compile-risk and a boot-risk review of the applied tree. Run 2026-10-10; each
report is a snapshot and its findings drove the fixes in the commit history.

| # | Report | Scope |
|---|---|---|
| 01 | vendor-coverage | files/7.1 -> files/7.2: 0 dropped, 16 replaced, gap analysis |
| 02 | ncz-coverage | vs ncz-os meta-cix patches-7.2 (229 files) |
| 03 | srcshelton-coverage | vs srcshelton/gentoo-ebuilds (88 + 54 patches) |
| 04 | compile-risk | symbol/API existence in the applied tree |
| 05 | boot-risk | 0088 / panthor 0011 / USB 0025 runtime hazards |

These are analysis notes, not a substitute for building and booting. Internal
paths reference the (gitignored) `.ncz-review/` and `.patchwork/` scratch trees
that are not part of the repository.

## Corrections found while acting on these reports

- **90045 (GPIO_CADENCE `depends on !ARCH_CIX || PINCTRL_SKY1`) — REJECTED.**
  The live MS-R1 runs `CONFIG_GPIO_CADENCE=y` with `PINCTRL_SKY1` **not set**,
  and `cdns-gpio 7` (the Cadence GPIO) provides the IRQ line for the RTS5453
  Type-C PD controller. Adding the dependency would disable the working GPIO
  and break Type-C PD. It is an Orion-O6-vs-MS-R1 board difference, not a gap.

## Known remaining issues (evaluated, deliberately left unpatched)

- **USB 0025 `cdnsp_sky1_hw_init()` (audit #6):** runs in probe (cold boot) and
  resume — both correct. The "resets an already-active controller" concern is a
  firmware-handoff / warm-reboot edge case; the audit's "vendor 0086" citation
  actually refers to the (unrelated) SuperSpeedPlus patch. Low risk.
- **USB 0025 `platform_data` (audit #8):** latent UAF — cdns3-plat.c stores
  `cdns->pdata = dev_get_platdata()` (a pointer into the wrapper's devm `data`)
  and dereferences it at runtime; `cdnsp_sky1_clear_acpi_pdata()` nulls the
  device field but not the child's stored copy. Triggers only on wrapper unload
  while the child stays bound. Fix direction: copy the needed fields in
  cdns3-plat.c instead of holding the pointer, or unbind the child on removal.
