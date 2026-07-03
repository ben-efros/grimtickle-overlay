# pve-network Gentoo Port — Modification Document

**Version**: upstream proxmox.com `libpve-network-perl` 1.1.8 (2025-09-16)
**Package**: `dev-perl/libpve-network-perl`
**Status**: Ebuild written, **network backend plugin deferred** (see §4)

---

## 1. Package Overview

`libpve-network-perl` is the Proxmox VE SDN (Software-Defined Networking) library.
It manages *overlay* networks — VLAN tags, VxLAN tunnels, EVPN/BGP routing,
WireGuard fabrics, IPAM, and DNS/DHCP integration for tenant networks.

**It does NOT manage the host's physical interfaces or main VM bridge (vmbr0).**
That responsibility belongs to `PVE::INotify` in `libpve-common-perl`.

### 1.1 Module hierarchy

| Module path | Role |
|---|---|
| `PVE::Network::SDN` | Top-level orchestration |
| `PVE::Network::SDN::Zones/*` | Zone plugins: VLAN, VxLAN, EVPN, QinQ, Simple, Faucet |
| `PVE::Network::SDN::Controllers/*` | Routing daemons: BGP, EVPN (FRR), ISIS, Faucet |
| `PVE::Network::SDN::Ipams/*` | IPAM: PVE built-in, NetBox, phpIPAM |
| `PVE::Network::SDN::Dns/*` | DNS: PowerDNS plugin |
| `PVE::Network::SDN::Dhcp/*` | DHCP: Dnsmasq via D-Bus (Net::DBus) |
| `PVE::Network::SDN::Fabrics` | WireGuard fabric (pxvirt addition; upstream since 9.x) |
| `PVE::API2::Network::SDN/*` | REST API endpoints |

### 1.2 pxvirt vs upstream

pxvirt ships version 1.1.8 — **identical to upstream**. This is a vanilla upstream
package. No pxvirt-specific patches were applied. No patches needed for the ebuild.

---

## 2. What pve-network Does and Does Not Touch

### 2.1 SDN configuration files (what this package manages)

The SDN layer generates `/etc/network/interfaces.d/sdn` — a Debian ifupdown2
snippet. On Debian, `ifupdown2` applies it automatically. On Gentoo, this file
must be processed by the **network backend plugin** (see §4).

```
/etc/network/interfaces.d/sdn   ← written by PVE::Network::SDN::Zones
/etc/frr/                        ← FRR (BGP/EVPN) config for EVPN zones
/etc/dnsmasq.d/                  ← DHCP ranges for SDN vnets
```

### 2.2 Host bridge (NOT managed by this package)

The host bridge `vmbr0` is managed by `PVE::INotify` in `libpve-common-perl`.
`PVE::INotify` reads/writes `/etc/network/interfaces` (Debian format).

On Gentoo this is the **primary adaptation challenge** — Gentoo manages network
interfaces via systemd-networkd (`.network` files), NetworkManager, or `netifrc`
(Gentoo's own init-script system). None of these use `/etc/network/interfaces`.

---

## 3. Dependency Analysis

All deps are in the Gentoo ::gentoo tree or already in this overlay:

| Module | Gentoo atom | Status |
|---|---|---|
| `JSON` | `dev-perl/JSON` | ::gentoo |
| `LWP::UserAgent` | `dev-perl/LWP-UserAgent` | ::gentoo |
| `Net::DBus` | `dev-perl/Net-DBus` | ::gentoo |
| `Net::IP` | `dev-perl/Net-IP` | ::gentoo |
| `Net::SSLeay` | `dev-perl/Net-SSLeay` | ::gentoo |
| `Net::Subnet` | `dev-perl/Net-Subnet` | ::gentoo |
| `NetAddr::IP` | `dev-perl/NetAddr-IP` | ::gentoo |
| `UUID` | `dev-perl/UUID` | ::gentoo |
| `Digest::SHA` | `virtual/perl-Digest-SHA` | ::gentoo |
| `MIME::Base64` | `virtual/perl-MIME-Base64` | ::gentoo |
| `CPAN::Meta::YAML` | `dev-perl/CPAN-Meta` | ::gentoo (USE=faucet only) |
| `PVE::*` | dev-perl/libpve-{common,access-control,cluster}-perl | this overlay |

---

## 4. The Network Backend Adaptation — Architecture Decision

### 4.1 The problem

PVE's network management is split across two places:

1. **`PVE::INotify`** (in `libpve-common-perl`) — reads and writes
   `/etc/network/interfaces` to configure the host's physical and bridge
   interfaces. Also calls `ifreload -a` (ifupdown2) to apply changes.

2. **`libpve-network-perl`** (this package) — writes SDN overlay config
   to `/etc/network/interfaces.d/sdn` and calls `ifreload -a` to apply.

Gentoo does not have ifupdown2 or `/etc/network/interfaces` as a first-class tool.

### 4.2 Three Gentoo network management approaches

| Approach | Config files | Hot-reload | Notes |
|---|---|---|---|
| **systemd-networkd** | `/etc/systemd/network/*.network` | `networkctl reload` | Gentoo default with systemd |
| **NetworkManager** | via nmcli/keyfile | `nmcli` | GUI-friendly, common on desktops |
| **netifrc** | `/etc/conf.d/net` | `rc-service net.vmbr0 restart` | Gentoo traditional, OpenRC |

### 4.3 Chosen strategy: two-layer adaptation

**Layer 1 (Phase 1 — immediate):** Provide a **thin compatibility shim** that lets
the existing PVE::INotify write `/etc/network/interfaces` as it does now, but instead
of calling `ifreload`, the shim translates the interface config to the active Gentoo
backend and applies it. This shim is packaged as `net-misc/pve-network-backend`.

**Layer 2 (Phase 2 — future):** Full native plugin in `PVE::INotify` that bypasses
the `/etc/network/interfaces` intermediary entirely and writes directly to the
Gentoo backend format.

### 4.4 Phase 1 shim: pve-network-backend

The shim (`/usr/sbin/pve-ifreload`) replaces `ifreload -a`:
- Reads `/etc/network/interfaces` and `/etc/network/interfaces.d/sdn`
- Converts ifupdown syntax to the target backend format
- Applies the configuration using the backend's tool

For `systemd-networkd` backend:
```
# /etc/network/interfaces (PVE writes this)
auto vmbr0
iface vmbr0 inet static
    address 192.168.1.10/24
    gateway 192.168.1.1
    bridge-ports eth0
    bridge-stp off
    bridge-fd 0

# Translated to: /run/systemd/network/10-vmbr0.network
[Match]
Name=vmbr0
[Network]
Address=192.168.1.10/24
Gateway=192.168.1.1
[Bridge]
STP=no
ForwardDelaySec=0
```

### 4.5 What does NOT need adaptation

- SDN zone config (VxLAN, EVPN): `PVE::Network::SDN::Zones` writes kernel-level
  `ip link` commands to FRR/systemd-networkd — these work identically on Gentoo
- FRR (BGP/EVPN routing): standard system daemon, same on all distros
- DHCP/Dnsmasq: ditto
- IPAM/DNS plugins: pure API logic, no OS-specific calls

### 4.6 netifrc integration (OpenRC systems)

For OpenRC + netifrc, Gentoo's existing `/etc/init.d/net.*` system handles
bridges via `/etc/conf.d/net`:
```
bridge_vmbr0="eth0"
config_vmbr0="192.168.1.10/24"
routes_vmbr0="default via 192.168.1.1"
```
The shim can generate this format instead of `.network` files when OpenRC is detected.

---

## 5. Gentoo-Specific Changes in This Ebuild

| Change | Reason |
|---|---|
| `USE=faucet` gates `FaucetPlugin.pm` install | Faucet is an OpenFlow SDN controller (rarely used, pulls `CPAN::Meta::YAML`) |
| systemd dnsmasq drop-in installed unconditionally | Harmless on OpenRC (OpenRC dnsmasq doesn't read systemd drop-ins) |
| `ifreload` not in RDEPEND | `ifreload` is part of ifupdown2 (not on Gentoo); replaced by `pve-network-backend` |

---

## 6. Functional Limitations (Gentoo)

| Limitation | Impact | Mitigation |
|---|---|---|
| **No ifupdown2** | SDN zone apply (`ifreload -a`) fails without backend shim | `net-misc/pve-network-backend` provides replacement |
| **Host bridge via /etc/network/interfaces** | PVE::INotify writes this file; nothing applies it | Same shim reads and translates it |
| **pve-network-backend not yet written** | SDN network apply broken until Phase 2 | Phase 1: manual bridge creation; document workaround |
| **SDN Faucet plugin removed (unless USE=faucet)** | No OpenFlow SDN | Rare enterprise feature; opt-in |

---

## 7. Deferred Work

| Item | Priority | Ticket |
|---|---|---|
| `net-misc/pve-network-backend` shim package | HIGH — blocks SDN and VM networking | `network-backend-plugin` SQL todo |
| Full native `PVE::INotify` Gentoo backend | MEDIUM — cleaner long-term | After Phase 1 validated |
| netifrc config generator in shim | LOW — for non-systemd users | Phase 3 |
