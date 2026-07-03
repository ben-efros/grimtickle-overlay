# pve-firewall → net-firewall/pve-firewall

## Overview

`pve-firewall` is the pxvirt firewall daemon. It generates and applies nftables/iptables
rules for the datacenter, individual hosts, VMs, and containers. Rules are defined in
`/etc/pve/firewall/` and synced across the cluster.

## Upstream

- **pxvirt source:** `packages/pve-firewall/pve-firewall/`
- **Debian package:** `pve-firewall`
- **Build system:** Makefile + Perl

## Portage Atom

```
net-firewall/pve-firewall
```

## Key Dependencies

| Debian | Gentoo atom |
|--------|-------------|
| `libpve-common-perl` | `dev-perl/libpve-common-perl` |
| `libpve-cluster-perl` | `sys-cluster/pve-cluster` |
| `conntrack` | `net-firewall/conntrack-tools` |
| `nftables` | `net-firewall/nftables` |
| `iptables` | `net-firewall/iptables` (legacy fallback) |

## USE Flags

| Flag | Effect |
|------|--------|
| `nftables` | Use nftables backend (recommended, default) |

## Ebuild Notes

- Use `inherit perl-module`
- systemd unit: `pve-firewall.service`
- Firewall rules stored in `/etc/pve/firewall/` (cluster-synchronized)
- On Gentoo, nftables is preferred over iptables

## Architecture Notes

Pure Perl; arch-independent (`KEYWORDS="~arm64 ~loong ~amd64"`).

## Notes

pve-firewall can operate without pve-cluster (Phase 3) — it will only manage host-local
rules if the cluster filesystem is not mounted.
