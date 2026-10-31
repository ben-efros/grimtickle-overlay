# 07 — Decisions for cix-sources-7.3.1-r1 (PCIe/Sky1 review round)

Recorded 2026-10-31. This is the decision log for the work whose findings
are in `06-7.3.1-pci-sky1-review.md`, `08-armbian-patch-evaluation.md`
and `09-msr1-npu-hack-evaluation.md`. It is intentionally explicit about
what was changed, what was deliberately not changed, and why.

## Context

`files/7.3/` had been assembled by a previous round (vendor resync +
local hardening, `0150`-`0176`) and verified only by patch application.
This round added:

1. a hardware/source review of the PCIe driver and the Sky1 ACPI
   plumbing,
2. a fresh 7.3.1 build and boot on the reference MS-R1,
3. evaluation of the Armbian CIX patch sets,
4. evaluation of `FyrbyAdditive/ms-r1-npu-hack`.

Baseline for verification: `linux-7.3.tar.xz` + `genpatches-7.3-2`
(base+extras) + all 113 `files/7.3/*.patch`, applied in shell-glob order
exactly as the ebuild does.

## Decisions

### D1 — Fix the four unambiguous PCIe code defects; keep each as its own patch

Added to `files/7.3/`:

| Patch | Reason |
|---|---|
| `0177-pci-sky1-cix-fix-aer-root-command-write-address.patch` | AER Root Command re-enable wrote to the PCIe-capability base instead of the AER extended-capability base; one AER event permanently disabled Root AER. |
| `0178-pci-sky1-cix-guard-ep-lookup-against-missing-bus.patch` | NULL `bridge->bus`/`root_bus` dereference reachable from PME/AER work when the link is down. |
| `0179-pci-sky1-cix-check-each-aer-irq-request.patch` | Only the third of three AER IRQ request results was checked. |
| `0180-pci-sky1-cix-unlock-on-pwren-timeout.patch` | `sky1_init_mutex` was held across a `-ETIMEDOUT` return, deadlocking later controllers. |

Rationale for separate patches: each is independently reviewable and
revertible, matches the existing one-topic-per-patch style of the local
series, and none of them changes intended behaviour on a healthy system
(they only affect error/interrupt paths).

### D2 — Fix the clock-error propagation in the ACPI/DT clock lookup

`0181-pci-sky1-cix-propagate-clk-lookup-failures.patch` makes required
clock lookup failures fail probe with the real errno instead of storing
`ERR_PTR()` in `struct sky1_pcie`. The optional `refclk_b` `-ENOENT` case
is preserved as `NULL`.

Alternative considered: only log and keep the old fall-through. Rejected
because every later `clk_prepare_enable()`/`clk_disable_unprepare()`
would still receive an error pointer; failing early is strictly safer.

### D3 — Fix the vendor/mainline driver name collision by renaming the synthetic device

`0184-pci-sky1-acpi-name-pdev-after-vendor-driver.patch` renames the
platform device from `sky1-pcie` to `sky1-pcie-cix`.

Reasons: Linux 7.3 ships the mainline `pci-sky1.c` driver with driver name
`sky1-pcie` and `PROBE_PREFER_ASYNCHRONOUS`; `platform_match()`'s
last-resort name comparison can bind the ACPI-created device to it. On
the test boot the vendor driver won, but only because the mainline async
probe lost the race. Renaming removes the ordering dependency entirely
and keeps the ACPI-HID match intact. Alternatives considered:

* change the vendor driver name back to `sky1-pcie` — rejected, `0032`
  renamed it deliberately to distinguish the two drivers;
* add a `driver_override` — more code, and would prevent the ACPI match
  fallback;
* leave it (boot worked) — rejected, the failure mode is a
  timing-dependent wrong-driver bind/confusing probe failure.

### D4 — Adopt the Armbian gpio IRQ-width fix, reject its preserve-firmware change

`0182-gpio-cadence-mask-irq-writes-to-implemented-width.patch` is
adopted from Armbian `cix-6.18/2001` (CIX original author Jianfeng Liu),
width-masking half only. The `preserve_firmware_config` half is **not**
adopted; full reasoning in `08-armbian-patch-evaluation.md` §3. Short
version: different driver base (`0017` has no quirk plumbing), Armbian
does not carry it on their nearest (7.1) branch, the MS-R1's PCIe works
with the current probe, and preserving firmware bypass/direction has a
real risk of leaving pins muxed away from GPIO consumers.

### D5 — Adopt Armbian's Sky1 DT PCIe x2 address fix

`0183-arm64-dts-cix-fix-sky1-pcie-x2-rcsu-addresses.patch` adopts
Armbian `uefi-arm64-dt-7.3/1001`. It is a two-line fix to an obvious
extra-hex-digit typo; ACPI boot is unaffected, DT boot is corrected.
Armbian `1002` (gpio DT quirk) is rejected because it conflicts with the
ACPI `gpio-cadence` rewrite; neither the MS-R1 nor the overlay's kernel
build enables the DT Sky1 path.

### D6 — Do not touch the CIX vendor patches themselves

All fixes are new trailing local patches (`0177`+). Editing `00xx`
vendor files in place would break the provenance/`NOTICE.md` model and
make the next vendor resync harder. This matches the established
`0150`-`0176` convention.

### D7 — No changes to shared Cadence code

`0032` modifies shared `pcie-cadence-*` files. The review found the
additions are namespaced/additive and the `of_property_*` →
`device_property_*` change is compatible with OF users, so no corrective
patch was warranted; it is recorded as an upstream-scrutiny item, not a
local fix.

### D8 — Armbian: no patch series merge

Armbian's newest CIX/ACPI series is 7.1 (ours is 7.3); its 7.3 work is
mainline-DT (`uefi-arm64-dt`) and not applicable to the MS-R1 ACPI
kernel. Only the two `uefi-arm64-dt-7.3` patches and the gpio-width fix
were evaluated as transferable; see `08-armbian-patch-evaluation.md`.

### D9 — NPU hack: evaluate, adapt direction recorded, not integrated this round

`09-msr1-npu-hack-evaluation.md` records the analysis. Key decisions:

* The hack's ACPI SSDT is **superseded on the reference board**: BIOS 1.0
  dated 2026-04-29 already exposes `_HID = "CIXH4010"` on
  `\_SB.NPU0.CRE0/1/2` (verified by disassembling the running DSDT), and
  the kernel creates `CIXH4010:00/01/02`. Loading the hack's
  `_HID`-adding SSDT on this firmware would attempt to define duplicate
  names in the same scope. It is only meaningful for older firmware; if
  shipped at all it must be opt-in and firmware-version gated.
* The hack's driver patch is against
  `cixtech/cix_opensource__npu_driver` branch `cix_mainline_dev`; our
  `cix-npu-driver-6.2.0` tarball (`p1_7.0_v6.2.0`) is byte-identical to
  that branch except for the `debian/` directory, so the `aipu.c` v0-ABI
  hunks apply, but the `aipu_mm.c` hunk does not (the newer driver
  restructured IOVA reservation and already has a V3 custom-IOVA path).
  It needs a forward-port, not a blind apply.
* At the user's direction the 7.1.5 kernel is not used for NPU testing
  this round (no userspace UMD is installed anyway), so no NPU package
  change was made. Next steps are in doc 09: forward-port the three
  changes, compile against 7.3.1, gate behind a USE flag, and only then
  test inference on a 7.3.1/UMD setup.

### D10 — Verification method: real boot is authoritative

The 7.2.9 round verified "applies cleanly" only; this round added a
native aarch64 build and a boot of the resulting 7.3.1 kernel on the
reference MS-R1, with the previous 7.1.5 kernel/UKI kept as the fallback
boot entry. Results are in §Verification below.

## Verification

* Patch chain: on top of the previous 113-patch `files/7.3` state, the
  eight new `0177`-`0184` patches apply with zero fuzz/rejects; the
  combined chain was independently applied to a pristine
  `linux-7.3` + `genpatches-7.3-2` tree in shell-glob order (the same
  order the ebuild uses).
* Build: native aarch64 GCC 16.2 on the MS-R1 (12 cores), tree under
  `/tmp`, reference 7.1.5 config as the base after `make olddefconfig`,
  `CONFIG_LOCALVERSION="-cix-review"`, `DEBUG_INFO` disabled and module
  compression off for the test build only. The patched
  `pci-sky1-cix.o`, `pci-sky1-acpi.o` and `gpio-cadence.o` compile
  without new warnings/errors.
* Boot: the resulting `7.3.1-cix-review` UKI was installed alongside the
  existing 7.1.5/7.2.9 entries and selected with a **one-shot** boot
  entry (`bootctl set-oneshot`), so a failed boot falls back to the
  previous default on the next reset. Evidence collected after boot is
  summarised below; full logs are quoted where they matter in doc 06.

## Rejected alternatives (summary)

| Alternative | Why rejected |
|---|---|
| Edit `0030`-`0039` in place | Breaks vendor provenance and resync; new trailing patches are the established convention. |
| Carry the whole Armbian `cix-7.1`/`cix-6.18` series | Older vendor baseline; would regress the 7.3 APIs the vendor set already ports. |
| Adopt `preserve_firmware_config` | Needs per-board pin audit/boot evidence; conflicts with the `0017` design; Armbian does not carry it on 7.1. |
| Blind-apply ms-r1-npu-hack patch | `aipu_mm.c` changed upstream; SSDT duplicates `_HID` on current BIOS; no UMD/hardware test available. |
| Patch every low-risk finding (P9/P10/S2/S3/S4) | Untestable behaviour changes or DT-only paths not built on MS-R1; documented instead. |
