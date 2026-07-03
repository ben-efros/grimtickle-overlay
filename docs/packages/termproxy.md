# proxmox-termproxy → sys-apps/proxmox-termproxy

## Overview

`proxmox-termproxy` is the Rust binary backend for the xterm.js terminal console.
It proxies WebSocket connections from pveproxy to a PTY running an arbitrary command
(e.g., `login`, `bash`, or a container's `lxc-console`).

**Package:** `proxmox-termproxy 2.0.2`  
**Source:** `termproxy/` subdirectory of `git://git.proxmox.com/git/pve-xtermjs.git`  
**Frontend pair:** `www-apps/pve-xtermjs` (the JS/HTML side)

---

## Status: ⏸ DEFERRED — Cargo vendor tarball not yet generated

The ebuild skeleton exists at `sys-apps/proxmox-termproxy/proxmox-termproxy-2.0.2.ebuild`
but has a `pkg_setup` guard that aborts the build. It will remain broken until the
vendor tarball is generated and uploaded.

---

## Why Deferred

Gentoo's `inherit cargo` requires either:

1. **A vendor tarball** — all crates pre-downloaded and bundled, referenced in `SRC_URI`.
   This is the standard approach for published Gentoo ebuilds.

2. **Network access during build** — not standard Gentoo practice; disabled by default
   in a sandbox build environment.

Generating a vendor tarball requires running `cargo vendor` against the source, which
needs a working Rust toolchain and internet access. This cannot be done from the current
session environment.

---

## When to Return

Return to this ebuild once **any** of these is true:

- You have a working Rust toolchain on the build host and can run `cargo vendor`
- You are writing the `dev-perl/proxmox-perl-rs` ebuild (which needs the same workflow)
  — do both vendor tarballs at the same time
- A Gentoo maintainer has published `proxmox-io` and the other Proxmox crates to
  the Gentoo tree, eliminating the need for vendoring

**Recommended:** defer until `ebuild-proxmox-perl-rs` is being worked on, since that
ebuild also requires `cargo vendor` for a much larger Rust workspace. Establishing the
vendor tarball generation workflow once covers both packages.

---

## Rust Dependencies (Cargo.toml)

| Crate | Version | Gentoo status |
|-------|---------|---------------|
| `anyhow` | `1` | `dev-libs/anyhow` in tree |
| `libc` | `0.2.107` | `dev-libs/libc` in tree |
| `mio` | `1` (net, os-ext) | `dev-libs/mio` in tree |
| `nix` | `0.29` (fs, ioctl, process, term) | `dev-libs/nix` in tree |
| `pico-args` | `0.5` | verify in tree |
| `form_urlencoded` | `1.2` | part of `url` crate, in tree |
| `proxmox-io` | `1` | **not in tree — must vendor** |

Only `proxmox-io` requires vendoring. All others are likely available in the Gentoo
tree as `dev-libs/` atoms.

---

## Steps to Complete the Ebuild

### 1. Generate vendor tarball

```bash
git clone git://git.proxmox.com/git/pve-xtermjs.git
cd pve-xtermjs/termproxy

# Generate vendor directory
cargo vendor vendor

# Bundle it
tar czf proxmox-termproxy-2.0.2-vendor.tar.gz vendor/
```

### 2. Compute checksums

```bash
sha512sum proxmox-termproxy-2.0.2-vendor.tar.gz
b2sum proxmox-termproxy-2.0.2-vendor.tar.gz
```

Add to `Manifest`.

### 3. Update the ebuild

- Set `COMMIT=` to the exact git commit hash (get with `git rev-parse HEAD`)
- Replace the placeholder `SRC_URI` with real URLs
- Remove the `pkg_setup` guard block

### 4. Test

```bash
ebuild proxmox-termproxy-2.0.2.ebuild digest
ebuild proxmox-termproxy-2.0.2.ebuild install
```

---

## Runtime Behavior

`termproxy` is **not a daemon**. It is spawned by `pveproxy` as a subprocess for each
terminal session and exits when the session ends. No systemd service file is needed.

The binary is invoked by pveproxy with arguments specifying the ticket, port, and
command to execute. The ticket is validated against PVE's auth system before the PTY
is opened.

---

## Relationship to proxmox-perl-rs

`proxmox-termproxy` is a good **practice run** for the `inherit cargo` workflow before
tackling `dev-perl/proxmox-perl-rs`, which is a much larger Rust workspace (pve-rs,
common, etc.) with dozens more vendored crates. Get termproxy working first to
validate the vendor tarball approach in the overlay.
