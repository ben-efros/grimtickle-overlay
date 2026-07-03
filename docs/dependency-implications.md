# Dependency Implications Reference

This document describes what breaks — and by how much — when specific packages are absent
at each stage of the pxvirt Gentoo port. Use this when deciding which packages to
prioritize or defer.

---

## Critical Path (Nothing Works Without These)

```
RUST TOOLCHAIN (dev-lang/rust ≥ 1.75)
    │
    ▼
proxmox-perl-rs  ← BLOCKS EVERYTHING BELOW
    │
proxmox-ve-rs    ← blocks pve-access-control, pve-manager
    │
pve-common       ← BLOCKS ALL MANAGEMENT PERL PACKAGES
    │
┌───┴─────────────────────────────────────────┐
pve-http-server  pve-access-control  pve-storage  pve-network
    │                   │
    └─────┬─────────────┘
          pve-guest-common
          │
     ┌────┴──────┐
qemu-server   pve-container
     │
pve-manager   ← requires ALL Phase 1 packages as hard deps
```

If **any** node in this chain is missing, `emerge sys-apps/pve-manager` will refuse.
There are no optional Depends: in pxvirt's Perl packages — everything is hard-wired.

---

## Package-by-Package Implications

### `dev-perl/libproxmox-rs-perl` (proxmox-perl-rs)

**Status:** Overlay ebuild needed (Rust → Perl XS)

**If missing:**
- Every pxvirt Perl package fails to install (`Depends: libproxmox-rs-perl`)
- **Zero** pxvirt functionality is available
- **Severity: TOTAL BLOCKER**

**Workaround:** None. Must be built first. Requires Rust ≥ 1.75 and vendored crates.

---

### `dev-perl/libpve-rs-perl` (proxmox-perl-rs pve-rs workspace)

**Status:** Overlay ebuild needed (same source as above, different workspace member)

**If missing:**
- `pve-access-control` fails → web UI login broken
- `pve-manager` fails to install
- **Severity: TOTAL BLOCKER**

---

### `dev-perl/libpve-common-perl` (pve-common)

**Status:** Overlay ebuild needed (pure Perl)

**If missing:**
- All higher-level packages fail: http-server, access-control, storage, network, qemu-server, pve-manager
- **Severity: TOTAL BLOCKER**

---

### `sys-firmware/pve-edk2-firmware`

**Status:** Overlay ebuild needed. Gentoo's `sys-firmware/edk2-bin` is **x86-only**.

**If missing:**
- ARM64 and LoongArch VMs can only boot via legacy BIOS (SeaBIOS-aarch64)
- Nearly all ARM64 cloud images (Ubuntu, Debian, Fedora, Rocky) **require UEFI** and will not boot
- ARM64 server workloads (EFI-signed kernels) will fail to start
- x86_64 VMs still work via `edk2-bin`
- **Severity: HARD BLOCKER for ARM64/LoongArch VM workloads**

**Workaround:** None for UEFI-required guests. Legacy-BIOS ARM64 guests only work with
specific boot setups. Build `pve-edk2-firmware` ebuild before attempting ARM64 VM tests.

---

### `sys-apps/proxmox-mini-journalreader`

**Status:** Not in Gentoo tree. Overlay ebuild needed.

**If missing:**
- `pve-manager` has a hard `Depends:` on this
- `emerge sys-apps/pve-manager` will **refuse**
- **Severity: HARD BLOCKER** (pve-manager cannot be emerged)

**Workaround:** A stub binary at `/usr/bin/proxmox-mini-journalreader` that exits 0
may satisfy Portage at install time, but task log display in the web UI will be broken.

---

### `sys-apps/proxmox-mail-forward`

**Status:** Not in Gentoo tree. Overlay ebuild needed.

**If missing:**
- `pve-manager` has a hard `Depends:` on this
- **Severity: HARD BLOCKER** (pve-manager cannot be emerged)

**Workaround:** Stub binary. Email notifications from pxvirt will silently fail.

---

### `sys-apps/proxmox-rrd-migration-tool`

**Status:** Not in Gentoo tree. Overlay ebuild needed.

**If missing:**
- `pve-manager` has a hard `Depends:` on this
- **Severity: HARD BLOCKER** (pve-manager cannot be emerged)

**Workaround:** Stub binary. RRD stats migration (upgrading from older pxvirt) won't work,
but fresh installations are unaffected at runtime.

---

### `dev-perl/libproxmox-acme-perl` (proxmox-acme)

**Status:** Overlay ebuild needed. Despite being an "advanced" feature, pve-manager
has a hard `Depends:` on this.

**If missing:**
- `emerge sys-apps/pve-manager` will **refuse**
- **Severity: HARD BLOCKER** (pve-manager cannot be emerged)

**Workaround:** None at package level. Build this ebuild before pve-manager.

---

### `www-apps/libjs-qrcodejs`

**Status:** Not in Gentoo tree. Overlay ebuild needed. Small single-file JS library.

**If missing:**
- `pve-manager` has a hard `Depends:` on this
- **Severity: HARD BLOCKER** (pve-manager cannot be emerged)

**At runtime if stubbed:** TOTP/2FA enrollment QR codes will not render.
Authentication still works if a secret is entered manually.

---

### `dev-perl/libpve-network-perl` + Gentoo backend (pve-network)

**Status:** Overlay ebuild needed + custom Gentoo backend plugin required.

**If missing the ebuild:**
- `pve-manager` cannot be emerged (hard dep)
- **Severity: HARD BLOCKER**

**If ebuild installed but Gentoo backend plugin absent:**
- Package installs successfully
- Network configuration changes via web UI (add bridge, modify VLAN) will call
  `ifupdown2` which does not exist on Gentoo → **runtime errors**
- VMs continue running on pre-configured bridges
- Cannot add new bridges or change network config through pxvirt
- **Severity: FUNCTIONAL BLOCKER for network management**

**Workaround:** Pre-configure all bridges via systemd-networkd/NM before starting pxvirt.
Use pxvirt only for VM/CT management, not network config. Implement the Gentoo backend
plugin to fully resolve.

---

### `sys-cluster/pve-cluster` (Phase 1 single-node)

**Status:** Phase 3 package. Not needed for Phase 1 — but pve-manager reads `/etc/pve/`
which on Debian is always a pmxcfs FUSE mount.

**If missing on a standalone node:**
- `/etc/pve/` must be a plain directory pre-seeded with config files
- `pve-cluster.service` must NOT be enabled (there's no corosync)
- pvedaemon works in "standalone" mode if `/etc/pve/` is correctly bootstrapped
- Cluster config sync, HA, cross-node migration all unavailable
- **Severity: NOT A BLOCKER if `/etc/pve/` is manually bootstrapped**

**Required seed files in `/etc/pve/` for standalone operation:**

```
/etc/pve/
├── datacenter.cfg          # keyboard: en-us
├── storage.cfg             # at minimum: dir storage pointing to /var/lib/vz
├── user.cfg                # root@pam entry
├── token.cfg               # empty
└── nodes/
    └── <hostname>/
        └── config          # empty or minimal
```

See `single-node-bootstrap.md` for the full bootstrap procedure.

---

### `app-emulation/vncterm`

**Status:** Overlay ebuild needed (CMake C).

**If missing:**
- VNC console tab in web UI is broken for VMs
- QEMU's built-in VNC server still functions but pxvirt's web-based noVNC integration
  relies on vncterm as the intermediary
- **Severity: Console access broken; VMs still run and are accessible via SSH**

---

### `app-emulation/spiceterm`

**Status:** Not in Gentoo tree. Overlay ebuild needed.

**If missing:**
- SPICE console is unavailable
- noVNC/VNC console still works via vncterm
- No clipboard sharing, audio, or USB redirection via SPICE
- **Severity: LOW — acceptable Phase 1 deferral; defer to Phase 4**

---

### `app-emulation/lxc-pve` (Phase 2)

**Status:** Overlay ebuild needed. No conflict — `app-emulation/lxc` does NOT exist
in the Gentoo main tree (only `acct-group/lxc` and `acct-user/lxc` exist).

**If missing:**
- `pve-container` cannot be emerged
- No LXC container management
- KVM VMs unaffected
- **Severity: Phase 2 blocker only**

---

### `sys-cluster/corosync-pve` vs `sys-cluster/corosync`

**Status:** Gentoo tree has `sys-cluster/corosync-3.1.0` (upstream). pxvirt ships
a patched corosync. **Must verify ABI compatibility before deciding.**

**If upstream corosync is ABI-compatible with pve-cluster:**
- No overlay ebuild needed — use `sys-cluster/corosync` from Gentoo tree ✅

**If upstream corosync is incompatible:**
- Must write `sys-cluster/corosync-pve` overlay ebuild
- Add `CONFLICTS="sys-cluster/corosync"` to prevent both being installed
- **Severity (if incompatible and unaddressed): Phase 3 total blocker**

---

### Gentoo Tree Packages (No Overlay Needed)

These packages already exist in the Gentoo main tree and should be used as-is:

| Package | Gentoo atom | Notes |
|---------|-------------|-------|
| libqb | `sys-cluster/libqb` | v2.0.8+ in tree |
| kronosnet | `sys-cluster/kronosnet` | v1.19+ in tree |
| frr | `net-misc/frr` | v10.x in tree (for BGP/EVPN SDN) |
| swtpm | `app-crypt/swtpm` | v0.10.0 in tree (vTPM for VMs) |
| libtpms | `dev-libs/libtpms` | v0.10.x in tree |
| lxcfs | `sys-fs/lxcfs` | v6.x in tree (note: category is sys-fs not app-emulation) |
| pixman | `x11-libs/pixman` | In tree |
| libgit2 | `dev-libs/libgit2` | In tree |
| libseccomp | `sys-libs/libseccomp` | In tree |
| postfix | `mail-mta/postfix` | In tree (satisfies mail-transport-agent dep) |
| edk2-bin | `sys-firmware/edk2-bin` | x86 only — need pve-edk2-firmware for ARM64/loong |

---

## Perl Module Gap Analysis

Several Perl modules that pxvirt depends on may not have ebuilds in the Gentoo tree.
**Run this check on the target system before writing pxvirt Perl ebuilds:**

```bash
# Check for each required module
for mod in \
  AnyEvent AnyEvent::HTTP \
  Authen::PAM \
  Clone \
  Crypt::OpenSSL::Random Crypt::OpenSSL::RSA \
  Filesys::Df \
  HTTP::Daemon HTTP::Message \
  IO::Stringy \
  Linux::Inotify2 \
  MIME::Base32 \
  Net::DBus Net::IP NetAddr::IP Net::DNS \
  String::ShellQuote \
  YAML::LibYAML \
  File::ReadBackwards File::Slurp \
  Template LWP URI UUID \
  Term::ReadLine::Gnu \
  Crypt::SSLeay; do
    perl -M"$mod" -e 1 2>/dev/null && echo "OK: $mod" || echo "MISSING: $mod"
done
```

Any `MISSING:` module needs either a `dev-perl/` overlay ebuild or (if it exists in the
Gentoo tree) a `package.accept_keywords` entry to unmask it.
