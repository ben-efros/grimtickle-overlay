# `dev-perl/proxmox-perl-rs` — pve-rs Rust XS Library

## Package Overview

| Field | Value |
|-------|-------|
| Ebuild | `dev-perl/proxmox-perl-rs/proxmox-perl-rs-0.9.4.ebuild` |
| Source | `pxvirt/packages/proxmox-perl-rs/` (jiangcuo fork) |
| Build system | Cargo (Rust) + perlmod genpackage.pl |
| Output | `libpve_rs.so` + 5 `PVE::RS::*` Perl modules |
| Priority | **Critical path** — blocks all Perl management packages |

## What This Package Provides

`proxmox-perl-rs` builds the Rust portion of the pxvirt management stack
and bridges it to Perl via XS. Without it, **pvedaemon cannot start** (it
tries to `require Proxmox::Lib::PVE` at startup, which loads `libpve_rs.so`).

### Installed Files

| File | Description |
|------|-------------|
| `${VENDORARCH}/auto/libpve_rs.so` | Rust cdylib — the XS shared object |
| `${VENDORLIB}/Proxmox/Lib/PVE.pm` | Library loader; finds and dlopen()s the .so |
| `${VENDORLIB}/PVE/RS/APT/Repositories.pm` | APT repo management (stubbed on Gentoo) |
| `${VENDORLIB}/PVE/RS/Firewall/SDN.pm` | SDN firewall rules |
| `${VENDORLIB}/PVE/RS/OpenId.pm` | OIDC authentication |
| `${VENDORLIB}/PVE/RS/ResourceScheduling/Static.pm` | HA resource scheduling |
| `${VENDORLIB}/PVE/RS/TFA.pm` | Two-factor authentication (TOTP/WebAuthn/recovery) |

## Gentoo-Specific Changes

### APT Removal (Two Patches)

The pxvirt Rust code has two layers of APT dependency that must be removed:

**Patch 0001** (`0001-Gentoo-remove-proxmox-apt-cache-feature-no-libapt-pkg.patch`):
- Removes `features = ["cache"]` from `pve-rs/Cargo.toml`'s `proxmox-apt` dependency
- The `"cache"` feature FFI-links `libapt-pkg.so` (Debian only)
- Without this patch: `libpve_rs.so` fails to link on Gentoo

**Patch 0002** (`0002-Gentoo-stub-Rust-APT-exports-no-libapt-pkg.patch`):
- Stubs all `#[export]` functions in `pve-rs/src/apt/repositories.rs`
- Stubs `send_updates_available()` in `lib.rs`
- Without this patch: compilation fails (undefined references to cache API)

### No libapt-pkg at All

The companion patch in `sys-apps/pve-manager` stubs `PVE::API2::APT` at the
Perl layer (returning HTTP 501). This means the APT update panel in the GUI
does not function — which is correct for Gentoo.

## Build System Details

The upstream Makefile does two distinct things:

1. **Cargo build** → `target/release/libpve_rs.so`
2. **`genpackage.pl`** → generates `Proxmox/Lib/PVE.pm` and `PVE/RS/*.pm`

`genpackage.pl` is a pure-Perl script from the `perlmod-bin` Debian package.
In the overlay it is provided by `dev-perl/perlmod-bin` and installed at
`/usr/lib/perlmod/genpackage.pl`.

The `Fixup.pm` file in the pve-rs directory is prepended to the generated
`Proxmox::Lib::PVE` module. It contains:
```perl
use Proxmox::Lib::SslProbe;
```
This references `Proxmox::Lib::SslProbe` from `libproxmox-rs-perl` (the
common Rust Perl bridge from `proxmox-perl-rs`'s `common/` workspace, which
the `libproxmox-rs-perl` package provides). The `RDEPEND` includes
`dev-libs/libproxmox-rs-perl` to satisfy this.

## Vendor Tarball Generation

The vendor tarball is **not** fetched from a public URL. It must be generated
once and placed in your DISTDIR.

### Background: Why a Vendor Tarball?

All Proxmox-specific Rust crates (`perlmod`, `proxmox-apt`, `proxmox-sys`,
`proxmox-notify`, etc.) are **not published to crates.io**. Debian distributes
them as separate packages in `/usr/share/cargo/registry/`. On Gentoo, they
must be bundled into a vendor tarball.

### Crate Sources

| Source | Repository | Commit |
|--------|-----------|--------|
| `perlmod` 0.13.6 | `pxvirt/packages/perlmod` | pxvirt submodule |
| `perlmod-macro` 0.9.2 | `pxvirt/packages/perlmod` | pxvirt submodule |
| `proxmox-*` monorepo crates | `git.proxmox.com/git/proxmox.git` | `550ebbed` (2025-04-09) |
| `proxmox-resource-scheduling` 0.3.0 | `git.proxmox.com/git/proxmox-resource-scheduling.git` | standalone repo |
| `proxmox-ve-config` 0.2.3 | `pxvirt/packages/proxmox-ve-rs` | pxvirt submodule |

The monorepo commit `550ebbed` (2025-04-09) is the "golden" snapshot where all
required crate versions are simultaneously satisfied:

| Crate | Required | At 550ebbed |
|-------|----------|-------------|
| proxmox-apt | ^0.11.5 | 0.11.7 ✓ |
| proxmox-notify | ^0.5.4 | 0.5.4 ✓ |
| proxmox-openid | ^0.10.4 | 0.10.4 ✓ |
| proxmox-sys | ^0.6 | 0.6.7 ✓ |
| proxmox-tfa | ^5 | 5.0.2 ✓ |
| proxmox-time | ^2 | 2.0.4 ✓ |
| proxmox-http | ^0.9 | 0.9.5 ✓ |

`proxmox-resource-scheduling` was a separate repo until it was merged into
the monorepo at 1.0.0 (May 2025). Version 0.3.0 is taken from that standalone
repo's final pre-merge commit.

### Generation Script

```bash
#!/bin/bash
set -euo pipefail

PXVIRT=/path/to/pxvirt
WORK=/tmp/pve-rs-vendor-work
PROXMOX_MONOREPO_COMMIT=550ebbed

# 1. Clone/prepare sources
git clone --depth=1 https://git.proxmox.com/git/proxmox.git /tmp/proxmox-monorepo
git -C /tmp/proxmox-monorepo fetch --unshallow
git -C /tmp/proxmox-monorepo checkout --detach ${PROXMOX_MONOREPO_COMMIT}

git clone https://git.proxmox.com/git/proxmox-resource-scheduling.git /tmp/proxmox-resource-scheduling
git -C /tmp/proxmox-resource-scheduling fetch --unshallow
git -C /tmp/proxmox-resource-scheduling checkout ba581d9  # version 0.3.0

# 2. Set up vendor workspace
mkdir -p "$WORK"
cp -a "$PXVIRT/packages/proxmox-perl-rs/proxmox-perl-rs/pve-rs" "$WORK/"
cp -a "$PXVIRT/packages/proxmox-perl-rs/proxmox-perl-rs/common" "$WORK/"

# Apply APT removal patch first
cd "$WORK" && patch -p1 < grimtickle-overlay/dev-perl/proxmox-perl-rs/files/0001-Gentoo-remove-proxmox-apt-cache-feature-no-libapt-pkg.patch

cat > "$WORK/Cargo.toml" << 'EOF'
[workspace]
members = ["pve-rs"]
resolver = "3"

[patch.crates-io]
perlmod = { path = "/path/to/pxvirt/packages/perlmod/perlmod/perlmod" }
perlmod-macro = { path = "/path/to/pxvirt/packages/perlmod/perlmod/perlmod-macro" }
# ... (see full template in overlay dev-perl/proxmox-perl-rs/files/vendor-workspace-Cargo.toml)
EOF

# 3. Run cargo vendor
cd "$WORK/pve-rs"
cat > .cargo/config.toml << 'EOF'
[profile.release]
debug = false
EOF
cd "$WORK" && cargo vendor pve-rs/vendor/

# 4. Copy path-deps into vendor (script in files/copy-path-deps-to-vendor.py)
python3 grimtickle-overlay/dev-perl/proxmox-perl-rs/files/copy-path-deps-to-vendor.py

# 5. Package
cd "$WORK/pve-rs" && \
  tar czf /tmp/proxmox-perl-rs-0.9.4-vendor.tar.gz vendor/
echo "Tarball ready: /tmp/proxmox-perl-rs-0.9.4-vendor.tar.gz"

# 6. Place in DISTDIR
cp /tmp/proxmox-perl-rs-0.9.4-vendor.tar.gz /var/cache/distfiles/
```

The pre-generated vendor tarball is also stored in:
```
grimtickle-overlay/dev-perl/proxmox-perl-rs/files/proxmox-perl-rs-0.9.4-vendor.tar.gz
```
For local development, you can symlink or copy this to your DISTDIR:
```bash
cp grimtickle-overlay/dev-perl/proxmox-perl-rs/files/proxmox-perl-rs-0.9.4-vendor.tar.gz \
   /var/cache/distfiles/
```

## Dependencies

### Build Dependencies
| Package | Version | Notes |
|---------|---------|-------|
| `virtual/rust` | ≥1.70 | Rust stable channel |
| `dev-lang/perl` | any | For genpackage.pl and Perl config queries |
| `dev-perl/perlmod-bin` | 0.13.6 | Provides `/usr/lib/perlmod/genpackage.pl` |

### Runtime Dependencies
| Package | Reason |
|---------|--------|
| `dev-libs/openssl` | TLS (proxmox-openid, proxmox-http) |
| `dev-libs/libproxmox-rs-perl` | Provides `Proxmox::Lib::SslProbe` (Fixup.pm) |

## Phase Position

This package is in **Phase 1** of the porting plan and is the single most
important package to get working. It unblocks:

```
proxmox-perl-rs (THIS)
    └── pve-common         (dev-perl/libpve-common-perl)
          ├── pve-http-server
          │     └── pve-access-control
          │           └── pve-storage → pve-manager
          └── pve-guest-common → pve-container / qemu-server
```

## Status

| Task | Status |
|------|--------|
| Vendor tarball generated | ✅ (2025-07-03, stored in files/) |
| APT patches written | ✅ |
| Ebuild skeleton written | ✅ |
| Build test on Gentoo | ⏳ pending |
| `genpackage.pl` output verified | ⏳ pending |
| Integration with pve-common | ⏳ pending |

## Notes

- The Rust edition is `2024`, requires Rust ≥ 1.75.0
- `RESTRICT="fetch"` is set because the vendor tarball cannot be fetched
  from a public URL automatically. Users must place it in DISTDIR.
- The `RESTRICT` can be lifted once a public hosting URL is established.
- `libproxmox-rs-perl` (from the `common/` workspace of proxmox-perl-rs)
  is a separate package built from the same source repo. It must be
  ported alongside this package.
