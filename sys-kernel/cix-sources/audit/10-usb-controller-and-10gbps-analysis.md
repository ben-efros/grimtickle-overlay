# 10 — USB controller setup and the path to 10 Gbps USB-SATA

Analysis date: 2026-10-31, on the reference Minisforum MS-R1 running
`7.1.5-cix`, cross-checked against the reviewed 7.3.1 boot log from doc
`07`.

Goal: understand the USB controller topology and what stands between the
current state and 10 Gbit/s links to the USB-SATA bridges.

**Short answer:** the host controllers, PHYs, hubs and bridges are all
10 Gbps-capable, but the vendor/CDNSP wrapper currently force-disables
SuperSpeedPlus (SSP) in hardware. Every CIX SSP port therefore trains at
USB 3.1 Gen1 (5 Gbps) even though the xHCI root hubs advertise 10 Gbps.
The SATA bridges (`ASM235CM`) are 10 Gbps/USB 3.2 Gen2 devices; the
AS2107 hubs advertise 10 Gbps SSP too. Reaching 10 Gbps requires making
that SSP-disable configurable and validating the 10 Gbps stability
problem that caused the workaround, plus using UAS and a 10 G-rated
cable.

## 1. Controller topology on the MS-R1

The DSDT describes ten CIX USB port groups: six `\_SB.SUB0`-`SUB5`
(SuperSpeed-capable) and four `\_SB.HUB0`-`HUB3` (USB 2.0 high-speed
only). Each group has a `CIXH2030` CDNSP wrapper and a child `CIXH2031`
Cadence USBSSP host controller (driver `cdns-usbssp`), which creates the
xHCI host.

| Port group | ACPI path | ACPI `maximum-speed` | Role | USB3 PHY | xHCI / USB buses |
|---|---|---|---|---|---|
| SUB0 | `\_SB.SUB0` | `super-speed-plus` | OTG (Type-C) | `UCP0.USBP` (`CIXH2033:00`, USBDP) | `xhci-hcd.16`: usb13 (2.0), usb14 (3.x) |
| SUB1 | `\_SB.SUB1` | `super-speed-plus` | OTG (Type-C) | `UCP1.USBP` (`CIXH2033:01`, USBDP) | no xHCI child while role = none |
| SUB2 | `\_SB.SUB2` | `super-speed-plus` | host | `UCP2.USBP` (`CIXH2033:02`, USBDP) | `xhci-hcd.12`: usb5, usb6 |
| SUB3 | `\_SB.SUB3` | `super-speed-plus` | host | `UCP3.USBP` (`CIXH2033:03`, USBDP) | `xhci-hcd.13`: usb7, usb8 |
| SUB4 | `\_SB.SUB4` | `super-speed-plus` | host | `U3P4.USB0` (`CIXH2034:00`, USB3) | `xhci-hcd.14`: usb9, usb10 |
| SUB5 | `\_SB.SUB5` | `super-speed-plus` | host | `U3P4.USB1` (`CIXH2034:00`, USB3) | `xhci-hcd.15`: usb11, usb12 |
| HUB0-3 | `\_SB.HUB0`-`HUB3` | `high-speed` | host | none | `xhci-hcd.8`-`.11`: usb1-usb4 |

Board documentation lists 2× full-featured USB-C (USB data up to 10 Gbps
+ DP 1.4), 3× USB 3.2 Gen2 10 Gbps Type-A, 4× USB 2.0 Type-A and one
M.2 E-key socket with USB support. The six `SUB` ports are the 10 Gbps
ports (2 Type-C + 3 Type-A + M.2 E-key USB); `HUB0-3` are the USB 2.0
ports. All six `SUB` controllers are declared `maximum-speed =
"super-speed-plus"` by firmware.

The current USB-SATA enclosure chain is attached to **SUB0 (the first
Type-C port)**: `usb_role/CIXH2031:00-role-switch` reports `host`,
`xhci-hcd.16` owns buses 13/14, and the chain is:

```
usb14 (root, xHCI, 10000M advertised)
└─ 14-1   AS2107 hub (174c:3174)      5000M
   ├─ 14-1.1 AS2107 hub               5000M
   │  ├─ 14-1.1.1 ASM235CM SATA bridge  5000M
   │  ├─ 14-1.1.2 ASM235CM SATA bridge  5000M
   │  ├─ 14-1.1.3 ASM235CM SATA bridge  5000M
   │  └─ 14-1.1.4 ASM235CM SATA bridge  5000M
   └─ 14-1.2 AS2107 hub               5000M
      ├─ 14-1.2.1 ASM235CM SATA bridge  5000M
      ├─ 14-1.2.2 ASM235CM SATA bridge  5000M
      └─ 14-1.2.3 ASM235CM SATA bridge  5000M
```

There are seven ASM235CM bridges in total (the other USB2 companion hubs
are `174c:2174`, product AS2107). The xHCI hosts report
`Host supports USB 3.1 Enhanced SuperSpeed` and HCI version `0x110`; the
USB3 root hub devices report `bcdUSB 3.10`, `speed=10000M`.

## 2. Why every link is 5 Gbps today

`cdnsp_sky1_probe()` in the vendor wrapper (`cdnsp-sky1.c`) does:

```c
data->ssp_disable = device_property_read_bool(dev, "ssp-disable");
/* 6.18/7.1/7.3 overlay hardening: force it off regardless of firmware */
data->ssp_disable = true;
```

and `cdnsp_sky1_drd_init()` then clears bit 31 of
`XEC_CFG_3XPORT_MODE`:

```c
#define XEC_CFG_3XPORT_MODE          0x2040
#define XEC_CFG_3XPORT_MODE_VALUE    0xa0031e07   /* bit31 set = SSP enabled */
#define CFG_3XPORT_MODE_DIS_SSP      (~(1 << 31))
...
writel(v0 & CFG_3XPORT_MODE_DIS_SSP, data->xhci_base + XEC_CFG_3XPORT_MODE);
```

Boot logs on both kernels show it firing for all `SUB` controllers:

```
cdnsp-sky1 CIXH2030:00: SSP disabled: XEC_CFG_3XPORT_MODE 0xa0031e00 -> 0x20031e00
cdnsp-sky1 CIXH2030:00: CIX CDNSP-sky1 wrapper id=0 started (u3-disable=0 ssp-disable=1)
...
(the same for id 1-5; HUB0-3 are USB2-only and log 0x0 -> 0x0)
```

This is the overlay's `0086` (7.1) / `0162` (7.3) workaround, originally
from the vendor tree. Its commit message is explicit: *sustained 10 Gbps
I/O on the MS-R1's CDNSP/cix-usbdp-phy stack produced periodic device
resets under load; capping at Gen1 has proven stable; the root cause was
not conclusively identified.*

Consequences:

* The xHCI **host controller capability** is still SSP, so the root hub
  advertises `10000M`; this is capability, not the negotiated port mode.
* The actual link training of every downstream device is Gen1, hence
  `new SuperSpeed USB device` (not `SuperSpeedPlus`) and
  `speed=5000` for all hubs/bridges.
* The devices themselves are not the bottleneck: AS2107 hubs advertise
  SuperSpeedPlus with 10 Gb/s RX/TX speed attributes, and ASM235CM
  bridges advertise `bcdUSB 3.20`, SSP 10 Gb/s and expose both a
  Bulk-Only (protocol 80) and UAS (protocol 98) interface.

## 3. What is already 10G-capable

| Layer | Evidence |
|---|---|
| ACPI / firmware | `maximum-speed = "super-speed-plus"` on `SUB0`-`SUB5` |
| xHCI host controller | HCI version `0x110`, `Host supports USB 3.1 Enhanced SuperSpeed` |
| USB3 PHYs | `phy-cix-usb3.c` and `phy-cix-usbdp.c` contain USB3 Gen2 PIPE tuning tables; `CIXH2034` is a dual-port USB3 PHY, `CIXH2033` are USB-DP PHYs |
| Hub | AS2107 descriptors list `10Gb/s Symmetric RX/TX SuperSpeedPlus` |
| SATA bridge | ASM235CM: USB 3.2 Gen2x1 to SATA 6 Gbps, supports UASP and BOT ([ASMedia](https://www.asmedia.com.tw/product/767Yq28sxFYMEgu4/3AbyQ83xZAUr3qW5.html)) |
| Board ports | 2× USB-C 10 Gbps, 3× USB-A 10 Gbps ([MS-R1 docs](https://github.com/minisforum-docs/MS-R1-Docs/blob/main/PlayBook/Korean/MS-R1-BaseGuide.md)) |

The remaining blockers are therefore software configuration (SSP bit),
cabling/link-training, and the unresolved 10 Gbps stability issue — not
missing hardware capability.

## 4. UAS vs Bulk-Only: the throughput side

Link speed alone is not enough for 10 Gbps storage:

* **7.1.5 reference kernel** boots with
  `usb-storage.quirks=174c:55aa:u`; the `u` flag disables UAS, so the
  ASM235CM bridges bind `usb-storage` BOT at protocol 80. BOT serializes
  commands and cannot saturate a 10 Gbps link.
* **7.3.1 test boot** (no quirk in `/etc/kernel/cmdline`) bound `uas`
  (`scsi hostN: uas`) to all seven bridges; `usb_storage` remains only
  as a dependency. That is the desired default for a 10 Gbps setup.
* The 7.3.1 boot log also shows one `uas_eh_abort_handler` +
  `uas_eh_host_reset_handler` on `0:0:0:0` at t=33.8 s, followed by a
  successful reset and disk attach. That is exactly the class of event
  to watch when testing 10 Gbps: it can be a one-off probe/power-up
  effect or the early symptom of the instability that motivated the SSP
  cap.

Note the SATA-side ceiling: ASM235CM is USB 3.2 Gen2x1 to **SATA
6 Gbps**. A single SATA SSD tops out around 550 MB/s (~4.4 Gbps) and a
single HDD much lower, so "10 Gbps to the bridge" mainly buys:

* full SATA III bandwidth per fast SSD (instead of ~450 MB/s under a 5
  Gbps USB link), and
* more aggregate upstream bandwidth for the seven drives behind the
  AS2107 hub tree (the hub's upstream link is shared).

For USB-NVMe bridges (ASM2362/RTL9210-class), 10 Gbps gives the full
~1 GB/s that SATA cannot.

## 5. Proposed path to 10 Gbps

This round produced analysis only; no USB build/behaviour changes were
made, because the reference MS-R1 is an active Ceph node and the 10 Gbps
mode itself is the known-unstable path.

### 5.1 Kernel: make SSP opt-in, default stable

Replace the unconditional override with a boot/module parameter so SSP
can be enabled for testing and left off by default until validated:

```c
/* cdnsp-sky1.c, sketch only */
static bool cix_usb_ssp_enable;
module_param_named(cix_usb_ssp_enable, cix_usb_ssp_enable, bool, 0444);
MODULE_PARM_DESC(cix_usb_ssp_enable, "Allow SuperSpeedPlus on CIX USBSSP ports");

...
data->ssp_disable = device_property_read_bool(dev, "ssp-disable");
if (!cix_usb_ssp_enable)
        data->ssp_disable = true;   /* keep current safe default */
```

`XEC_CFG_3XPORT_MODE` then keeps bit 31 set and the host can train SSP.
A per-controller allow-list (id 0-5 only) is preferable to all-or-nothing
for the first tests. Do the same review for the device-side
`D_XEC_CFG_3XPORT_MODE` write if peripheral mode is ever needed; the
current plan is host-mode only.

Because the parameter is built-in (`CONFIG_USB_CDNSP_SKY1=y`), pass
`cix_usb_ssp_enable=1` on the kernel command line for the experiment; no
feature is enabled on a normal boot.

### 5.2 Test sequence (single maintenance window)

1. Boot the patched kernel with `cix_usb_ssp_enable=1` via one-time
   UEFI `BootNext` (same procedure as doc 07), leaving the production
   entry untouched.
2. Check `dmesg | grep SSP` (no "SSP disabled" for SUB0), `lsusb -t`
   (`10000M` on the hub/bridges), and `dmesg | grep SuperSpeedPlus`.
3. Start with **one bridge directly on the port**, no hub chain, using a
   known 10 G-rated cable. Confirm 10 G link before adding the hub tree.
4. Test the hub tree on the Type-C SUB0 port and on a Type-A 10 G port
   (SUB2/3/4). Record which physical port is which.
5. With UAS active, run `fio`/`dd` direct I/O at queue depth >1 on one
   drive and then several drives in parallel; capture throughput and
   `dmesg -w`.
6. Acceptance: link stays at `10000M` for 30+ min of sustained I/O with
   no `uas_eh_*`, xHCI reset/`-71`/`-110` errors, no AER/SError, and no
   device disappearance.
7. On any reset: capture full dmesg, `lsusb -t`, `/sys/kernel/debug/usb/
   devices`, xHCI port registers if available, and the exact workload;
   fall back to 5 G and bisect the cause.

### 5.3 Suspected causes to investigate if 10 G is still unstable

The vendor workaround notes did not identify a root cause. Candidates,
in rough order of likelihood/value:

1. **PHY/Gen2 signal tuning** — `phy-cix-usbdp.c` / `phy-cix-usb3.c`
   carry Gen2 PIPE tables, but the vendor 10 G path was never validated
   end-to-end. Compare register dumps between 5 G and 10 G link training.
2. **AXI burst/bandwidth** — DSDT supplies `axi_bmax_value = 0x07`;
   verify whether 10 G needs a larger burst/outstanding setting
   (`sof_clk_freq`/`lpm_clk_freq` are also firmware-provided).
3. **LPM (U1/U2)** — the deferred `xhci-plat` patch in
   `files/7.3/usb-host-xhci-plat-acpi-lpm-autodetect.patch.deferred`
   would enable U1/U2 on ACPI hosts; test both LPM-off and LPM-on. Long
   idle/active transitions are a classic SSP hub failure source.
4. **Cable/connector/hub-chain** — a 5 G-rated cable or an extra hub hop
   can force 5 G or cause training retries even with SSP enabled. Test
   direct, then one hub, then the full tree.
5. **UAS/bridge firmware** — ASM235CM UAS is known to need
   `uas`-specific quirks on some firmware revisions. Compare BOT vs UAS
   at 5 G first (isolates UAS from SSP), then at 10 G.
6. **Power/thermal/USB-C orientation** — Type-C SBU/orientation and PD
   (RTS5453) state can affect the SuperSpeed lanes; test both cable
   orientations and a Type-A port.

### 5.4 Hardware recommendations

* Use a USB 3.2 Gen2 (10 Gbps) certified cable for the first link; the
  current enclosure's cable is unknown and the current 5 G result is
  explained by SSP-disable, but a bad cable will mask success once SSP
  is enabled.
* Prefer a direct connection for the initial test; each AS2107 hop must
  itself negotiate 10 G for the whole chain to benefit.
* Expect per-drive SATA III (~550 MB/s) as the individual ceiling; 10 G
  is most valuable for fast SATA SSDs and for aggregate multi-drive
  throughput.

## 6. Current vs target

| Property | Current (7.1.5 / 7.3.1) | Target |
|---|---|---|
| SSP bit in `XEC_CFG_3XPORT_MODE` | cleared (disabled) | set on tested port(s) |
| Root hub / device link | 10G advertised / 5G trained | 10G trained |
| Hub/bridge link | 5000M | 10000M |
| Storage driver | BOT on 7.1.5; UAS on 7.3.1 | UAS |
| Kernel default | stable 5G | 5G default, opt-in 10G until validated |
| Per-drive throughput | SATA- or 5G-limited | SATA III-limited (~550 MB/s) |

## 7. References

* [ASMedia ASM235CM — 10G SATA device](https://www.asmedia.com.tw/product/767Yq28sxFYMEgu4/3AbyQ83xZAUr3qW5.html)
* [Minisforum MS-R1 base guide (port list)](https://github.com/minisforum-docs/MS-R1-Docs/blob/main/PlayBook/Korean/MS-R1-BaseGuide.md)
* [ServeTheHome MS-R1 overview](https://www.servethehome.com/the-minisforum-ms-r1-12-core-arm-10gbe-mini-workstation-is/)
* Vendor/overlay SSP workaround: `files/7.3/0162-usb-cdns3-sky1-force-disable-superspeedplus.patch`,
  `files/7.1/0086-usb-cdns3-sky1-force-disable-superspeedplus.patch`; prior
  audit `01-vendor-coverage.md` G1.
