# 05 — Boot-time risk review of three untested 7.2.9 behavioural changes

Read-only audit of the applied tree at `/root/grimtickle-overlay/.patchwork/base`
(Linux 7.2.9 + 85 patches). Nothing was built or booted; every claim below is
from the applied source, the mainline helpers it calls, and the vendor/srshelton
patch sets under `.ncz-review/`.

Verdict vocabulary, used explicitly per finding:

- **WILL BREAK BOOT** — can panic / deadlock / permanently lose a boot-critical device.
- **degrades a feature** — machine boots, device or class of events is lost/corrupted.
- **latent** — needs a teardown/removal or a probe race to trigger.

Summary order is most serious first.

---

## F1 — panthor: GPU power-on was switched from the vendor's raw-SMC/IDM sequence to an ACPI PowerResource; a mismatch is an SError panic

**Change:** 0011. **Files:** `drivers/gpu/drm/panthor/panthor_device.c`
`panthor_sky1_acpi_power_on()` (lines 61–106), called from
`panthor_device_init()` line 363 and `panthor_device_resume()` line 650;
`panthor_sky1_hw_prepare()` line 108, first MMIO at line 130.

`panthor_sky1_acpi_power_on()` requires an ACPI `_DSD` reference named
`mali-supply` or `power-supply` on the CIXH5000 GPU device, and calls
`acpi_device_set_power(supply, ACPI_STATE_D0)`.

- Property missing/not an ACPI device → `dev_err_probe(dev, -ENODEV, ...)`
  (lines 88–96) → `panthor_device_init()` returns -ENODEV → **probe fails
  permanently, GPU absent** (degrades a feature; `dev_err_probe` does not defer).
- Property present but the referenced object is not `power_manageable`
  (e.g. a bare `PowerResource`, or a Device without `_PR0`/`_PS0`),
  `acpi_device_set_power()` returns `-EINVAL` (`drivers/acpi/device_pm.c:167`)
  → same permanent failure.
- Property present and valid, but the resource's AML does not perform the
  SoC/IDM hand-off the vendor's raw SMC did: the *first* `readl()` of
  `ptdev->sky1_rcsu_reg + PANTHOR_SKY1_RCSU_PGCTRL` in
  `panthor_sky1_hw_prepare()` (line 130) or the first GPU MMIO in
  `panthor_hw_init()` runs against an unopened register window → asynchronous
  SError → `arm64_serror_panic()` → **WILL BREAK BOOT**.

This is not hypothetical: the vendor's own 7.2 line carries
`.ncz-review/.../0186-drm-panthor-sky1-power-on-GPU-via-raw-SMC-SCMI-before-first-MMIO.patch`
whose message states TFA's SCMI handler both powers the GPU domain **and**
programs the IDM to permit non-secure GPU register access, and that "skipping
it means the very first GPU MMIO read in `panthor_hw_init()` raises an
unrecoverable SError". The overlay's 0011 replaced that call; whether the
MS-R1 DSDT's GPU power resource does the equivalent cannot be checked here
because `.ncz-review/msr1-acpi.dat` is a 0-byte failed acpidump.

Note: on the O6 1.3 DSDT (`.../acpi-table-upgrade/o6/1.3/dsdt/DSDT.asl:13064`,
`GPU` / `GPUP`), `mali-supply`/`power-supply` point at Device `GPUP`, which has
`_PR0`/`_PR3` and whose `_ON` does `DMRP (One, 0x04, 0x15000000, One)`, i.e. the
ACPI path *is* plausible on that firmware. The hazard is MS-R1 firmware parity,
which is unverified.

---

## F2 — panthor: coherency is now decided by firmware `_CCA` and can hard-fail probe or silently run the wrong protocol

**Change:** 0011 (implicit — it does not carry the vendor's Sky1 coherency
quirks). **File:** `drivers/gpu/drm/panthor/panthor_gpu.c`
`panthor_gpu_coherency_init()` lines 471–492.

```
477  /* Start with no coherency, and update it if the device is flagged coherent. */
478  ptdev->gpu_info.selected_coherency = GPU_COHERENCY_NONE;
479  ptdev->coherent = device_get_dma_attr(ptdev->base.dev) == DEV_DMA_COHERENT;
481  if (!ptdev->coherent) return 0;
...
488  if ((gpu_read(...GPU_COHERENCY_FEATURES) & GPU_COHERENCY_PROT_BIT(ACE_LITE))) {
489      ptdev->gpu_info.selected_coherency = GPU_COHERENCY_ACE_LITE; return 0;
491  drm_err("Coherency not supported by the device"); return -ENOTSUPP;
```

Under ACPI, `device_get_dma_attr()` is `acpi_get_dma_attr()` driven purely by
the `_CCA` bit (`drivers/acpi/scan.c:1526-1531`, `drivers/acpi/property.c:1683`).
The O6 DSDT declares the GPU `_CCA = One` (`DSDT.asl:13123`), so this path
selects ACE-Lite on that firmware without any SoC-specific confirmation.

Concrete outcomes:

- `_CCA=1` but `GPU_COHERENCY_FEATURES` does not advertise ACE-Lite →
  `-ENOTSUPP` → **GPU probe fails permanently** (degrades a feature).
- `_CCA=1` and ACE-Lite advertised, but the platform is actually wired
  non-coherent → silent GPU/DPU coherency mismatch (stale framebuffer reads).
  Vendor patch `0115-soc-cix-add-ACPI-scan-handler-to-override-GPU-_CCA-o.patch`
  exists precisely because "the Sky1 DSDT declares the GPU (CIXH5000) with
  `_CCA=1` (coherent), but the SoC was designed for non-coherent GPU operation".
  That scan handler (`CIX_ACPI_GPU_SCAN`), and the panthor-side Sky1 coherency
  quirk the vendor says is also needed, are **absent from the overlay's 85
  patches** (grep for `_CCA`/`CIX_ACPI_GPU_SCAN`/`coherency_mode` over
  `sys-kernel/cix-sources/files/7.2/` finds only unrelated hits).

Verdict: **degrades a feature / silent corruption**, with a firmware-`_CCA`-
dependent hard probe failure. Not a boot freeze by itself.

---

## F3 — rts5453 (0088): delayed storm-rearm work can be re-armed after `cancel_delayed_work_sync()` and run on freed memory

**Change:** 0088. **File:** `drivers/usb/typec/rts5453.c`
`rts5453_group_leave()` lines 1418–1454, `rts5453_group_irq_handler()` lines
992–1018.

Teardown order is:

```
1429  if (group->ara_client) i2c_unregister_device(group->ara_client);
1437  cancel_delayed_work_sync(&group->storm_rearm_work);
1443  if (group->storm_masked) { group->storm_masked = false; enable_irq(group->irq); }
1447  free_irq(group->irq, group);
1450  debugfs_remove_recursive(group->debugfs_dir);
1452  mutex_destroy(...); mutex_destroy(...);
1454  kfree(group);
```

The guard handler is still registered between 1437 and 1447, and the line is
known to be stuck asserted (0088's own header: ~7800 IRQ/s). The
`enable_irq()` at 1445 re-exposes a still-asserted level line before
`free_irq()`. If the handler runs in that window and reaches
`RTS5453_STORM_NO_PROGRESS_MAX`, it executes

```
1013  disable_irq_nosync(irq);
1014  schedule_delayed_work(&group->storm_rearm_work,
1015                        msecs_to_jiffies(RTS5453_STORM_REARM_MS));
```

i.e. it re-arms `storm_rearm_work` **after** the only cancel. Nothing cancels it
again before `kfree(group)`; 5 s later `rts5453_group_storm_rearm()` runs
`container_of()` on freed memory and calls `enable_irq()` (UAF → slab corruption
or panic; also an unbalanced enable). Correct order is `free_irq()` first
(which synchronises with the handler), then cancel the work, then free.

Verdict: **latent use-after-free**, reachable at shutdown/unbind and at boot on
the `rts5453h_probe()` error path (line 1570). Not a deterministic boot breaker.

---

## F4 — rts5453 (0088): the guard handler re-queues `apply_work` after `cancel_delayed_work_sync()`; the probe-failure path never cancels it at all

**Change:** 0088. **File:** `drivers/usb/typec/rts5453.c`
`rts5453_group_service_members()` lines 954–969 (schedule at line 965),
`rts5453h_remove()` lines 1583–1592, probe error path line 1570.

`rts5453_group_service_members()` is called from the new guard handler and
does `schedule_delayed_work(&rts->apply_work, 0)` after only a
`READ_ONCE(rts->removing)` check taken under `members_lock`.

- `rts5453h_remove()` sets `removing` and calls
  `cancel_delayed_work_sync(&rts->apply_work)` (1587–1588) **before**
  `rts5453_group_leave()` removes the member from `group->members` (1592).
  A handler that passed the `removing` check just before it was set can enqueue
  `apply_work` after the cancel returns. The subsequent `group_leave()` waits on
  `members_lock`, then unregisters ports and returns; `rts` is devm-managed on
  the i2c client and is freed at device release. `apply_work` has no devres
  cancel action, so it runs against freed `rts` → **UAF**.
- On probe failure, `rts5453h_probe()` jumps to `err_group_leave`
  (line 1570–1571) and calls `rts5453_group_leave()` **without** setting
  `removing` and **without** cancelling `apply_work`. Any alert handled during
  teardown can queue it; the probe then returns and devres frees `rts`
  → **UAF at boot**.

The previous (ARA-only) design was protected because `smbus_do_alert()` holds
`device_lock(&client->dev)` while calling `->alert()`, and
`i2c_unregister_device()` holds the same lock. The new guard handler calls
`rts5453_capture_and_clear_alert()` directly (line 963) and bypasses that lock
entirely, which is what creates the window.

Verdict: **latent use-after-free**, boot reachable on the probe-failure path.

---

## F5 — rts5453 (0088): the storm breaker counts *all* interrupts, not consecutive non-progressing ones — every 8th PD interrupt masks the line for 5 s

**Change:** 0088. **File:** `drivers/usb/typec/rts5453.c` lines 977, 998,
1200; macro line 945.

`group->no_progress` is incremented on every guard-handler invocation
(line 998), and is reset only when the handler itself trips the breaker
(line 1006) and when the re-arm work runs (line 977). There is **no reset on
success** and `rts5453_group_service_members()` cannot report whether the line
was actually released. Therefore the 8th *cumulative* interrupt since the last
mask always trips

```
945  #define RTS5453_STORM_NO_PROGRESS_MAX 8
946  #define RTS5453_STORM_REARM_MS        5000
```

and masks the shared PD IRQ for 5 s (`disable_irq_nosync`, line 1013). On a
healthy board with ordinary plug/role-swap/alt-mode traffic this is a spurious
5-second Type-C/PD blackout after every 8 events; on the stuck-line MS-R1 it is
the intended duty cycle. The comment at 937–944 explicitly claims "eight
consecutive rounds in which servicing the members did not release the line",
but the code cannot observe release, so the claim is wrong.

Verdict: **degrades a feature** (Type-C/PD events lost for 5 s at a time).

---

## F6 — rts5453 (0088): flag set is actually compatible — answer to the explicit question

**Change:** 0088. **Files:** `drivers/usb/typec/rts5453.c:1106,1147-1160`;
`drivers/i2c/i2c-smbus.c:190-205`; `kernel/irq/manage.c:1490-1690`.

- ARA action flags: `IRQF_SHARED | IRQF_ONESHOT`, no explicit trigger bits
  (`i2c-smbus.c:190`); `__setup_irq()` fills the trigger from
  `irqd_get_trigger_type()` (`manage.c:1494`).
- Guard flags: `IRQF_SHARED | IRQF_ONESHOT | group->trigger_type`, where
  `group->trigger_type = irq_get_trigger_type(group->irq)` (`rts5453.c:1106`).
- `__setup_irq()` accepts because `(old & new) & IRQF_SHARED` is set, the
  trigger bits equal `irqd_get_trigger_type()` (`manage.c:1620-1629`), and
  both actions set `IRQF_ONESHOT` (`manage.c:1631-1635`). Since 0078/0088 run
  with `CONFIG_I2C_SMBUS=y`, the ARA action is installed first, so the
  inherited-trigger path is not even needed.

So the request will **not** fail with `-EBUSY`, and if it somehow did, 0088 only
warns and sets `guard_irq = false` (`rts5453.c:1151-1160`) — non-fatal, but the
storm mitigation silently disappears. `disable_irq_nosync()` (not the blocking
`disable_irq()`) is also the correct choice inside the threaded handler:
`irq_finalize_oneshot()` checks `irqd_irq_disabled()` (`manage.c:1127`) and will
not unmask the line behind the breaker's back. No sleep-in-atomic or
probe-deadlock issue: the handler is threaded, and it only blocks on
`members_lock`/`rts->lock`, not on the requesting thread.

**Lower-severity items in the same change:**

- `rts5453_group_irq_disable()` (lines 899–905) takes the blocking
  `disable_irq()` under `pm_lock`, from suspend/shutdown. It waits for the guard
  thread, which may be inside I2C transactions. If the I2C adapter is already
  runtime-suspended this can hang; also the storm breaker's core-IRQ depth and
  the group's `irq_disable_depth` are two independent counters that must both
  unwind. The re-arm path does unwind, but any path that skips it leaves the
  shared line masked for ARA too.
- `storm_masked` / `no_progress` are plain non-atomic fields written from the
  handler and read from the work/teardown (lines 977–978, 1006–1007, 1443).
- `debugfs_remove_recursive(group->debugfs_dir)` (line 1450) happens after
  `free_irq` but before `kfree`; an open reader of `topology`/`counters` holds
  `s->private = group` and is not synchronised by debugfs.

---

## F7 — cdns3: the "destructive" ACPI hardware reinitalisation is back, guarded only by a device link

**Change:** 0025/0089. **File:** `drivers/usb/cdns3/cdns3-sky1.c`
`cdnsp_sky1_probe()` lines 722–726; `cdnsp_sky1_hw_init()` lines 220–250.

`cdnsp_sky1_probe()` unconditionally runs `cdnsp_sky1_hw_init()` — assert
`usb_reset`, assert `usb_preset`, SCMI clock programming, mode-strap write,
deassert — under ACPI as well as DT. The vendor's
`0086-usb-cdns3-Skip-destructive-hardware-reinit-under-ACP.patch` exists because
doing this under ACPI "killed xHCI controllers that were already active with
connected USB devices, causing 'xHCI host not responding to stop endpoint
command' followed by controller death" when xhci-plat (PNP0D10) probed first.

The 0025 redesign tries to avoid the collision by making the xHCI owner a
*child* (CIXH2031 → `cdns-usb3`) that is a device-link consumer of the wrapper
(`cdnsp_sky1_bind_acpi_children()`, line 578), and by blocking PNP0D10 in
`drivers/soc/cix/cix-acpi-usb-scan.c`. That only works if
`CONFIG_CIX_ACPI_USB_SCAN` is on and the child is genuinely deferred. If either
link is broken (config off, firmware exposes PNP0D10 anyway, child probes
independently), the wrapper resets a live controller.

Verdict: **degrades a feature / can kill USB**; boot-critical only if USB storage
is the root device (it is not on this Ceph host, but it is a recovery path).

---

## F8 — cdns3: probe-order losses are permanent, not `-EPROBE_DEFER` (no `cix_acpi_resource_lookup_defer()` use)

**Change:** 0025. **Files:** `drivers/usb/cdns3/cdns3-sky1.c:653-661,696-698,
544-612`; `drivers/usb/cdns3/cdns3-plat.c:168-170,182-184,199-203`.

The child device's resources/IRQ names come from the CIX `RSNL` table, injected
by `drivers/soc/cix/cix-acpi-resource-lookup.c` during the CIXA1019 probe
(lines 195–252, 714–729). Consumers are expected to call
`cix_acpi_resource_lookup_defer()`, as the CIX PHY drivers do
(`drivers/phy/cix/phy-cix-usbdp.c:1520`, `phy-cix-usb3.c:441`, …). Neither
cdns3 file does:

- `platform_get_irq_byname(pdev, "host"/"peripheral")` (`cdns3-plat.c:182,199`)
  returns `-ENXIO` until RSNL has named the resource; returned as-is
  (lines 183–184, 201–203) → **permanent probe failure, no USB**.
- `devm_reset_control_get_exclusive(dev, "usb_reset"/"usb_preset")`
  (`cdnsp_sky1.c:653,658`) returns `-ENOENT` if RSTL/RSNL injection has not run;
  passed to `dev_err_probe` → non-deferring → **permanent probe failure, no USB**.
- `cdnsp_sky1_get_phys()` returns bare `-ENODEV` when no CIXH2031 ACPI child
  with a PHY reference is found (`cdnsp_sky1.c:449`), and probe returns it
  directly (line 696–698) → permanent failure. (On the O6 DSDT the child *is*
  nested and only declares `cdnsp,usb3-phy`, which is fine because a missing
  reference yields NULL, not an error.)
- Conversely `bus_find_device_by_fwnode()` returning NULL is unconditionally
  `-EPROBE_DEFER` (`cdnsp_sky1.c:562-566`); if the child HID never matches
  (case/HID mismatch), the wrapper defers **forever** with no timeout and no
  diagnostic.

Verdict: **degrades a feature (USB lost permanently)**; not a boot breaker on
this host.

---

## F9 — cdns3: raw `platform_data` pointer into the wrapper's devres is handed to a child that can outlive it

**Change:** 0025. **Files:** `drivers/usb/cdns3/cdns3-sky1.c:523-542,589-602`;
`drivers/usb/cdns3/cdns3-plat.c:167,237,244,272,330,338`.

`data` is `devm_kzalloc`'d on the wrapper (line 636) and
`child_dev->platform_data = &data->pdata` (line 593) is a raw pointer into it.
The link is created with `DL_FLAG_AUTOREMOVE_SUPPLIER` (line 578–580), which
only deletes the link when the wrapper unbinds; it does not unbind the child.
`cdnsp_sky1_clear_acpi_pdata()` runs only from the wrapper's own `.remove()`
(line 799). If the wrapper is unbound while the child stays bound (module
unload/rebind), the child's `cdns3_plat_probe()`/PM/suspend callbacks dereference
freed memory (`cdns->pdata->usb2_phy`, `platform_suspend`, `quirks`).
`cdnsp_sky1_get_phys()`/`cdnsp_sky1_get_phy()` also leak a `phy_get` +
`device_link_add` pair per retry because the devres ref is added before the
probe can fail (`cdnsp_sky1.c:377-400`).

Verdict: **latent** (removal/rebind only).

---

## F10 — cdns3: `select PHY_CIX_USBDP if ARCH_CIX` ignores the symbol's `depends on TYPEC`

**Change:** 0089. **File:** `drivers/usb/cdns3/Kconfig` (`USB_CDNS3_SKY1`).

`PHY_CIX_USBDP` is a tristate whose Kconfig also has `depends on TYPEC`
(`drivers/phy/cix/Kconfig:29-35`). `select` bypasses dependencies, so a config
with `TYPEC=n` still forces `PHY_CIX_USBDP=y` and builds `phy-cix-usbdp.o`
against unavailable Type-C APIs → Kconfig "unmet direct dependencies" warning
and a likely build/link failure. For a tree that has never been compiled this
is a real blocker; on the MS-R1 config TYPEC is presumably on (the rts5453
Type-C driver is in the set), so it may not bite here.

Verdict: **build hazard**, not a boot hazard.

Also minor in the same area: `cdnsp_sky1_hw_stop()` returns early if
`reset_control_assert()` fails (lines 252–268), deliberately leaving the clocks
enabled — a clock leak on a failed/aborted probe.

---

## Explicit answers to the review questions

- **IRQ compatibility (0088):** satisfied. `IRQF_SHARED` on both, trigger bits
  equal `irqd_get_trigger_type()`, `IRQF_ONESHOT` on both. Registration will
  succeed; if it ever fails, the change degrades to ARA-only (the storm returns)
  rather than failing probe.
- **disable/enable balance (0088):** balanced in the normal, re-arm and
  storm-masked-teardown paths; **not** balanced against a concurrent storm trip
  between `cancel_delayed_work_sync()` and `free_irq()` (F3), which both leaks
  a re-armed work item and can enable a freed IRQ.
- **Atomic context / deadlock (0088):** none at probe or in the handler;
  `disable_irq_nosync()` is correct, and blocking `disable_irq()` is only used
  in process context (suspend/shutdown), where its interaction with the I2C
  adapter's own runtime PM is the residual risk.
- **Probe ordering (0025/0089):** PHY → wrapper → child is enforced by chained
  device links, but the RSNL/RSTL naming dependency (CIXA1019) is **not**
  deferred on, and the ACPI-child lookup defers forever if the HID never
  matches.
- **Firmware mismatch:** panthor can hard-fail probe (no GPU) or panic on SError
  (F1/F2); rts5453 silently degrades (F5); cdns3 can permanently lose USB
  (F8) or reset a live controller (F7).
- **Resource lifetime:** two concrete use-after-free windows in 0088 (F3, F4)
  and one latent raw-pointer lifetime bug in 0025 (F9).
