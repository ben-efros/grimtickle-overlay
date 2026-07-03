# proxmox-backup → app-backup/proxmox-backup

## Overview

`proxmox-backup` is the Proxmox Backup Server — a Rust-based backup solution that supports
incremental, deduplicated backups of VMs, containers, and plain files. pxvirt integrates
with PBS for VM/CT backup via `pve-storage` and `proxmox-backup-qemu`.

## Upstream

- **pxvirt source:** `packages/proxmox-backup/proxmox-backup/`
- **Debian packages:** `proxmox-backup-server`, `proxmox-backup-client`, `proxmox-backup-file-restore`
- **Build system:** Cargo (large Rust workspace)

## Portage Atom

```
app-backup/proxmox-backup
```

## Key Dependencies

| Build dep | Gentoo atom |
|-----------|-------------|
| Rust toolchain | `dev-lang/rust` (≥ 1.75) |
| `libacl-dev` | `sys-apps/acl` |
| `libpopt-dev` | `dev-libs/popt` |
| `libzstd-dev` | `app-arch/zstd` |
| `libudev-dev` | `virtual/udev` |
| `libfuse3-dev` | `sys-fs/fuse:3` |
| `libjs-extjs` | `www-apps/libjs-extjs` |
| `proxmox-widget-toolkit` | `www-apps/proxmox-widget-toolkit` |

## Ebuild Notes

- Use `inherit cargo`
- This is a large Rust workspace; vendor all crates with `cargo vendor`
- Set `CARGO_HOME` appropriately in the ebuild
- Split ebuilds may be preferable:
  - `app-backup/proxmox-backup-server` — the PBS daemon
  - `app-backup/proxmox-backup-client` — the backup client (used by pve-storage)
- The client (`proxmox-backup-client`) is what pve-storage calls for VM backups

## USE Flags

| Flag | Effect |
|------|--------|
| `server` | Build and install the full PBS server daemon |
| `client` | Build only the backup client (lighter) |
| `fuse` | Enable FUSE-based file restore |

## Architecture Notes

Rust; `KEYWORDS="~arm64 ~loong"`. Verify Rust target triple support:
- ARM64: `aarch64-unknown-linux-gnu` ✅ stable
- LoongArch: `loongarch64-unknown-linux-gnu` ✅ since Rust 1.71

## Notes

`proxmox-backup-qemu` (a separate package) is the QEMU-integrated PBS client library
used for live VM backups. It should be built as a companion to this package.
