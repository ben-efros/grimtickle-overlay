# pve-manager → sys-apps/pve-manager

## Overview

`pve-manager` is the top-level pxvirt management package. It provides:
- `pvedaemon` — the main API daemon (listens on a unix socket)
- `pveproxy` — the HTTPS reverse proxy (port 8006)
- `pvestatd` — statistics daemon
- The web UI (assembled from extjs + proxmox-widget-toolkit + pxvirt-specific JS)
- CLI tools: `pvesh`, `pveceph`, `pvesubscription`, etc.

## Upstream

- **pxvirt source:** `packages/pve-manager/pve-manager/`
- **Debian package:** `pve-manager`
- **Build system:** Makefile + Perl

## Gentoo-Specific Patches Required

### Patch 1: Stub `PVE::API2::APT` (startup blocker)

`PVE/API2/Nodes.pm` line 42 contains a compile-time `use PVE::API2::APT`, which
in turn requires `AptPkg::Cache` (from `libapt-pkg-perl`). This Debian-only library
does not exist on Gentoo. Without patching, **`pvedaemon` crashes at startup**.

**Patch:** `files/0001-Gentoo-stub-PVE-API2-APT-libapt-pkg-perl-unavailable.patch`

This patch replaces `PVE/API2/APT.pm` with a stub that:
- Satisfies `Nodes.pm`'s `use PVE::API2::APT` without crashing
- Returns HTTP 501 for all `/nodes/{node}/apt/*` endpoints with a message
  directing users to use `emerge` instead

**Affected features** (unavailable on Gentoo — Debian-only):
- Web UI "Updates" tab: package update check / apply
- `pvesh get /nodes/{node}/apt/versions`
- Repository management via web UI

**Unaffected:** All VM, CT, storage, user, network, firewall management.

See `docs/perl-module-audit.md` for full analysis.


sys-apps/pve-manager
```

## Key Dependencies

All Phase 1 packages, plus:

| Debian | Gentoo atom | Notes |
|--------|-------------|-------|
| `libpve-common-perl` | `dev-perl/libpve-common-perl` | |
| `libpve-http-server-perl` | `dev-perl/libpve-http-server-perl` | |
| `libpve-access-control` | `dev-perl/libpve-access-control` | |
| `libpve-cluster-perl` | `sys-cluster/pve-cluster` | Phase 3 (optional for single node) |
| `libpve-guest-common-perl` | `dev-perl/libpve-guest-common-perl` | |
| `libpve-storage-perl` | `dev-perl/libpve-storage-perl` | |
| `qemu-server` | `app-emulation/qemu-server` | |
| `proxmox-widget-toolkit` | `www-apps/proxmox-widget-toolkit` | |
| `libjs-extjs` | `www-apps/libjs-extjs` | |
| `novnc-pve` | `www-apps/novnc-pve` | |
| `pve-xtermjs` | `www-apps/pve-xtermjs` | |
| `libterminfo-perl` | `dev-perl/Term-ReadLine` | |
| `libtemplate-perl` | `dev-perl/Template-Toolkit` | |
| `dtach` | `app-misc/dtach` | Detached terminal for qm terminal |
| `gdisk` | `sys-apps/gptfdisk` | Disk partitioning |
| `jq` | `app-misc/jq` | JSON CLI processing |
| `dmidecode` | `sys-apps/dmidecode` | Hardware info |
| `hdparm` | `sys-apps/hdparm` | Disk params |

## Ebuild Notes

- Use `inherit perl-module systemd`
- Install systemd units: `pvedaemon.service`, `pveproxy.service`, `pvestatd.service`
- Web UI assets are installed to `/usr/share/pve-manager/`
- The Makefile's `install` target must be called with the correct `DESTDIR` and `PREFIX`
- On single-node installs without `pve-cluster`, stub out the cluster API calls by
  ensuring `/etc/pve/` is a plain directory (not the pmxcfs FUSE mount)

## Single-Node vs Cluster Mode

On Debian, `/etc/pve/` is always a pmxcfs FUSE mount (from `pve-cluster`). For a
standalone Gentoo node (Phase 1, no cluster), create `/etc/pve/` as a plain directory
and populate it with the required config files:

```bash
mkdir -p /etc/pve
# Minimal standalone config
cat > /etc/pve/datacenter.cfg << 'EOF'
keyboard: en-us
EOF
```

Full cluster mode requires Phase 3 (`pve-cluster`).

## Post-Install

```bash
systemctl enable --now pvedaemon.service
systemctl enable --now pveproxy.service
systemctl enable --now pvestatd.service

# Access web UI
# https://<host>:8006
```

## Architecture Notes

Pure Perl runtime; `KEYWORDS="~arm64 ~loong ~amd64"`.
