# Perl Module Gap Audit

**Date:** 2026-07-02  
**Scope:** All Perl modules required by the pxvirt management stack  
**Method:** Searched `/var/db/repos/gentoo/dev-perl/` for each module package

---

## Summary

✅ **All standard Perl dependencies are available in the Gentoo tree.**  
✅ **APT dependency fully disabled across both Perl and Rust layers (patches written).**

No overlay ebuilds are needed for the Perl module layer — proceed directly to writing
the pxvirt-specific Perl package ebuilds.

**APT is completely excised:** The entire `/nodes/{node}/apt/*` API surface is removed
via patches at two independent layers (see below). pvedaemon starts cleanly on Gentoo.

---

## Modules in Gentoo Tree (`dev-perl/`)

All of the following are confirmed present and do not need overlay ebuilds:

| Module | Gentoo atom |
|--------|-------------|
| AnyEvent | `dev-perl/AnyEvent` |
| AnyEvent::HTTP | `dev-perl/AnyEvent-HTTP` |
| Authen::PAM | `dev-perl/Authen-PAM` |
| Clone | `dev-perl/Clone` |
| Crypt::OpenSSL::Random | `dev-perl/Crypt-OpenSSL-Random` |
| Crypt::OpenSSL::RSA | `dev-perl/Crypt-OpenSSL-RSA` |
| Crypt::SSLeay | `dev-perl/Crypt-SSLeay` |
| Filesys::Df | `dev-perl/Filesys-Df` |
| HTTP::Daemon | `dev-perl/HTTP-Daemon` |
| HTTP::Message | `dev-perl/HTTP-Message` |
| IO::Stringy | `dev-perl/IO-stringy` |
| IO::Socket::SSL | `dev-perl/IO-Socket-SSL` |
| Linux::Inotify2 | `dev-perl/Linux-Inotify2` |
| MIME::Base32 | `dev-perl/MIME-Base32` |
| Mozilla::CA | `dev-perl/Mozilla-CA` |
| Net::DBus | `dev-perl/Net-DBus` |
| Net::DNS | `dev-perl/Net-DNS` |
| Net::IP | `dev-perl/Net-IP` |
| Net::SSLeay | `dev-perl/Net-SSLeay` |
| NetAddr::IP | `dev-perl/NetAddr-IP` |
| String::ShellQuote | `dev-perl/String-ShellQuote` |
| Template (Toolkit) | `dev-perl/Template-Toolkit` |
| Term::ReadLine::Gnu | `dev-perl/Term-ReadLine-Gnu` |
| File::ReadBackwards | `dev-perl/File-ReadBackwards` |
| File::Slurp | `dev-perl/File-Slurp` |
| JSON | `dev-perl/JSON` |
| JSON::XS | `dev-perl/JSON-XS` |
| LWP (libwww-perl) | `dev-perl/libwww-perl` |
| LWP::Protocol::https | `dev-perl/LWP-Protocol-https` |
| URI | `dev-perl/URI` |
| UUID | `dev-perl/UUID` |
| YAML::LibYAML | `dev-perl/YAML-LibYAML` |

---

## Perl Core Modules (ship with `dev-lang/perl` — no separate package needed)

These appeared as "missing" from dev-perl/ but are bundled with Perl itself:

| Module | Status |
|--------|--------|
| Encode | Perl core |
| POSIX | Perl core |
| Scalar::Util | Perl core |
| Socket | Perl core |
| Storable | Perl core |
| Time::HiRes | Perl core |

---

## APT Removal: Two-Layer Strategy

APT surfaces at **two independent layers** in the pxvirt/proxmox-perl-rs stack.
Both must be patched. Patch files are already written in the overlay.

---

### Layer 1 — Perl: `PVE::API2::APT` (pve-manager)

**Patch:** `sys-apps/pve-manager/files/0001-Gentoo-stub-PVE-API2-APT-Perl-layer-no-apt-on-Gentoo.patch`

`PVE/API2/APT.pm` uses three Debian-only Perl modules:
```perl
use AptPkg::Cache;       # libapt-pkg-perl -- Debian only
use AptPkg::PkgRecords;
use AptPkg::System;
```

`PVE/API2/Nodes.pm` line 42 has a **compile-time** `use PVE::API2::APT` -- not lazy.
When `pvedaemon` starts it immediately loads `APT.pm`, which dies with
`Can't locate AptPkg/Cache.pm`. **pvedaemon cannot start without this patch.**

**Fix:** Replace `PVE/API2/APT.pm` with a stub that loads cleanly, registers all the
same API endpoints, and returns HTTP 501 directing users to `emerge`.

---

### Layer 2 -- Rust: `proxmox-apt` crate with `"cache"` feature (proxmox-perl-rs)

**Patches:**
- `dev-perl/proxmox-perl-rs/files/0001-Gentoo-remove-proxmox-apt-cache-feature-no-libapt-pkg.patch`
- `dev-perl/proxmox-perl-rs/files/0002-Gentoo-stub-Rust-APT-exports-no-libapt-pkg.patch`

`pve-rs/Cargo.toml` declares:
```toml
proxmox-apt = { version = "0.11.5", features = ["cache"] }
```

The `"cache"` feature enables FFI bindings against Debian's `libapt-pkg` C library,
which does not exist in the Gentoo tree. **`pve_rs.so` fails to compile without patching.**

Additionally, `pve-rs/src/apt/repositories.rs` and `common/src/apt/repositories.rs`
export XS functions (via perlmod) that call `proxmox_apt::list_available_apt_update()`
and `proxmox_apt::update_database()` -- symbols only present with the `"cache"` feature.

**Fix (patch 1):** Remove `features = ["cache"]` from the `proxmox-apt` dep.
**Fix (patch 2):** Stub all `#[export]` function bodies in both `repositories.rs` files
to return `Err("APT not available on Gentoo")`. Stub `send_updates_available()` in
`lib.rs` to return `Ok(())`.

---

### Why Both Layers Are Needed

| Layer | Without Patch | With Patch |
|-------|--------------|------------|
| Perl `PVE::API2::APT` | pvedaemon crashes at startup | pvedaemon starts; APT endpoints return 501 |
| Rust `proxmox-apt` cache feature | `pve_rs.so` fails to compile | Compiles cleanly; APT XS stubs return errors |

---

## Impact on pxvirt Functionality

| Feature | Status on Gentoo |
|---------|-----------------|
| `/nodes/{node}/apt/update` (check updates) | Not available -- use `emerge --update @world` |
| `/nodes/{node}/apt/versions` (installed pkgs) | Not available -- use `qlist -Iv` |
| `/nodes/{node}/apt/changelog` | Not available |
| `/nodes/{node}/apt/repositories` | Not available -- use `/etc/portage/repos.conf` |
| APT update email/webhook notifications | Not sent |
| All VM/CT management | Fully functional |
| All storage management | Fully functional |
| All user/auth management | Fully functional |
| All networking/SDN | Fully functional |
| Web UI (everything except Updates tab) | Fully functional |

---

## Conclusion

APT is **fully excised** across both Perl and Rust layers. Patch files are written.
`pvedaemon` starts cleanly on Gentoo and `pve_rs.so` compiles without `libapt-pkg`.
The web UI Updates tab returns a clear 501 directing users to `emerge`.
