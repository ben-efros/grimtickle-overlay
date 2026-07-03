# pve-network → net-misc/libpve-network-perl

## Overview

`pve-network` is the pxvirt network configuration layer. It manages Linux bridges, bonds,
VLANs, and SDN (Software Defined Networking) configurations. On Debian it drives
`ifupdown2`; on Gentoo a custom backend is required.

## Upstream

- **pxvirt source:** `packages/pve-network/pve-network/`
- **Debian packages:** `libpve-network-perl`, `libpve-network-api-perl`
- **Build system:** Makefile + Perl

## Portage Atoms

```
net-misc/libpve-network-perl
```

## Key Dependencies

| Debian | Gentoo atom | Notes |
|--------|-------------|-------|
| `libpve-common-perl` | `dev-perl/libpve-common-perl` | |
| `ifupdown2` | — | **Not available on Gentoo — see below** |
| `bridge-utils` | `net-misc/bridge-utils` | `brctl` for bridge management |
| `frr` | `net-misc/frr` | USE=frr; for BGP/EVPN SDN |
| `vlan` | `net-misc/vconfig` | VLAN tools |
| `ethtool` | `sys-apps/ethtool` | NIC feature detection |

## Gentoo Networking Backend

`pve-network` uses a plugin dispatch table to select its network backend. The Debian
backend calls `ifupdown2`'s `ifreload` / `ifquery` commands. On Gentoo:

### Option A: File-generation + systemd-networkd reload

Write a Perl plugin (`PVE::Network::Plugin::SystemdNetworkd`) that:
1. Generates `.netdev` and `.network` files in `/etc/systemd/network/`
2. Calls `networkctl reload` to apply them

### Option B: File-generation + NetworkManager

Write a Perl plugin (`PVE::Network::Plugin::NetworkManager`) that:
1. Calls `nmcli connection add/modify/delete` to manage connections
2. Calls `nmcli connection up/down` to apply changes

See [networking.md](../networking.md) for full details on both backends.

## USE Flags

| Flag | Effect |
|------|--------|
| `frr` | Pulls in `net-misc/frr` for BGP/EVPN SDN support |
| `systemd-networkd` | Activates systemd-networkd backend plugin |
| `networkmanager` | Activates NetworkManager backend plugin |

## Ebuild Notes

- Install both `libpve-network-perl` and `libpve-network-api-perl` from the same source
- The custom Gentoo backend plugin should be installed as a patch or additional source file
- Config lives in `/etc/pve/sdn/` (runtime, managed by pve-cluster)

## Architecture Notes

Pure Perl; arch-independent (`KEYWORDS="~arm64 ~loong ~amd64"`).
