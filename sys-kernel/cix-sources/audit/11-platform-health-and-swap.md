# 11 — Platform health after the 7.3.1 SSP test boot, and swap enablement

Test boot: `7.3.1-cix-ssp` (7.3.1 + opt-in SuperSpeedPlus patch `0190`,
`cix_usb_ssp_enable=1`), 2026-11-01 14:04 PST on the reference MS-R1.

## Swap

`/etc/fstab` already contained:

```
/dev/vg1/swap none swap sw 0 0
```

but the LV was not activated at boot, so systemd timed out waiting for
`/dev/vg1/swap` and no swap was active.  The cause was the LVM
autoactivation allow-list in `/etc/lvm/lvm.conf`, which only contained
`vg0/root`:

```
auto_activation_volume_list = [
    "vg0/root"
]
```

`vg1/swap` is a 98 GiB LV on `nvme1n1`.  It was added to the list:

```
auto_activation_volume_list = [
    "vg0/root",
    "vg1/swap"
]
```

The change was validated with a deactivate/reactivate cycle equivalent
to the boot path:

```sh
swapoff /dev/vg1/swap
lvchange -an vg1/swap
pvscan --cache --activate ay
swapon -a
```

Result: `vg1/swap` active, `/dev/vg1/swap` active as
`dev-vg1-swap.swap`, 97 GiB swap available.  A full reboot has not yet
been done after this change; the next boot should verify the systemd
device/swap units start without the timeout.

## Panthor / Mali

Kernel side:

- `panthor 1.9.0` initialized on `CIXH5000:00`
- Mali-G720-Immortalis `id 0xc870`, CSF FW interface v3.13.0
- ACE-Lite coherency, GPU power domain 21 on via SMC SCMI
- No panthor errors or faults in dmesg

Userspace/device side:

- `/dev/dri/card0` and `/dev/dri/renderD128` exist
- `/usr/share/vulkan/icd.d/panfrost_icd.aarch64.json` present
- `vulkaninfo --summary` reports:

```
deviceName  = Mali-G720 MC10
driverName  = panvk
driverInfo  = Mesa 26.3.0-devel (git-84acd8488a)
deviceType  = PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU
```

The GPU runtime PM state went `active` during Vulkan device creation and
back to `suspended` when idle, which is the expected power-gating
behaviour.  `panvk` prints its usual non-conformant warning; no kernel
errors result.

## Other platform checks

- `systemd`: `running`; no failed units.
- PCIe: 5 root ports, both RTL8127 10GbE controllers, all 3 NVMe
  controllers present; AER counters all zero; no NVMe resets/errors.
- Network: `enp1s0` up at 5 Gbps with VLAN `enp1s0.10`; `enp49s0` down
  (no carrier).  This is link/cabling, not a driver failure.
- Audio: HDA card `cix-ipbloq-hda` and ALSA devices present.
- RTC, cpufreq, hwmon sensors present.
- USB: SuperSpeedPlus test passed at 10 Gbps with a RTL9210/UAS
  adapter (856 MB/s read, no resets during I/O).
- NPU: hardware (`CIXH4010:00/01/02`) present but no `aipu` module,
  `/dev/aipu`, or UMD installed; the NPU driver remains a separate
  out-of-tree package and is not part of this kernel.

Known pre-existing dmesg noise remains: ACPI `MUX0`/`MUX1` lookup
timeouts (`cdns-i2c`, ASoC deferred probes), `ramoops` probe `-22`, and
CPPC `PEFG: AE_NOT_FOUND`.  These are also present without the SSP
change and are tracked in the earlier audit documents.

Ceph is degraded because the USB-SATA enclosure is intentionally
unplugged (10 OSDs down, 1 host down) and because of pre-existing MDS
metadata damage; `noout` is set.  That is a maintenance state, not a
kernel regression.
