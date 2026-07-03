# VM Bridge Networking on Gentoo

pxvirt's networking layer (`pve-network`) was designed around Debian's `ifupdown2` and
`/etc/network/interfaces`. Gentoo does not ship `ifupdown2`, so VM bridges must be
configured through the system's own network manager. This document covers both
**systemd-networkd** and **NetworkManager** approaches.

---

## Background: What pve-network Needs

pxvirt creates a Linux bridge (`vmbr0` by default) and attaches VMs/containers to it as
virtual tap interfaces. The host's physical NIC is also enslaved to the bridge so that
VMs share the host's uplink. Key requirements:

1. A persistent bridge device (`vmbr0`) created at boot.
2. A physical NIC enslaved to the bridge (for external connectivity).
3. The host IP assigned to the bridge, **not** the physical NIC.
4. VLAN-aware bridge mode for SDN/VLAN scenarios (optional).
5. Additional bridges for isolated networks (no physical NIC, VM-only).

---

## Option A: systemd-networkd

systemd-networkd manages network devices via `.netdev` and `.network` unit files in
`/etc/systemd/network/`. This is the lightest-weight approach and integrates well with
`systemd` (pxvirt's init system of choice).

### 1. Enable systemd-networkd

```bash
systemctl enable --now systemd-networkd
systemctl enable --now systemd-resolved   # optional but recommended
```

Disable any competing network managers (NetworkManager, dhcpcd, netifrc):

```bash
systemctl disable NetworkManager
rc-update del netifrc default   # if using OpenRC
```

### 2. Create the bridge device

`/etc/systemd/network/10-vmbr0.netdev`

```ini
[NetDev]
Name=vmbr0
Kind=bridge

[Bridge]
# Enable VLAN filtering for SDN/VLAN support (optional)
VLANFiltering=yes
STP=no
```

### 3. Assign an IP to the bridge

`/etc/systemd/network/20-vmbr0.network`

```ini
[Match]
Name=vmbr0

[Network]
# Static IP — adjust to your environment
Address=192.168.1.10/24
Gateway=192.168.1.1
DNS=1.1.1.1
DNS=8.8.8.8

# Or use DHCP:
# DHCP=ipv4
```

### 4. Enslave the physical NIC to the bridge

Replace `eth0` with your actual interface name (check `ip link`).

`/etc/systemd/network/30-eth0-bridge.network`

```ini
[Match]
Name=eth0

[Network]
Bridge=vmbr0

# Ensure the NIC itself has no IP — the bridge holds it
LinkLocalAddressing=no
DHCP=no
```

### 5. Reload and verify

```bash
networkctl reload
networkctl status vmbr0
ip addr show vmbr0
brctl show vmbr0
```

Expected: `vmbr0` is UP with your IP, `eth0` shown as a bridge port with no IP.

### 6. Isolated VM-only bridge (no uplink)

For internal-only networks (e.g., `vmbr1`):

`/etc/systemd/network/11-vmbr1.netdev`

```ini
[NetDev]
Name=vmbr1
Kind=bridge

[Bridge]
STP=no
```

`/etc/systemd/network/21-vmbr1.network`

```ini
[Match]
Name=vmbr1

[Network]
# No address — VMs handle their own IPs on this segment
LinkLocalAddressing=no
```

### 7. VLAN bridge (802.1Q trunk)

To carry tagged VLANs across a trunk port into VMs:

`/etc/systemd/network/10-vmbr0.netdev`

```ini
[NetDev]
Name=vmbr0
Kind=bridge

[Bridge]
VLANFiltering=yes
STP=no
```

Then for each VM's tap interface at runtime, pve-network handles the per-port VLAN config
via the `ip link` / `bridge vlan` commands — no additional `.netdev` files needed.

---

## Option B: NetworkManager

NetworkManager is more common on desktop-oriented Gentoo installs. It can manage bridges
via `nmcli` or connection profiles.

### 1. Install and enable

```bash
emerge --ask net-misc/networkmanager
systemctl enable --now NetworkManager
```

Disable competing managers:

```bash
systemctl disable systemd-networkd
systemctl disable dhcpcd
```

### 2. Create the bridge

```bash
nmcli connection add \
  type bridge \
  con-name vmbr0 \
  ifname vmbr0 \
  bridge.stp no
```

### 3. Assign a static IP to the bridge

```bash
nmcli connection modify vmbr0 \
  ipv4.method manual \
  ipv4.addresses 192.168.1.10/24 \
  ipv4.gateway 192.168.1.1 \
  ipv4.dns "1.1.1.1,8.8.8.8"
```

Or use DHCP:

```bash
nmcli connection modify vmbr0 ipv4.method auto
```

### 4. Enslave the physical NIC

```bash
nmcli connection add \
  type ethernet \
  con-name eth0-bridge \
  ifname eth0 \
  master vmbr0
```

### 5. Bring everything up

```bash
nmcli connection up vmbr0
nmcli connection up eth0-bridge
```

Verify:

```bash
nmcli device status
ip addr show vmbr0
bridge link show
```

### 6. Isolated VM-only bridge

```bash
nmcli connection add \
  type bridge \
  con-name vmbr1 \
  ifname vmbr1 \
  bridge.stp no \
  ipv4.method disabled \
  ipv6.method disabled

nmcli connection up vmbr1
```

### 7. VLAN bridge

NetworkManager supports VLAN-filtering bridges:

```bash
nmcli connection modify vmbr0 bridge.vlan-filtering yes
nmcli connection up vmbr0
```

Tagged VLAN sub-interfaces for the host itself (if needed):

```bash
nmcli connection add \
  type vlan \
  con-name vmbr0.100 \
  ifname vmbr0.100 \
  dev vmbr0 \
  id 100 \
  ipv4.method manual \
  ipv4.addresses 10.100.0.1/24
```

---

## Comparison

| Feature | systemd-networkd | NetworkManager |
|---------|-----------------|----------------|
| Config format | `.netdev` / `.network` files | nmcli / keyfile profiles |
| Headless server | ✅ Ideal | ✅ Workable |
| Desktop integration | ❌ No applet | ✅ Full GUI/applet support |
| VLANs | ✅ Supported | ✅ Supported |
| Bonds | ✅ `.netdev` Kind=bond | ✅ `nmcli type bond` |
| Low overhead | ✅ Minimal | ⚠️ Heavier daemon |
| pve-network plugin | Write custom `plugin_systemd` | Write custom `plugin_nm` |

**Recommendation for headless ARM/LoongArch servers:** Use systemd-networkd. It requires no
additional packages beyond what a base systemd Gentoo install provides.

---

## pve-network Integration

`pve-network` (libpve-network-perl) abstracts network configuration through pluggable
backends. On Debian it calls `ifupdown2`. On Gentoo, a custom backend module must be
written (or `pve-network` called with the `--dry-run` / file-generation mode only, with
the host network manager reading the resulting configuration).

Two approaches:

### A. File-generation mode (simpler)
Configure `pve-network` to write network config files to a staging directory, then have
a small service (oneshot systemd unit) apply them by copying into
`/etc/systemd/network/` and reloading `networkctl`.

### B. Custom plugin (more complete)
Write a Perl plugin module for `pve-network` that calls `networkctl` / `nmcli` directly
instead of `ifupdown2`. This requires modifying `pve-network`'s plugin dispatch table.

See `packages/pve-network.md` for implementation notes.

---

## Kernel Requirements

Ensure your kernel has these options enabled (all required for bridging):

```
CONFIG_BRIDGE=y
CONFIG_BRIDGE_NETFILTER=y
CONFIG_VLAN_8021Q=y
CONFIG_VLAN_8021Q_GVRP=y
CONFIG_NET_SCH_INGRESS=y
CONFIG_NET_CLS_U32=y
CONFIG_NETFILTER_XT_MATCH_PHYSDEV=y
```

For VLAN-filtered bridges (SDN):

```
CONFIG_BRIDGE_VLAN_FILTERING=y
```
