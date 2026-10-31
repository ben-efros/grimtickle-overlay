# 09 — ms-r1-npu-hack evaluation

Repo: <https://github.com/FyrbyAdditive/ms-r1-npu-hack> @ `700619b`
("Initial commit: MS-R1 NPU fix", 2026-04-30).
Evaluated 2026-10-31 against `sys-kernel/cix-npu-driver` and the
reference MS-R1 board.

## What the hack contains

1. `npu-fix/ssdt/Ssdt-MsR1-NpuCoreHid.asl` (+ compiled `.aml`): an SSDT
   that adds `_HID = "CIXH4010"` and `_UID` to `\_SB.NPU0.CRE0/1/2`,
   intended to be loaded via an initramfs ACPI override.
2. `npu-fix/driver/msr1-npu-driver.patch` (~230 lines) against
   `cixtech/cix_opensource__npu_driver` branch `cix_mainline_dev`:
   v0 compat ioctls (`REQ_BUF_V0`, `FREE_BUF_V0`, `SCHEDULE_JOB_V0`),
   `struct aipu_cap.asid_base[4] -> [32]`, and forced 32-bit IOVA
   (`bus_dma_limit = 0xc0000000`, `dma_mask = 32`, V3 region size
   `0x3ffff000`).
3. Artifacts (`cix-npu-driver-dkms_6.1.1-2_all.deb`, `acpi-override.cpio`)
   and a userspace inference example.

The hack's own root-cause list is: missing `_HID` on NPU cores (ACPI),
missing kernel module, UMD/KMD ABI mismatch (old UMD layouts), and the
NPU's 32-bit address bus vs the 35-bit IOVAs the IOMMU hands out.

## Findings on the reference MS-R1

### F1 — The SSDT is not needed on this firmware

The board's BIOS is `1.0` dated **2026-04-29**. Disassembling the running
DSDT shows `\_SB.NPU0` (`CIXH4000`) with children:

```
Device (CRE0) { Name (_HID, "CIXH4010") Name (_UID, Zero) ... }
Device (CRE1) { Name (_HID, "CIXH4010") Name (_UID, One)  ... }
Device (CRE2) { Name (_HID, "CIXH4010") Name (_UID, 0x02) ... }
```

and the live kernel exposes `/sys/bus/platform/devices/CIXH4010:00/01/02`.
The hack's premise (cores only have `_ADR`, no `_HID`) matches an older
BIOS, not the current one. Loading the SSDT on this firmware would try to
define `_HID`/`_UID` names that already exist in the same scopes —
duplicate-name ACPI errors at best, and it is unnecessary.

**Decision:** do not ship or auto-load the SSDT. If an older-firmware
user needs it, keep it as an opt-in, documented artifact (initramfs
ACPI-override prepend) with a check for existing `CIXH4010` devices.
`cix-npu-driver` gets no automatic ACPI override.

### F2 — Our driver source is the hack's base, but not identical

`cixtech/cix_opensource__npu_driver` tag `p1_7.0_v6.2.0` (the version
pinned by `cix-npu-driver-6.2.0.ebuild`) vs current
`cix_mainline_dev`: the trees differ **only** by the `debian/` packaging
directory; all `driver/` sources are identical. Consequences for the
hack patch:

| Hack hunk | Applies to our 6.2.0 source? |
|---|---|
| `aipu.c` v0 compat ioctls | yes (with minor fuzz) |
| `armchina_aipu.h` `asid_base[4] -> [32]` | yes |
| `aipu_mm.c` forced V3 IOVA/32-bit DMA | **no** — our driver already restructured IOVA reservation (`use_v3_custom_iova`, `aipu_mm_reserved_iova_for_never_map`, runtime `V3_2` region sizing); the hack's context (`#if defined(CONFIG_ARCH_CIX)` + `iova_region_size` block) no longer exists |

So the hack is directly reusable for two of the three driver changes; the
IOVA change needs a forward-port, not a blind `patch -p1`.

### F3 — ABI/behaviour trade-offs not resolvable without userspace

* `asid_base[32]` changes the `AIPU_IOCTL_QUERY_CAP` payload size. The
  hack needs it for the published `cix-noe-umd` 2.0.2/2.0.4; a newer UMD
  that was built against `[4]` would see a different struct. Since the
  overlay does not package a UMD, we cannot pin which userspace is
  intended.
* The v0 compat ioctls are additive and safe, but only useful with an
  old UMD.
* The 32-bit IOVA limit is correct for the Zhouyi V3 in Sky1, but forcing
  it unconditionally could regress a future NPU with a wider bus. A
  forward-port should apply it to `AIPU_ISA_VERSION_ZHOUYI_V3` (and leave
  the existing runtime fallback in place).

Neither can be validated on this reference image: no `aipu.ko`, no
`/dev/aipu`, no `cix-noe-umd` library is installed, and the user directed
that the running 7.1.5 kernel not be used for NPU testing this round.

## Decision

**Not integrated in this round.** The code changes are small and the
source base is compatible, but the correct integration is a forward-port
with hardware/UMD validation, and doing it blind would risk changing the
NPU UAPI for other boards without a test. The concrete next-step
integration, when hardware/userspace is available, is:

1. Add `sys-kernel/cix-npu-driver/files/msr1/`:
   * `0100-armchina-npu-msr1-v0-abi-compat.patch` — `aipu.c` v0 ioctls +
     `asid_base[32]` (from the hack, re-authored with proper headers and
     `checkpatch`-clean style; the hack patch itself is not
     checkpatch-clean).
   * `0101-armchina-npu-msr1-v3-32bit-iova.patch` — forward-port of the
     `aipu_mm.c` change scoped to `ZHOUYI_V3`, preserving the existing
     runtime fallback.
2. Gate both behind an **opt-in USE flag** (`msr1-npu-quirks`, default
   off) in `cix-npu-driver-6.2.0`/`9999`, because the UAPI size change
   must match the installed UMD.
3. Compile the module against 7.3.1 (`/usr/src/linux-7.3.1-cix`) with
   `make W=1`; expected one pre-existing warning set only.
4. On a 7.3.1 image with `cix-noe-umd` installed: modprobe, check
   `NPU core num is 3` / `/dev/aipu`, then run `infer_minimal.py` with
   the ModelScope mobilenet_v2 graph. Only then enable the flag by
   default (if at all).
5. Do **not** ship the SSDT by default; provide it as a documented opt-in
   only for BIOS versions that lack `CIXH4010` (check
   `/sys/bus/acpi/devices/CIXH4010:*` before loading).

## Provenance

The hack repo is a third-party GPL-2.0/BSD-2-Clause-Patent work (driver
patch and SSDT source respectively). If adopted, record it in
`NOTICE.md` with the hack repository URL and the upstream driver
repository, preserving the hack author's attribution. The `.aml`/`.deb`
artifacts must not be redistributed from the overlay; rebuild them from
source.
