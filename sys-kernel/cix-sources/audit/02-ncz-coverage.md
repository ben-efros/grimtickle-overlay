# 02 — ncz `meta-cix` 7.2 coverage audit vs our `files/7.2`

Auditor: coverage subagent (read-only; only this report written).
Date: 2026-10-10.
Our tree: `sys-kernel/cix-sources/files/7.2/` — 85 patches (87 entries incl. 2 `.deferred`
and 1 `.txt`), applied by `cix-sources-7.2.9.ebuild` via `eapply "${FILESDIR}/7.2/"*.patch`
(shell glob order, **not** numeric — see §7).
Sibling: `ncz-os/meta-cix` `linux-cix-sky1-ncz-7.2/patches-7.2/` — 229 files on disk,
205 wired in `recipe_7.2.bb` / `ordered.txt`.

## Method / evidence base

1. **Our side**: grep of every distinctive token (function names, ACPI HIDs, DT compatibles,
   config symbols, comments) across `files/7.2/*.patch`. Absence of a token across the whole
   set is the primary "we lack this" signal; presence is quoted wherever an equivalent exists.
2. **Pristine kernel ground truth**: `.patchwork/base` is the harness *working* tree with the
   series applied; its pristine commit is `6d14c66` ("linux-7.2 + genpatches-7.2-10 = 7.2.9").
   API facts below are read from `git -C .patchwork/base show 6d14c66:<path>`.
3. **ncz side**: every patch body in `patches-7.2/`, plus the bucket reports already produced
   under `.ncz-review/agents/{core,scmi,clock,display,gpu,usb,thermal-iommu-pcie,audio-pinctrl-dma,npuvpu}/`.
   Those reports were written against **`files/7.1`**; this audit re-verified every
   candidate gap against **`files/7.2`** and against `6d14c66`, and drops the ones the 7.2
   port already resolved (notably **USB 0112** and **0187-route**, see §5).
4. `DIVERGENCES-7.2.md` records what the 7.2 port intentionally replaced (srcshelton 7.2-native
   USB `0025`, panthor `0011`, SCMI `0075`/`0085`, pmdomain `0077`/`0078`).

Verdict codes used in the appendix: **COVERED** (equivalent functionality present),
**PARTIAL** (subset present, listed gaps remain), **GAP** (functionality absent),
**CONFLICT** (ncz offers a competing design we deliberately did not take),
**NA** (ncz-only tree/unapplied/diagnostic or superseded), **OOT** (fix belongs in our
out-of-tree `cix-npu-driver`/`cix-vpu-driver` packages, not `cix-sources`), **DIAG**.

Summary of 229 on-disk patches: **72 COVERED, 71 GAP, 41 NA, 14 CONFLICT, 12 OOT,
8 PARTIAL, 7 DIAG**. The large GAP count is dominated by low-tier hardening/cosmetic items;
the ranked list below is what matters.

---

## TIER 0 — build blocker (fix before any image)

### 1. ncz **0081** — v7.2 DRM API drift not fully carried (`drm_atomic_state`, `drm_panel_init`)
- **What it fixes**: treewide `struct drm_atomic_state` → `struct drm_atomic_commit`
  (7.2 rename), and `devm_kzalloc`+`drm_panel_init()` → `devm_drm_panel_alloc()` for the
  eDP panel (7.2 made panels refcounted/kref+devm-allocated).
- **Device**: MS-R1 DP/eDP path — entire `drivers/gpu/drm/cix/{linlon-dp,dptx}` stack
  (`CONFIG_DRM_CIX`). Our `00100`/`00101` add the driver.
- **Visible at BOOT?** Worse — visible at **compile/link**: no kernel is produced.
- **Evidence**:
  ```
  $ grep -c 'struct drm_atomic_state' files/7.2/00100-*.patch files/7.2/00101-*.patch
  00100: 40      00101: 36
  $ grep -rn 'drm_atomic_state' files/7.2/*.patch | grep -i 'typedef\|#define'   -> (no shim)
  $ git show 6d14c66:include/drm/drm_atomic.h | grep -n 'struct drm_atomic'
  480:struct drm_atomic_commit {           # "drm_atomic_state" symbol does not exist in 7.2.9
  $ git show 6d14c66:include/drm/drm_panel.h | grep -n 'devm_drm_panel_alloc\|drm_panel_init'
  318:#define devm_drm_panel_alloc(dev, type, member, funcs, connector_type)
  # ncz 0081 body:
  6:- drm_atomic_state renamed to drm_atomic_commit treewide
  14:- drm_panel_init -> devm_drm_panel_alloc (edp panel)
  65:+	panel = devm_drm_panel_alloc(dev, struct cix_edp_panel, base,
  ```
- **Note**: `agents/display/REPORT.md` says overlay `1003` "already covers most of 0081";
  the two API items above are the residual and are **not** in `1003` (`grep -c` = 0 there).
  `.patchwork/base` presently has `struct drm_atomic_state` in `drivers/gpu/drm/cix/**`, so
  that tree cannot compile the CIX display stack as-is. The 7.2 sweep only checked
  gotos/braces, which is why this survived.

---

## TIER 1 — binds / crashes during boot

### 2. ncz **0100 (+0106/0108)** — Sky1 PCIe SMMU bypass-STE / ATS-override and event-queue storm
- **What it fixes**: pre-installs bypass STEs for the 10 known Sky1 root-port SIDs and sets
  `ARM_SMMU_OPT_PCIE_ATS_OVERRIDE` (forces `EATS=TRANS` for PCIe masters). `0106` disables
  `CR0.EVTQEN`; `0108` re-enables it and masks `ARM_SMMU_FEAT_PRI` instead.
- **Device**: SMMUv3 in front of the PCIe root complexes → **NVMe, RTL8127 NIC, USB controllers**.
- **Visible at BOOT**: yes — event-queue storm / bus-master during stream-table reset
  (`event 0x07` C_BAD_STREAMID, ~130 IRQ/s CPU0) can wedge the first NVMe access.
- **Evidence** (nothing in our set):
  ```
  $ grep -l 'ARM_SMMU_OPT_PCIE_ATS_OVERRIDE\|arm_smmu_init_sid_strtab\|CR0_EVTQEN' files/7.2/*.patch
  (no output)
  # our only SMMU patches: 0037 (suspend/resume) and 0070 (IRQ-setup on resume)
  # ncz 0100:
  65:+#define CIX_SKY1_PCIE_SMMU_BASE	0x0b010000ULL
  91:+		if (arm_smmu_init_sid_strtab(smmu, sid)) {
  103:+	smmu->options |= ARM_SMMU_OPT_PCIE_ATS_OVERRIDE;
  ```
- **Caveat** (from `agents/thermal-iommu-pcie/`): 0106 vs 0108 contradict each other
  (EVTQ off vs PRI off). Adopt 0100; pick 0106-style EVTQ disable or 0108-style PRI mask
  by metal test. `0108` also has `ARM_SMMU_FEAT_PRI`; our set only references it in `0070`.

### 3. ncz **0168** (+0148/0157) — CLKT→clkdev bridge never re-maps when the late SCMI clocks device binds
- **What it fixes**: registers a `bus_register_notifier(&scmi_bus_type, …)`; on
  `BUS_NOTIFY_BOUND_DRIVER` for `SCMI_PROTOCOL_CLOCK`/`"clocks"` it re-runs the ACPI CLKT
  walk (idempotent via `mapped_list`).
- **Device**: every CLKT-derived clock consumer — **NVMe/PCIe PHY `pclk`, USB PHY/glue,
  i2c-cadence, pwm-sky1, sky1-gpt timer, audio**.
- **Visible at BOOT**: yes. Measured on ncz: the bridge probes ~1.11 s, the second SCMI
  "clocks" device binds ~1.47 s, so aliases are never created and those consumers defer.
- **Evidence**:
  ```
  $ grep -l 'bus_register_notifier\|scmi_bus_type\|mapped_list' files/7.2/*.patch   -> (none)
  $ grep -l 'sky1_acpi_clk_probe' files/7.2/*.patch -> 00052-clk-add-cix-clk-driver.patch
  # i.e. we ship the bridge (00052) but not the late-bind remap.
  # ncz 0168:
  29:notifier on scmi_bus_type; on BUS_NOTIFY_BOUND_DRIVER for the clocks
  98:+	struct list_head mapped_list;
  116:+	list_for_each_entry(map, &priv->mapped_list, node) {
  ```
- **Same family (each is an independent `-ENOENT → -EPROBE_DEFER` fix; absent from 7.2)**:
  | ncz | consumer | our tree today | ncz added line |
  |---|---|---|---|
  | 0166 | `timer-sky1-gpt.c` | `0045` returns `-EINVAL` on `devm_clk_get` failure (`grep -n -A2 fch_timer_apb_clk 0045-*.patch` → `return -EINVAL;`) | `18:Same -ENOENT-to-EPROBE_DEFER translation … 33:+ return dev_err_probe(&pdev->dev,` |
  | 0158 | `pwm-sky1.c` | `0028` uses `return dev_err_probe(dev, PTR_ERR(sky1->pclk), …)` (raw `-ENOENT`) | `43:+ -EPROBE_DEFER : PTR_ERR(sky1->pclk),` |
  | 0165 | `i2c-cadence.c` | `0019` never touches the clock (base `devm_clk_get_enabled`, raw errno) | `28:+ -EPROBE_DEFER : PTR_ERR(id->clk),` |
  | 0095 | `phy-cix-pcie.c` / `phy-cix-usbdp.c` `pclk` | `0024` returns raw `PTR_ERR`; `0072`/`0073` don't cover `pclk` | `agents/clock` verified |
- **Boot impact**: 0166 is the sharpest — a lost race permanently drops the system
  clocksource for that boot.

### 4. ncz **0110** + **0109** — RTL8127 (Sky1 NIC) HW-tally SError and ASPM/ClockPM
- **What it fixes**: `0110` early-returns `rtl8169_update_counters()` for
  `RTL_GIGA_MAC_VER_80` (RTL8127A) because its BAR is inaccessible while `pm_runtime`
  reports active → fatal ARM SError `ESR 0xbe000011`. `0109` additionally disables
  ASPM/ClockPM on `PCI_VENDOR_ID_REALTEK/0x8127`, gated on `acpi_dev_present("CIXH2020",…)`.
- **Device**: MS-R1 onboard Realtek RTL8127 Ethernet.
- **Visible at BOOT**: not at link-up; appears under load / `get_stats64` polling, then
  hard-faults. Treat as boot-relevant because a `netdev` stat read can kill the box.
- **Evidence**:
  ```
  $ grep -l 'rtl8169_update_counters\|RTL_GIGA_MAC_VER_80' files/7.2/*.patch   -> (none)
  # ncz 0110:
  26:+	if (tp->mac_version >= RTL_GIGA_MAC_VER_80)
  # ncz 0109: PCI_VENDOR_ID_REALTEK/0x8127 ASPM+ClockPM clear in drivers/pci/quirks.c
  ```

### 5. ncz **0215** — Sky1 root ports cannot allocate I/O bridge windows
- **What it fixes**: `pci_read_bridge_windows()` gains
  `pci_bridge_has_parent_io_window()` / `pci_bridge_is_cix_sky1_root_port()`; a CIX Sky1
  root port (`17cd:0100`) whose parent already exposes `IORESOURCE_IO` is allowed the window.
- **Device**: PCIe bridge window assignment → any downstream I/O BAR (NVMe option ROM,
  xHCI, BMC-class devices).
- **Visible at BOOT**: resource assignment happens at PCI enumeration.
- **Evidence**:
  ```
  $ grep -l 'pci_bridge_has_parent_io_window\|pci_bridge_is_cix_sky1' files/7.2/*.patch  -> (none)
  # ncz 0215:
  54:+	       dev->vendor == 0x17cd && dev->device == 0x0100;
  ```

### 6. ncz **0122 + 0124** — `_STA` quirk for hidden Sky1 NPU/SCMI children
- **What it fixes**: in `drivers/acpi/sta_quirk.c` (our `2004`), un-hide `CRE0-2` under
  `CIXH4000/NPU0` and tighten the hidden-child match to parent HID + ACPI name
  (`CRE0-2`, `DVFS`/`CLKS`) + `uid == 0`.
- **Device**: Zhouyi NPU (CRE cores) and the SCMI `DVFS`/`CLKS` children under `CIXHA006`
  that our `2004` currently does not un-hide (`0124` also fixes a latent matching bug).
- **Visible at BOOT**: ACPI enumeration; the NPU itself is OOT/DKMS so the user-visible
  effect is mainly SCMI clock/perf children and NPU PM domains.
- **Evidence**: our `2004` handles `CIXHA008`/`CIXHA009` only:
  ```
  $ grep -l 'CIXH4010\|CRE0-2\|DVFS.*CLKS' files/7.2/*.patch   -> (none)
  # ncz 0122:
  44:+ *   CRE0-2 (NPU cores, children of CIXH4000/NPU0, all uids)
  ```

### 7. ncz **0160** — SCMI hwmon thermal zones never register
- **What it fixes**: Sky1 firmware does not implement SCMI `config_set`; the existing
  `continue` skips `scmi_thermal_sensor_register()` for **all 20 sensors** → only 5 generic
  acpitz zones. ncz demotes the failure to `dev_dbg` and falls through.
- **Device**: Sky1 thermal sensors/throttling (all SoC zones).
- **Visible at BOOT**: yes — thermal zones/cooling bindings are created at probe.
- **Evidence**:
  ```
  $ grep -l 'scmi_thermal_sensor_register' files/7.2/*.patch   -> (none)
  # ncz 0160:
  16:But the probe loop `continue`s past scmi_thermal_sensor_register()
  51:+			dev_dbg(dev,
  ```

### 8. ncz **0213** — safe ACPI fan control (`CIXHA024`)
- **What it fixes**: new `drivers/hwmon/cix-fan.c` exposing the CIXHA024 fan through standard
  hwmon PWM semantics with range/sentinel validation and a mutex.
- **Device**: MS-R1 chassis/SoC fan.
- **Visible at BOOT**: fan control only, but absence means no thermal mitigation path on
  an ACPI-only box; safety-relevant under load.
- **Evidence**: `$ grep -l 'cix-fan\|CIXHA024' files/7.2/*.patch -> (none)`.

### 9. ncz **0210** — ACPI thermal cooling bind uses a safe devfreq helper (our `0060` is weaker)
- **What it fixes**: `devfreq_cooling_get_device()` + `IS_REACHABLE()`, and an `np == NULL`
  fallback to `thermal_cooling_device_register()` in `of_devfreq_cooling_register_power()`
  (7.2 dropped the `np` argument from the devm registration path).
- **Device**: GPU/CPU devfreq cooling binding on ACPI (no OF node).
- **Visible at BOOT**: cooling device registration at thermal-zone creation.
- **Evidence**:
  ```
  $ grep -l 'devfreq_cooling_get_device' files/7.2/*.patch   -> (none)
  $ grep -l 'devfreq_cooling' files/7.2/*.patch -> 0060-ACPI-thermal-bind-devfreq-cooling-devices-via-devfre.patch
  # our 0060 uses the Devin-Li variant (moves struct to a public header, string-matches
  # cdev->type); it does NOT add the np==NULL fallback 7.2 needs.
  # ncz 0210:
  58:+	struct device *cdev_dev = devfreq_cooling_get_device(cdev);
  83:+devfreq_cooling_get_device(struct thermal_cooling_device *cdev)
  ```
- **PARTIAL**, not a total miss: our `0060` addresses the same `acpi_thermal_should_bind_cdev()`
  bug but not the 7.2 registration adaptation.

### 10. ncz **0090** (conditional) — `acpi_dev_pm_detach()` schedules while atomic
- **What it fixes**: probe-failure cleanup calls `acpi_remove_pm_notifier()` →
  `synchronize_srcu()` under `deferred_probe_work` with preemption disabled → `BUG: scheduling
  while atomic`. ncz stops removing the notifier in the failure path.
- **Evidence**: `$ grep -l 'acpi_dev_pm_detach' files/7.2/*.patch -> (none)`.
- **Risk**: band-aid (leaks the notifier on any ACPI probe failure). Take only if the real
  BUG is observed; label UNVERIFIED for MS-R1.

---

## TIER 2 — needed for correct operation under load / runtime

Display (all absent from our `files/7.2`, all ACPI-relevant on MS-R1):
- **0154 + 0170** — DPTX reset/clock validation and "only require what firmware declares".
  Without it the DPTX can never probe on firmware that declares only `dp_reset` and
  `vid_clk0/1`. `grep -l 'trilin_dp_fw_declares' files/7.2/*.patch -> (none)`.
- **0176** — AUX/DPCD cold-boot robustness (`-EBUSY` from a not-yet-drained AUX engine →
  permanent no-display). No AUX-retry patch in our set.
- **0046** — `drm_kms_helper_connector_hotplug_event()` on resume; userspace never re-probes
  after STR. `grep -l 'connector_hotplug_event' files/7.2/*.patch -> (none)`.
- **0169** — double `clk_put()` on ACPI pxlclk: our `00100` has
  `24010:+	clk_put(pipe->pxlclk);` in `linlondp_pipeline_destroy()` while the ACPI path used
  `devm_clk_get()` → `__clk_put` on `LIST_POISON2` at teardown. ncz guards with
  `has_acpi_companion()`.
- **0156 + 0162** — `linlondp_dev.c` aclk `clk_prepare_enable()` failure propagation and
  `-ENOENT → -EPROBE_DEFER`.
- **0134 (+0133)** — DPTX/DPU runtime-PM restore; overlay `00100` still has the
  `//pm_runtime_enable(dp->dev);` lines commented out. Reconcile with our `00101` pin model.
- **0161** — eDP panel ACPI `_DSD` desc properties (bpc/bus-format defaults). `00100` uses
  `of_property_read_u32` gated on `desc->num_modes || desc->num_timings`.
- **0226 → 0223 → 0229 → 0231** — DP-audio ELD chain. `get_eld`,
  `hdmi_audio_infoframe_pack_for_dp`, `params->cea` are all absent from our set; DP audio is
  silent/no-ELD without it.

Audio (highest-value genuine audio delta):
- **0171 + 0182 (+0224 ACPI half)** — our `0022-sound-soc-add-cix-soc-support.patch`
  hard-codes `sky1_hdmi_topology[]` / `"hdmi-audio-codec.%d"` and never uses
  `device_find_child(..., cix_dp_match_hdmi_codec)` or `device_link_add(DL_FLAG_AUTOREMOVE_CONSUMER)`;
  ncz abandoned that approach on real hardware. `grep -l 'cix_acpi_dp_audio_get' files/7.2/*.patch -> (none)`.
- **0224 correctness subset** — `card-utils.c` `cix_dailink_status_check()` has the
  uninitialised-`status` UB in our tree:
  ```
  files/7.2/0022-*.patch:
  221:+	ret = of_property_read_string(np, "status", &status);
  223:+	if (status) {                 # reads uninitialised pointer if read failed
  ```

Thermal / CPUfreq:
- **0184** — `cpufreq_cooling` errors on missing OF node under ACPI
  (`$ grep -l 'capacity_freq_ref\|cpufreq_cooling.*OF node' files/7.2/*.patch -> (none)`; log-only).
- **0204** — `arch_topology` `capacity_freq_ref` cpufreq notifier on ACPI
  (`$ grep -l 'capacity_freq_ref' files/7.2/*.patch -> (none)`).

SCMI:
- **0093 + 0132** — activate firmware-implemented protocols and set up their Tx/Rx channels
  when the ACPI namespace has no per-protocol children. `scmi_is_protocol_implemented` and
  `scmi_txrx_setup` (only the base in our adopted `0003`) absent from any 7.2 patch except
  `0003`'s own `scmi_txrx_setup`. Whether MS-R1 needs it is UNVERIFIED (`2004` suggests the
  children exist but are hidden).
- **0209 + 0183/0185** — exact rational perf↔freq conversion and idempotent OPP add.
  `grep -l 'sustained_freq\|level_indexing_mode' files/7.2/*.patch -> (none)`.

Core:
- **0200** — rpmsg `dev_err_ratelimited`; the log flood is caused by **our own**
  `0009-remoteproc-add-cix-dsp-remoteproc-driver.patch`. `grep -l 'no used buffer' files/7.2/*.patch -> (none)`.
- **0202** — `platform_get_irq_byname()` fallback when the ACPI named IRQ's GSI is not yet
  mapped (PSIU mailbox probe race).
- **0206** — pstore/ramoops firmware-node property lookup, otherwise ramoops silently never
  registers on ACPI.
- **0181** — fixes a genuine defect in **our** `0033-regulator-add-acpi-support.patch`:
  ```
  files/7.2/0033-*.patch:
  331:+		bool found;
  347:+			set[i] |= found;      # uninitialised, accumulated across levels
  # ncz 0181:
  29:+			found = !fwnode_property_read_u32(np, prop, &pval);
  ```
- **0177** — pinctrl ACPI: an absent optional pin group aborts the whole consumer walk.
  `grep -l 'acpi_pinctrl_group_present' files/7.2/*.patch -> (none)`.

USB:
- **0193 / 0222** — generic root-hub power-on-good floor and powered-but-RPM-suspended port
  recovery (`drivers/usb/core/hub.c` is untouched by our set:
  `grep -l 'drivers/usb/core/hub.c' files/7.2/*.patch -> (none)`). Both are deliberate
  mainline divergences; ncz measured them on O6N, UNVERIFIED on MS-R1.
- **0163/0164 (partial)** — our `0025` already translates `-ETIMEDOUT → -EPROBE_DEFER` for
  clock enable and returns `-EPROBE_DEFER` for not-yet-bound PHYs, but `devm_clk_bulk_get()`
  `-ENOENT` is still terminal (ncz 0164) and `phy-cix-usb3` `apb_clk/ref_clk` `-ENOENT` is
  not translated (ncz 0163).

GPU:
- **0188** — re-apply Sky1 hw power-on at noirq resume. Our consolidated `0011` uses
  `SET_SYSTEM_SLEEP_PM_OPS` (grep `noirq` → only `0031`/`0032`), so resume-after-STR power-on
  is not replayed. ncz itself did **not** apply `0188` (`.unwired`-equivalent), so lower
  confidence than the display/SMMU items.

---

## TIER 3 — optional / cosmetic / knowingly skipped

Log-noise and diagnostics (safe to skip): **0178** (SCMI fastchannel fallback), **0179**
(SMMU FW-config notes), **0207** (TBU no-op), **0214** (ECAM duplicate reservations),
**0205** (module-param doc), **0203** (inert, `CONFIG_OF=y`).
Optional hardening: **0201** (acpi_table_upgrade on/off), **0208** (btrtl error propagation),
**0212** (cacheinfo global IDs), **0217/0218** (rtw89 rfkill/`_DSM`), **0107** (fixed-regulator
`enabled_at_boot`), **0059** (gpio-cadence `preserve_firmware_config` — metal-gated, changes
probe-time pin init on a box that boots), **0088** (pmdomain late fwnode provider — only if a
consumer SError reproduces), **0094** (panthor defer on rate 0), **0180/0192** (USB wrapper RPM
ordering — our `0025` already gates on wrapper `pdata`), **0113** (our `0025` covers the
phy-dep check), **0167** (gated on ncz `0066`, which we don't carry).

Explicitly rejected as diagnostics/never-ship: **0089** (global `pm_runtime` gate),
**0142/0144/0150/0151** (VPU/clk diagnostics), **0219/0230** (ramoops/ELD tracing),
**9021/9022** (`.unwired` beacons/PCIe knobs).

---

## Sanity-check of the four deliberate non-adoptions

### A. ncz **0118** rts5453 vs our SMBus-ARA design — **non-adoption still sound**
ncz `0118` restores a plain shared threaded IRQ and has **no** ARA:
```
0118: 1033:+ ret = devm_request_threaded_irq(&client->dev, client->irq,
      1035:+ IRQF_TRIGGER_LOW | IRQF_SHARED | IRQF_ONESHOT,
      (grep -c 'ara|ARA' 0118 -> 1, a non-functional mention)
```
Our `0078` deliberately hands the IRQ to the generic SMBus-ARA core
(`i2c_new_smbus_alert_device()`, `struct rts5453_irq_group`) because **MS-R1 wires two
RTS5453 (0x30/0x31) to one active-low GpioInt**; our `0088` then acks the shared IRQ when no
chip answers ARA, with live evidence (`/proc/interrupts 144 … smbus_alert`, ~7,800 IRQ/s,
`irq_acks=0`). ncz's form would re-collapse both chips onto one handler with no ARA drain.
**Keep ours.** The real risk is not ncz — it is that `0088` is marked *NOT BUILT, NOT
BOOT-TESTED*; carry that through the metal test.

### B. ncz PCIe model arbitration vs our vendor `sky1-pcie` driver — **non-adoption sound**
ncz `0099` adds `early_param("sky1_pcie_native", …)` (default native) and `0101` blocks
`CIXH2020` platform devices in *standard/ECAM* mode:
```
0099: early_param("sky1_pcie_native", …)   # gates sky1_acpi_scan_attach()
0101: block CIXH2020 in standard mode      # avoids vendor early-reset killing live links
```
Our `0030` (disable ACPI PCIe devices) + `0031`/`0032` (vendor `sky1-pcie` driver) is the
native-only design; we carry **no** ECAM fallback and no `sky1_pcie_native` knob
(`grep -l 'sky1_pcie_native' files/7.2/*.patch -> none`). `0101` only matters if the standard
mode is reachable, so it is not a gap for us. This is sound **as long as MS-R1 firmware is
the native path**; if a future BIOS needs ECAM, `0099+0101` must be taken as a unit.

### C. ncz in-tree NPU (`0119`–`0125`) / VPU (`0126`+`0129`–`0153`, `0173`, `0194`) — **non-adoption sound**
ncz's own production config forbids in-tree NPU (`config-7.2-lean-msr1-o6n.defconfig`:
*"ARMCHINA_NPU MUST NOT BE BUILT IN-TREE … the accelerator ships as a vendor DKMS module"*)
and de-facto runs the OOT `amvx.ko`. In-tree builds collide with our
`cix-npu-driver`/`cix-vpu-driver` (same `armchina_npu.ko`/`amvx.ko`, duplicate
`armchina_aipu_alloc_dma_buf`). Our `grep` confirms no `drivers/misc/armchina-npu` or
`drivers/media/platform/cix` in `files/7.2`. **Keep out-of-tree.** The actionable residue is
that the *same bugs* exist in our OOT packages and should be patched there:
`0159`+`0220` (IRQ `dev_id`/oneshot), `0121`+`0123` (NULL `pd_core[]`, force D0),
`0173` (vb2 `q->lock`), `0130` (reset before `enable_irq`), `0128`/`0129`
(`<linux/string.h>`/`strscpy`, missing-firmware error propagation), `0194` (workqueue order).
Only **0122/0124** (`sta_quirk.c`) belong in `cix-sources` and are listed as Tier-1 GAP #6.

### D. ncz **0084-equivalent / config umbrella** (ncz `0116` + 7.1's `0084`) — **our re-expression is sound**
Our `DIVERGENCES-7.2.md` §5 re-expressed the old `0084 CIX_SKY1_USB` umbrella as `0090`
(direct Kconfig deps) plus `0089` (PHY dependency):
```
0090: depends on USB_ROLE_SWITCH ; select I2C_SMBUS ; PHY_CIX_* : depends on ACPI || OF
0089: select PHY_CIX_USBDP if ARCH_CIX ; MODULE_SOFTDEP("pre: phy-cix-usbdp")
```
ncz `0116` instead reverts 7.2's unified `USB_CDNS3` Kconfig to the fork's split
`USB_CDNS_HOST`/`USB_CDNSP` layout. Our form is coherent with the srcshelton 7.2-native USB
`0025` and fixes the same two real problems (OF-only PHY gating on an ACPI box; missing
`I2C_SMBUS`/role-switch deps). **Keep ours.** The one genuine config item ncz documents that
we do not ship is the `17cd:0100` PCI/USB ID collision rule
(`# CONFIG_USB_CDNS3_PCI_WRAP is not set`, else `cdnsp_pci_probe` NULL-derefs on the Sky1
root ports). Our `0090` sets `depends on ACPI || OF` for `USB_CDNS3_SKY1` but does not by
itself force `USB_CDNS3_PCI_WRAP`/`USB_CDNSP_PCI` off; the ebuild ships no config at all, so
this remains a **documentation/instruction item** (recommend adding it to the overlay's
reference config guidance).

---

## Corrections to the earlier (7.1-based) reports

These were listed as gaps against `files/7.1` but are **already resolved in `files/7.2`**:

- **ncz 0112 (USB host role init)** — NOT a gap. Pristine 7.2.9 already does it, and our
  `0025` preserves the lines:
  ```
  $ git show 6d14c66:drivers/usb/cdns3/cdns3-plat.c | grep -n 'host_init\|cdns_core_init_role'
  173:	cdns->gadget_init = cdns3_plat_gadget_init;
  174:	cdns->host_init = cdns3_plat_host_init;
  175:	ret = cdns_core_init_role(cdns);
  ```
  Our `0025` hunks only remove the old PHY error labels; these lines are untouched context.
- **ncz 0221 (wrapper-ready gate)** — equivalent present: our `0025` probe defers when the
  ACPI wrapper's `pdata` is not yet set
  (`+ if (has_acpi_companion(dev) && !cdns->pdata) return dev_err_probe(dev, -EPROBE_DEFER, "waiting for platform wrapper data\n");`)
  and resolves PHY child devices by fwnode with `-EPROBE_DEFER`/`device_link_add`.
- **ncz 0187-route (panthor SCMI DVFS via perf OPP)** — equivalent present in the adopted
  srcshelton `0011`: it stores `pdevfreq->opp_dev` and does
  `dev_pm_opp_find_freq_ceil(pdevfreq->opp_dev, …)` / `dev_pm_opp_set_opp(pdevfreq->opp_dev, opp)`.
- **ncz 0135 panthor / 00186-ipreset / 00188** — our `0011` already carries `gpu_reset`,
  RCSU `0x218` clock-gate enable and the `gpu_clk_stacks` named clock.

---

## Appendix — per-patch verdict (all 229 on-disk files)

**COVERED (72)** — equivalent functionality in `files/7.2`:
`0001 0002 0003 0007 0008 0009 0011 0012 0013 0014 0015 0016 0017 0018 0019 0020 0021 0023
0024 0025 0026 0027 0028 0029 0031 0032 0033 0034 0035 0036 0037 0038 0039 0040 0041 0042
0043 0044 0045 0047 0048 0049 0051 0053 0054 0055 0056 0057 0058 0060 0061 0062 0063 0067
0075 0076 0077 0078 0082 0085 0086 0087 0096 0104 0105 0112 0131 0187(route) 0187(ipreset)
0189 0221 0227 0232`

**PARTIAL (8)** — subset present, remaining work listed in the tiers:
`0084` (panthor fwd-port; srcshelton `0011` is a superset but softer coherency/power-on —
re-verify on MS-R1) · `0113` (phy-dep half present) · `0148`+`0157` (CLKT pending/error
propagation; only useful with `0168`) · `0180`+`0192` (USB RPM ordering) · `0210` (ACPI
devfreq-cooling; our `0060` is the weaker variant) · `0224` (audio hardening; ACPI device-link
half missing).

**GAP (71)** — ranked in the tiers above:
`0046 0059 0081 0088 0090 0093 0094 0095 0099 0100 0101 0102 0103 0106 0107 0108 0109 0110
0122 0124 0132 0133 0134 0154 0155 0156 0158 0160 0161 0162 0163 0164 0165 0166 0168 0169
0170 0171 0176 0177 0178 0179 0181 0182 0183 0184 0185 0188 0193 0200 0201 0202 0204 0205
0206 0207 0208 0209 0211 0212 0213 0214 0215 0216 0217 0218 0222 0223 0226 0229 0231`
(0102/0103 are the "optional reset" policy differences vs our `0072`/`0073`; take only as a
deliberate revision, not stacked.)

**CONFLICT (14)** — competing design; do not merge:
`0004 0005 0006 0010 0022 0065 0066 0068 0069 0070 0071 0072 0118 0228`
(`0228` = ncz caps linlondp at 32 planes; our `00101` widens core DRM to 64 — a policy choice,
not automatically a gap; v7.2.9 `drm_plane_mask()` is still `u32`.)

**NA (41)** — ncz-only tree/unapplied/superseded:
`0030 0052 0064 0073 0074 0079 0080 0083 0091 0092 0097 0098 0111 0114 0115 0116 0117 0119
0120 0125 0126 0127 0136 0137 0138 0139 0140 0141 0143 0145 0146 0146 0147 0149 0167 0172
0174 0186 0186 0190 0191 0203 0225`
(`0203` is inert with `CONFIG_OF=y`; `0097/0098/0167/0183/0190/0191/0083` are gated on ncz
`0066` which we deliberately do not carry.)

**OOT (12)** — fix belongs in our out-of-tree accelerator packages:
`0121 0123 0128 0129 0130 0135 0135 0152 0153 0159 0173 0194 0220`

**DIAG (7)** — never ship: `0089 0142 0144 0150 0151 0219 0230` (plus `.unwired` 9021/9022).

---

## Ordered action list (what the parent should do next)

1. **Fix `0081`'s residual in `files/7.2` before anything else** — `00100`/`00101` cannot
   compile against 7.2.9. Rename `drm_atomic_state`→`drm_atomic_commit` (and the 7
   `drm_atomic_state_put` sites in our patches → `drm_atomic_commit_put`), and switch the eDP
   panel to `devm_drm_panel_alloc()`.
2. **Adopt `0100`** (SMMUv3 Sky1 bypass-STE + ATS override); decide `0106`-EVTQ-off vs
   `0108`-PRI-mask by metal test. This is the NVMe/PCIe boot wedge.
3. **Adopt `0168`** (CLKT remap on late SCMI bind), then `0166/0158/0165/0095` deferral fixes.
4. **Adopt `0110` (+`0109` conditional)** for the RTL8127 SError.
5. **Fold `0181` into `0033`** (real uninitialised-`found` bug in our code).
6. Adopt `0160`, `0213`, `0215`, `0122+0124`, and replace/augment `0060` with `0210`'s
   `np == NULL` 7.2 adaptation.
7. Drift/hardening batch: `0200`, `0202`, `0206`, `0177`, `0184`, `0204`, `0046`, `0169`,
   `0154/0170/0176`, `0156/0162`, `0226/0223/0229/0231`, `0171/0182/0224`.
8. **Do not adopt**: `0004/0005/0006/0065/0066/0068/0069/0070/0071/0072/0118/0228` and the
   in-tree NPU/VPU drivers; keep the rts5453 ARA, vendor `sky1-pcie` and out-of-tree
   accelerators as decided.

## §7 — latent hazards noted while auditing

- The 7.2.9 ebuild globs `files/7.2/*.patch` in **shell sort order**, so `00050…00062` and
  `00100/00101` are applied **before** `0007/0008/0009` and `0011`. This is benign today
  (they touch disjoint paths) but is a real ordering hazard when adding cross-dependent
  patches; the same warning is in the thermal/IOMMU report (R12).
- `DIVERGENCES-7.2.md` lists `0029` and several vendor USB patches as removed; this audit
  confirms the removal did not orphan functionality that ncz relies on, **except** for the
  `0081` display API drift, which the removal did not touch.
- Everything above is textual/grep evidence against `files/7.2` and pristine `6d14c66`; no
  build or metal test was performed (read-only constraint).
