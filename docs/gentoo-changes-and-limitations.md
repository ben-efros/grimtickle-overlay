# pxvirt Gentoo Port — Changes & Functional Limitations

> **Purpose:** Track every Gentoo-specific modification, functional difference,
> and known limitation compared to the upstream pxvirt/Proxmox VE Debian installation.
> Updated continuously as packages are ported.
>
> **Last updated:** 2025-07-03

---

## How to Read This Document

Each entry uses one of these severity tags:

| Tag | Meaning |
|-----|---------|
| 🔴 **BREAKING** | Feature completely non-functional; requires user action or upstream fix |
| 🟠 **DEGRADED** | Feature partially works; reduced functionality vs Debian |
| 🟡 **DIFFERENT** | Behaviour differs but equivalent result is achievable |
| 🟢 **TRANSPARENT** | Change is internal only; user-visible behaviour identical |
| ⚪ **DEFERRED** | Package skeleton exists; not yet installable |

---

## Package-by-Package Changes

---

### `app-emulation/lxc-pve` (6.0.5)

**Build system change:** Upstream lxc switched from autotools to Meson at v4.0.
The ebuild uses `inherit meson` rather than the `autotools` eclass that older
Gentoo tutorials suggest.

**Patches applied:**

| Patch | Source | Effect |
|-------|--------|--------|
| `0001-PVE-Config-deny-rw-mounting-of-sys-and-proc.patch` | pxvirt | 🟢 Security hardening; prevents containers rw-mounting /sys and /proc |
| `0002-PVE-Config-attach-always-use-getent.patch` | pxvirt | 🟢 Uses `getent` for uid resolution instead of `/etc/passwd` direct parse |
| `0001-apparmor-allow-lxc-start-to-create-user-namespaces.patch` | pxvirt | 🟢 AppArmor profile update |
| `0002-apparmor-use-abi-directive-in-apparmor-profiles.patch` | pxvirt | 🟢 AppArmor ABI directive modernisation |

**Post-install behaviour:**

| Item | Debian | Gentoo |
|------|--------|--------|
| `lxc-user-nic` | setuid 4755 via dpkg trigger | Set 4755 in `pkg_postinst` |
| `/etc/subuid`, `/etc/subgid` | Created by `adduser` | Created in `pkg_postinst` if absent |
| AppArmor profiles | Loaded by `apparmor.service` | Same — no change |

**No functional limitations.** LXC container create/start/stop/exec fully expected to work.

---

### `www-apps/libjs-extjs` (7.0.0)

🟢 **TRANSPARENT**

Pre-built JavaScript library fetched from Proxmox git via `git-r3`.
Installed to `/usr/share/javascript/extjs/`. No build step.
Identical content to the Debian `libjs-extjs` package.

---

### `www-apps/libjs-qrcodejs` (1.20230525)

🟢 **TRANSPARENT**

Single-file JS library. `USE=minify` runs `uglifyjs` if available (optional).
Installed to `/usr/share/javascript/qrcodejs/qrcode.min.js`.
Path hardcoded in `pveproxy`; must match exactly.

---

### `www-apps/novnc-pve` (1.6.0)

🟢 **TRANSPARENT** (functionally)

**Build change:** Requires `dev-util/esbuild` (confirmed in Gentoo tree) to
bundle `app/ui.js` into `app.js`. 20 Proxmox-specific patches applied on top
of upstream noVNC 1.6.0.

**Important:** Do NOT substitute `app-misc/novnc` from the Gentoo tree.
The Proxmox patches add WebSocket authentication, custom VNC command
passthrough, PVE-specific UI buttons, and clipboard support that the stock
noVNC does not have. Substituting it would break console access.

**Installed to:** `/usr/share/novnc-pve/`

---

### `www-apps/pve-xtermjs` (5.5.0)

🟢 **TRANSPARENT**

Pre-built npm artifacts committed to the pxvirt git repository.
`sed` substitutes `@VERSION@` into `index.html.tpl`.
**Installed to:** `/usr/share/pve-xtermjs/`

**RDEPEND:** `sys-apps/proxmox-termproxy` — see below (deferred).

---

### `sys-apps/proxmox-termproxy` (2.0.2) ⚪ DEFERRED

🔴 **BREAKING — Terminal console non-functional until completed**

The WebSocket-to-PTY proxy (Rust binary) required for the xterm.js terminal
console. The ebuild skeleton exists with a `pkg_setup` guard that `die`s with
an informative message.

**Blocked on:** Cargo vendor tarball generation for the `proxmox-termproxy`
workspace. Only one non-tree crate (`proxmox-io`) is needed beyond crates.io.

**To complete:** See `docs/packages/termproxy.md` for exact steps.

**User impact:** Clicking the "Console" button in the pxvirt GUI will fail
to open a terminal. SSH access to containers/VMs is unaffected.

---

### `sys-apps/proxmox-mini-journalreader` (1.6)

🟢 **TRANSPARENT**

Single C file. Links against `libsystemd`. Installed to `/usr/libexec/`.
Used by pve-manager to read journal entries for the task log panel.

---

### `sys-cluster/corosync` (3.1.10)

🟡 **DIFFERENT** (improved vs Debian's 3.1.x)

Upstream 3.1.10 already includes fixes from 3 of the 5 pxvirt patches
(knet timer fix, CVE-2026-35091, CVE-2026-35092). Only 2 patches applied:

| Patch | Effect |
|-------|--------|
| `0001-systemd-Enable-PrivateTmp` | 🟢 Systemd sandboxing improvement |
| `0002-systemd-Only-start-if-corosync.conf-exists` | 🟢 Prevents boot failure on unclustered nodes |

**KEYWORDS added:** `~arm64 ~loong` (not in Gentoo tree's 3.1.0).

**No functional regression.** ABI-compatible with `pve-cluster`.

---

### `dev-perl/perlmod-bin` (0.13.6)

🟢 **TRANSPARENT**

Installs `genpackage.pl` to `/usr/lib/perlmod/genpackage.pl`.
This is a build-time tool only; no runtime impact.
Sourced from pxvirt's pinned `perlmod` submodule (0.13.6).

---

### `dev-perl/proxmox-perl-rs` (0.9.4)

**This is the most impactful Gentoo-specific change in the entire port.**

#### APT Removal — Two-Layer Strategy

pxvirt's Rust XS library has two layers of Debian-specific APT dependency,
both of which are removed:

**Layer 1 — Rust compile-time (Patch 0001):**
- Removes `features = ["cache"]` from `proxmox-apt` in `pve-rs/Cargo.toml`
- The `"cache"` feature FFI-links `libapt-pkg.so` — a Debian-only library
- Without this patch: `libpve_rs.so` fails to link on Gentoo

**Layer 2 — Rust function stubs (Patch 0002):**
- Stubs all `#[export]` APT cache functions in `pve-rs/src/apt/repositories.rs`
- Stubs `send_updates_available()` in `pve-rs/src/lib.rs`
- Each stub returns `Err("not available on Gentoo")`
- Without this patch: compilation fails (undefined references)

**Layer 3 — Perl API stub (in `sys-apps/pve-manager`):**
- `PVE::API2::APT` is replaced with a 6-endpoint stub (HTTP 501)
- Without this: `pvedaemon` crashes at startup (`use PVE::API2::APT` at compile-time)

🔴 **FUNCTIONAL LIMITATION — APT Update Panel non-functional:**
The Datacenter → Node → Updates screen in the GUI does not work.
`apt-get update` / `apt-get upgrade` are Debian concepts with no Gentoo equivalent.
Users should use `emerge --sync && emerge -uDU @world` for system updates.

🟠 **DEGRADED — Package update notifications absent:**
`send_updates_available()` sends a notification when apt packages need updating.
On Gentoo this function returns `Ok(())` immediately (no-op). No package update
notifications will be generated by pxvirt itself.

**Vendor tarball:** 277 Rust crates (246 from crates.io + 31 Proxmox-internal
crates not published to crates.io). Tarball stored in `files/` (36MB compressed).
See `docs/packages/proxmox-perl-rs.md` for regeneration instructions.

---

### `dev-perl/libpve-common-perl` (9.0.11)

🟡 **DIFFERENT** (network config behaviour)

Pure Perl. All 20 Perl deps confirmed in Gentoo tree.

**Network configuration (`PVE::INotify`, `PVE::Network`):**

| Behaviour | Debian | Gentoo |
|-----------|--------|--------|
| Watched config file | `/etc/network/interfaces` | File does not exist |
| inotify watch | Set up successfully | Watch registered but never triggers |
| `read_etc_network_interfaces()` | Returns parsed interface list | Returns empty config |
| GUI → Node → Network tab | Shows current interfaces | Shows empty list |

🟠 **DEGRADED — GUI Network tab empty:**
The Node → Network configuration tab will show no interfaces.
This is expected behaviour until the `network-backend-plugin` todo is
implemented. Network changes through the GUI will not work.

**Workaround:** Configure networking directly via `systemd-networkd` unit files
or `NetworkManager`. See `docs/networking.md`.

`ifupdown2` detection (`Network.pm:1527`) is always false on Gentoo — harmless.

**Deferred RDEPEND (not yet ported):**
- `libproxmox-rs-perl` — from `common/` workspace of proxmox-perl-rs
- `libproxmox-acme-perl` — ACME/Let's Encrypt client

---

### `dev-perl/libpve-http-server-perl` (6.0.5)

🟢 **TRANSPARENT** (core functionality)

Pure Perl. All Perl deps confirmed in Gentoo tree.

**Bootstrap5 HTML browser (`USE=html-browser`):**

| Behaviour | Debian | Gentoo (default) | Gentoo (+html-browser) |
|-----------|--------|-----------------|----------------------|
| `/bootstrap5/css/bootstrap.min.css` | Served | 404 | Served |
| HTML API browser formatting | Works | Minimal HTML | Works |

🟡 **DIFFERENT (minor):** The built-in HTML API browser (`pvesh` accessed via
browser without credentials) shows minimal HTML without Bootstrap styling unless
`USE=html-browser` is set. This is a developer tool; normal operation unaffected.

**`www-apps/bootstrap` (5.3.8):** Companion ebuild fetches Bootstrap 5 dist
from GitHub releases. Installed to `/usr/share/bootstrap-html/`.

---

## Global Networking Differences

**This is the most significant operational difference from Debian.**

| Feature | Debian | Gentoo (current) | Gentoo (planned) |
|---------|--------|-----------------|-----------------|
| Bridge config | `/etc/network/interfaces` via `ifupdown2` | Not managed by pxvirt | `network-backend-plugin` todo |
| GUI Network tab | Configure bridges, VLANs | Empty — no interfaces shown | After plugin |
| `pvesh get /nodes/NODE/network` | Returns full config | Returns `[]` | After plugin |
| Bridge creation (vm/ct) | Auto-created by `ifupdown2` | Must pre-create manually | After plugin |

**Immediate workaround for a working node:**
1. Pre-create the Linux bridge manually via `systemd-networkd` or `ip` commands
2. Name it `vmbr0` (pxvirt default) or adjust VM/CT configs to match
3. Set it up persistently in a `.network` file before starting pxvirt services

See `docs/networking.md` for full details and example configuration.

---

## Deferred / Blocked Packages

| Package | Blocker | User Impact |
|---------|---------|-------------|
| `sys-apps/proxmox-termproxy` | Cargo vendor tarball needed | ❌ xterm.js terminal console |
| `app-emulation/vncterm` | `wchardata.c` not in Gentoo `unifont` | ❌ Serial console (VNC-based) |
| `sys-apps/proxmox-mail-forward` | Cargo vendor needed | 🟡 Mail forwarding from root |
| `sys-apps/proxmox-rrd-migration-tool` | Cargo vendor needed | Minor (migration only) |
| `dev-libs/libproxmox-rs-perl` | Not yet written (common/ workspace) | ⚠️ pve-common dep |
| `dev-perl/libproxmox-acme-perl` | Not yet written | ⚠️ TLS cert management |

---

## Features That Will Never Work on Gentoo

| Feature | Reason | Gentoo Alternative |
|---------|--------|-------------------|
| Apt package updates (GUI) | No `libapt-pkg`, no dpkg | `emerge -uDU @world` |
| `apt-get` subscriptions panel | Debian-only | N/A |
| pxvirt Subscription Management | Hits Debian repos | N/A (subscription concept doesn't apply) |
| Debian security notices | Uses Debian CVE tracker | Use GLSA / `glsa-check` |

---

## Patches Summary Table

| File | Package | Purpose | Type |
|------|---------|---------|------|
| `app-emulation/lxc-pve/files/0001-PVE-Config-deny-rw-mounting…` | lxc-pve | Security hardening | Upstream pxvirt patch |
| `app-emulation/lxc-pve/files/0002-PVE-Config-attach-always-use-getent…` | lxc-pve | uid resolution fix | Upstream pxvirt patch |
| `app-emulation/lxc-pve/files/0001-apparmor-allow-lxc-start…` | lxc-pve | AppArmor user ns | Upstream pxvirt patch |
| `app-emulation/lxc-pve/files/0002-apparmor-use-abi-directive…` | lxc-pve | AppArmor ABI | Upstream pxvirt patch |
| `dev-perl/proxmox-perl-rs/files/0001-Gentoo-remove-proxmox-apt-cache-feature…` | proxmox-perl-rs | Remove libapt-pkg dep | **Gentoo-specific** |
| `dev-perl/proxmox-perl-rs/files/0002-Gentoo-stub-Rust-APT-exports…` | proxmox-perl-rs | Stub APT XS exports | **Gentoo-specific** |
| `sys-apps/pve-manager/files/0001-Gentoo-stub-PVE-API2-APT-Perl-layer…` | pve-manager | Stub APT Perl API | **Gentoo-specific** |
| `sys-cluster/corosync/files/0001-systemd-Enable-PrivateTmp…` | corosync | Systemd sandboxing | Upstream (adapted path) |
| `sys-cluster/corosync/files/0002-systemd-Only-start-if-corosync.conf-exists…` | corosync | Prevent boot fail | Upstream (adapted path) |
| `www-apps/novnc-pve/files/0001…0020` | novnc-pve | PVE VNC customisation | 20 upstream pxvirt patches |

---

## Installed Path Differences

Where Gentoo's paths differ from Debian's expected paths:

| Component | Debian path | Gentoo path | Notes |
|-----------|------------|-------------|-------|
| Perl vendor libs | `/usr/share/perl5/` | `$(perl -MConfig -e '..installvendorlib..')` | Ebuild queries Perl Config |
| Perl vendor arch | `/usr/lib/*/perl5/` | `$(perl -MConfig -e '..installvendorarch..')` | Same |
| `libpve_rs.so` | `…/auto/libpve_rs.so` | `VENDORARCH/auto/libpve_rs.so` | Same relative path |
| genpackage.pl | `/usr/lib/perlmod/genpackage.pl` | `/usr/lib/perlmod/genpackage.pl` | ✅ Identical |
| bootstrap5 | `/usr/share/bootstrap-html/` | `/usr/share/bootstrap-html/` | ✅ Identical |
| noVNC | `/usr/share/novnc-pve/` | `/usr/share/novnc-pve/` | ✅ Identical |
| xterm.js | `/usr/share/pve-xtermjs/` | `/usr/share/pve-xtermjs/` | ✅ Identical |
| ExtJS | `/usr/share/javascript/extjs/` | `/usr/share/javascript/extjs/` | ✅ Identical |
| qrcode.js | `/usr/share/javascript/qrcodejs/qrcode.min.js` | Same | ✅ Identical |
| mini-journalreader | `/usr/libexec/proxmox-mini-journalreader` | `/usr/libexec/proxmox-mini-journalreader` | ✅ Identical |

---

## Version Differences vs Upstream pxvirt/Debian

| Package | pxvirt/Debian | Overlay | Notes |
|---------|--------------|---------|-------|
| corosync | 3.1.x (pve-patched) | 3.1.10 | Upstream 3.1.10 already includes 3 of 5 pxvirt patches |
| lxc-pve | 6.0.5 | 6.0.5 | Identical |
| novnc-pve | 1.6.0 | 1.6.0 | Identical |
| pve-xtermjs | 5.5.0 | 5.5.0 | Identical |
| perlmod | 0.13.6 | 0.13.6 | Identical (pxvirt submodule) |
| proxmox-apt (vendor) | 0.11.5+ | 0.11.7 | Later patch-compatible version |
| proxmox-notify (vendor) | 0.5.4 | 0.5.4 | Identical |
| bootstrap | 5.x | 5.3.8 | Latest stable |

---

## dev-perl/libproxmox-rs-perl (0.3.5)

**Purpose:** Pure Perl bridge — generates `Proxmox::RS::*` stub modules via `genpackage.pl --lib=-`
that delegate to `libpve_rs.so` already loaded by `dev-perl/proxmox-perl-rs`.

| Change | Severity | Notes |
|--------|----------|-------|
| No Rust compilation | TRANSPARENT | This package is pure Perl; the .so comes from proxmox-perl-rs |
| Dynamic dispatch to PVE library | TRANSPARENT | `Proxmox::Lib::Common` tries `Proxmox::Lib::PVE` first, then PMG |
| `Proxmox::Lib::SslProbe` is pure Perl | TRANSPARENT | Perl reimplementation of openssl-probe Rust crate; avoids setenv() crash on Perl < 5.38 |

---

## dev-perl/libpve-access-control (9.0.3)

**Purpose:** Role-based access control — users, groups, realms, ACLs, TFA, API tokens, OIDC.

| Change | Severity | Notes |
|--------|----------|-------|
| `libpve-cluster-perl` not yet ported | BREAKING | `PVE::AccessControl` reads `/etc/pve/user.cfg` via pmxcfs; auth fails without it. Workaround: seed `/etc/pve/` as plain directory — see docs/packages/pve-access-control.md |
| Shell completions skipped | DIFFERENT | `pveum.bash-completion` / `pveum.zsh-completion` not installed; generation requires full runtime stack at build time |
| Man page skipped | DIFFERENT | `pveum.1` generated by `pve-doc-generator` (not yet ported) |
| All CPAN deps confirmed in tree | TRANSPARENT | Authen-PAM, Crypt-OpenSSL-{Random,RSA}, MIME-Base32, perl-ldap, Net-SSLeay, UUID |

---

## dev-perl/POSIX-strptime (0.13)

**Purpose:** Perl XS binding for `strptime(3)`. Not in the Gentoo tree; added to overlay.
Required by `PVE::Storage::PBSPlugin` — without it `PVE::Storage` fails to load entirely.

| Change | Severity | Notes |
|--------|----------|-------|
| Not in ::gentoo tree | TRANSPARENT | Added to overlay; sourced from CPAN GOZER/POSIX-strptime-0.13.tar.gz |

---

## dev-perl/libpve-apiclient-perl (3.4.2)

**Purpose:** PVE REST API client (PVE::APIClient::LWP). Used by PBSPlugin to talk to PBS.

| Change | Severity | Notes |
|--------|----------|-------|
| Sourced from upstream proxmox git (not pxvirt fork) | TRANSPARENT | No pxvirt-specific patches; upstream proxmox.com is authoritative |
| All CPAN deps in tree | TRANSPARENT | IO-Socket-SSL, libwww-perl, URI, JSON, Net-SSLeay |

---

## dev-perl/libpve-storage-perl (9.0.13)

**Purpose:** Unified storage abstraction with plugins for all PVE storage backends.

| Change | Severity | Notes |
|--------|----------|-------|
| `libpve-cluster-perl` not yet ported | BREAKING | `/etc/pve/storage.cfg` unreadable without pmxcfs. Workaround: seed file manually. |
| Ceph backends require `USE=ceph` | DIFFERENT | RBDPlugin + CephFSPlugin .pm files always installed, but `ceph-common`/`librados2-perl` only pulled with USE=ceph |
| NFS/CIFS/iSCSI gated by USE flags | DIFFERENT | System tools (`nfs-utils`, `samba`, `open-iscsi`) made optional |
| `bcache-tools` not required | TRANSPARENT | Debian listed it as dep; Diskmanage.pm only reads sysfs paths, never calls bcache binary |
| Shell completions + man page skipped | DIFFERENT | Same reason as libpve-access-control (pve-doc-generator not ported) |
| All plugin .pm files always installed | TRANSPARENT | PVE::Storage hard-uses all plugins at load time; USE flags only gate system tools |

---

## dev-perl/libpve-guest-common-perl (6.0.2)

**Purpose:** Shared base modules for VMs (qemu-server) and containers (pve-container).

| Change | Severity | Notes |
|--------|----------|-------|
| `proxmox-websocket-tunnel` binary not yet ported | DEGRADED | Live migration tunneling (`PVE::Tunnel::fork_websocket_tunnel`) fails; local guest operations unaffected |
| `libpve-cluster-perl` not yet ported | DEGRADED | `ReplicationConfig`/`ReplicationState`/`AbstractConfig` cluster reads fail on single-node; non-replicated local VMs/CTs unaffected |
| All CPAN deps in tree | TRANSPARENT | JSON, URI, Time::HiRes, IPC::Open2 (core) |
| Sourced from upstream proxmox.com git (no pxvirt fork) | TRANSPARENT | No pxvirt-specific patches in pve-guest-common |
