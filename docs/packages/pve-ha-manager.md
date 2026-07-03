# pve-ha-manager → sys-cluster/pve-ha-manager

## Overview

`pve-ha-manager` implements High Availability (HA) resource management for pxvirt clusters.
It monitors cluster members, detects node failures, and automatically restarts VMs and
containers on surviving nodes. It uses Corosync quorum for fencing decisions.

## Upstream

- **pxvirt source:** `packages/pve-ha-manager/pve-ha-manager/`
- **Debian packages:** `pve-ha-manager`, `pve-ha-simulator` (testing tool)
- **Build system:** Makefile + Perl

## Portage Atom

```
sys-cluster/pve-ha-manager
```

## Key Dependencies

| Debian | Gentoo atom |
|--------|-------------|
| `pve-cluster` | `sys-cluster/pve-cluster` |
| `libpve-common-perl` | `dev-perl/libpve-common-perl` |
| `libpve-cluster-perl` | `sys-cluster/pve-cluster` |
| `libjson-perl` | `dev-perl/JSON` |
| `libclone-perl` | `dev-perl/Clone` |

## Ebuild Notes

- Use `inherit perl-module`
- systemd units: `pve-ha-lrm.service` (Local Resource Manager), `pve-ha-crm.service`
  (Cluster Resource Manager)
- `pve-ha-simulator` can be installed under a `test` USE flag

## HA Resource Configuration

Resources are configured via the web UI or:

```bash
ha-manager add vm:100 --state started
ha-manager add ct:200 --state started --max_restart 3
```

HA groups and fencing policies are configured in `/etc/pve/ha/`.

## Architecture Notes

Pure Perl; arch-independent (`KEYWORDS="~arm64 ~loong ~amd64"`).

## Notes

HA requires a minimum of 3 nodes (or 2 nodes + a QDevice) for reliable quorum. Do not
enable HA on a 2-node cluster without a QDevice — node failure may cause both nodes to
fence each other.
