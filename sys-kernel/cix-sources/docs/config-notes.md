# MS-R1 (CIX Sky1 / CP8180) kernel configuration notes

The `cix-sources` ebuild ships sources only; it cannot enforce kernel config.
These are the config items that matter on the Minisforum MS-R1 ("TinyTerror"),
with the evidence for each. Apply them to the config you build with (the value
captured from the running board is noted where it differs).

## Required

### `# CONFIG_RT_GROUP_SCHED is not set`

The captured MS-R1 config has `CONFIG_RT_GROUP_SCHED=y`. That is wrong for this
board under a normal systemd/cgroup-v2 userland.

With `RT_GROUP_SCHED=y` and the cgroup-v2 `cpu` controller enabled (which
systemd does), every non-root cgroup starts with zero RT runtime. A
`sched_setscheduler(SCHED_RR)` call then fails with `EPERM` even for a process
holding `CAP_SYS_NICE`. Consequently rtkit and PipeWire silently stay on
`SCHED_OTHER`; under load the audio thread is not scheduled ahead of ordinary
work and you get XRUNs.

ncz-os found and fixed this on the same hardware (their r287/r289: forced
`RT_GROUP_SCHED` off). It is a config-only fix: `FAIR_GROUP_SCHED`,
`CFS_BANDWIDTH`, `cpu.weight` and `cpu.max` are unaffected.

Check with:

    grep RT_GROUP_SCHED /path/to/.config
    # want: # CONFIG_RT_GROUP_SCHED is not set

### `CONFIG_PINCTRL_SKY1=y` (and `CONFIG_PINCTRL_SKY1_BASE=y`)

The captured MS-R1 config has both unset. Without the Sky1 pinctrl driver, the
two ACPI pin controllers (`_SB.MUX0`, HID `CIXHA016`, and `_SB.MUX1`, HID
`CIXHA017`) never register, so every consumer that asks for its pin state fails
the controller lookup and logs, per device:

    pctldev with ACPI name '\_SB.MUX0' not found

On a normal boot this appears 16x for MUX0 and 24x for MUX1 (sbsa-uart,
cdnsp-sky1, cix-ipbloq-hda, sky1-asoc-card, cdns-i2s-mc, cdns-i2c), and those
devices run without their pin-mux configuration. The DSDT really does define
the controllers (Device MUX0/MUX1 with _HID CIXHA016/CIXHA017 and a full
pin-function table); they are just not driven. The pinctrl-sky1 driver matches
both HIDs.

ncz-os enables both in their 7.3.1 config. Use together with patch 0189
(pinctrl-acpi consumer deferral) so consumers that probe before the controller
registers wait for it instead of silently continuing.

Check with:

    grep PINCTRL_SKY1 /path/to/.config
    # want: CONFIG_PINCTRL_SKY1=y and CONFIG_PINCTRL_SKY1_BASE=y

## Consider

These are lower priority; the captured MS-R1 config values are shown.

| Option | Captured | Note |
|---|---|---|
| `CONFIG_DEBUG_INFO_BTF` | not set | if enabled, needs pahole >= 1.22 or olddefconfig silently drops it (ncz r283 gate) |
| `CONFIG_MODULE_COMPRESS` | `y` / `_XZ=y` | ncz's fleet rule is "never xz a .ko"; not required for this board |
| `CONFIG_DRM_PANIC_SCREEN` | `"qr_code"` | ncz uses `"kmsg"`; cosmetic |
| `CONFIG_MODVERSIONS` | not set | Yocto/DKMS concern, not ours |
| `CONFIG_DMABUF_DEBUG` | off | good; keep off (`amvx` dma-buf import maps zero pages) |
| `CONFIG_SQUASHFS_ZSTD` / `CONFIG_CRYPTO_ZSTD` | `y` / `m` | good; keep (zram-generator) |

Source for the ncz findings: ncz-os/meta-cix `linux-cix-sky1-ncz_7.3-rc7.bb`
revision notes (r283/r287/r289) and
`.review-7.3/analysis/ncz-7.3rc7-review.md` section G3/H3.
