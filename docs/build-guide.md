# Build Guide: Using grimtickle-overlay

This guide walks through adding the overlay to a Gentoo system and installing pxvirt
components with `emerge`.

---

## Prerequisites

- Gentoo Linux with Portage
- `app-eselect/eselect-repository` (preferred) **or** `app-portage/layman`
- `dev-vcs/git` (the overlay is git-based)
- Internet access to sync the overlay

---

## 1. Add the Overlay

### Using eselect-repository (recommended)

```bash
emerge --ask app-eselect/eselect-repository

eselect repository add grimtickle-overlay git \
  https://github.com/YOUR_USER/grimtickle-overlay.git

emaint sync -r grimtickle-overlay
```

### Using layman (legacy)

```bash
emerge --ask app-portage/layman

layman -o https://raw.githubusercontent.com/YOUR_USER/grimtickle-overlay/main/layman.xml \
       -f -a grimtickle-overlay

# Add to /etc/portage/make.conf if not already:
# source /var/lib/layman/make.conf
```

### Local checkout (development)

```bash
git clone https://github.com/YOUR_USER/grimtickle-overlay.git /var/db/repos/grimtickle-overlay

# /etc/portage/repos.conf/grimtickle-overlay.conf
cat > /etc/portage/repos.conf/grimtickle-overlay.conf << 'EOF'
[grimtickle-overlay]
location = /var/db/repos/grimtickle-overlay
sync-type = git
sync-uri = https://github.com/YOUR_USER/grimtickle-overlay.git
priority = 50
EOF

emaint sync -r grimtickle-overlay
```

---

## 2. Architecture Keyword Unmasking

pxvirt targets ARM64 and LoongArch. All overlay ebuilds are keyword-masked as `~arm64`
and `~loong`. Unmask them globally for your arch:

### ARM64

```bash
# /etc/portage/package.accept_keywords/pxvirt
app-emulation/pve-qemu-kvm ~arm64
app-emulation/qemu-server ~arm64
dev-perl/libpve-common-perl ~arm64
dev-perl/libpve-http-server-perl ~arm64
dev-perl/libpve-access-control ~arm64
dev-perl/libpve-guest-common-perl ~arm64
dev-perl/libpve-storage-perl ~arm64
dev-perl/libpve-rs-perl ~arm64
dev-perl/libproxmox-rs-perl ~arm64
net-misc/libpve-network-perl ~arm64
sys-apps/pve-manager ~arm64
www-apps/libjs-extjs ~arm64
www-apps/proxmox-widget-toolkit ~arm64
www-apps/novnc-pve ~arm64
www-apps/pve-xtermjs ~arm64
app-emulation/vncterm ~arm64
```

### LoongArch

Replace `~arm64` with `~loong` in the above file, or add a second stanza:

```bash
# append to /etc/portage/package.accept_keywords/pxvirt
*/* ~loong   # accept all ~loong packages (broad; use per-package for tighter control)
```

---

## 3. USE Flags

Key USE flags to configure before emerging. Add to `/etc/portage/package.use/pxvirt`:

```bash
# Storage backends for pve-storage
dev-perl/libpve-storage-perl  zfs ceph nfs iscsi lvm

# QEMU: enable KVM, disable unnecessary targets
app-emulation/pve-qemu-kvm  kvm spice vnc  -sdl -gtk -opengl

# Ceph: already in overlay — tune for your needs
sys-cluster/ceph  -jemalloc -babeltrace radosgw

# LXC (Phase 2)
app-emulation/lxc-pve  apparmor seccomp

# Corosync (Phase 3)
sys-cluster/corosync-pve  kronosnet

# Manager: enable ACME/Let's Encrypt if desired
sys-apps/pve-manager  acme
```

### Global USE flags (make.conf suggestions)

```bash
# /etc/portage/make.conf
USE="systemd dbus openssl curl ssl zlib lzma"
```

---

## 4. Phase 1 Install: Minimal Viable Node

Install in dependency order. Once ebuilds are written, a single `emerge` will resolve the
tree automatically, but understanding the order helps when troubleshooting.

```bash
# Step 1: Rust FFI libraries (required by many pxvirt Perl packages)
emerge dev-perl/libproxmox-rs-perl dev-perl/libpve-rs-perl

# Step 2: Core Perl library stack
emerge dev-perl/libpve-common-perl

# Step 3: HTTP server and access control (parallel, no interdep)
emerge dev-perl/libpve-http-server-perl dev-perl/libpve-access-control

# Step 4: Guest common (depends on access-control)
emerge dev-perl/libpve-guest-common-perl

# Step 5: Storage and network abstraction
emerge dev-perl/libpve-storage-perl net-misc/libpve-network-perl

# Step 6: QEMU binary (patched; large compile)
emerge app-emulation/pve-qemu-kvm

# Step 7: QEMU server daemon
emerge app-emulation/qemu-server

# Step 8: Web UI assets (arch-independent, fast)
emerge www-apps/libjs-extjs www-apps/proxmox-widget-toolkit \
       www-apps/novnc-pve www-apps/pve-xtermjs app-emulation/vncterm

# Step 9: Top-level manager
emerge sys-apps/pve-manager
```

Or as a single command (Portage resolves order):

```bash
emerge sys-apps/pve-manager
```

---

## 5. Phase 2 Install: LXC Containers

```bash
emerge app-emulation/lxc-pve app-emulation/lxcfs \
       app-emulation/pve-lxc-syscalld app-emulation/pve-container
```

---

## 6. Phase 3 Install: Cluster & HA

```bash
emerge sys-cluster/corosync-pve sys-cluster/pve-cluster sys-cluster/pve-ha-manager
```

---

## 7. Phase 4 Install: Advanced

```bash
# Firewall
emerge net-firewall/pve-firewall

# ACME / Let's Encrypt
emerge dev-perl/libproxmox-acme-perl

# Backup server/client
emerge app-backup/proxmox-backup

# Ceph (already in overlay)
emerge sys-cluster/ceph
```

---

## 8. Post-Install Setup

After installing Phase 1, perform initial configuration:

```bash
# Start the pvedaemon and pveproxy services
systemctl enable --now pvedaemon.service
systemctl enable --now pveproxy.service
systemctl enable --now pvestatd.service

# Access the web UI at https://<host-ip>:8006
```

Set up the admin user:

```bash
pveum useradd root@pam   # or use the existing root@pam
pveum passwd root@pam
```

Configure the VM bridge (see [networking.md](networking.md) for full guide):

```bash
# Quick example with systemd-networkd
cp /etc/systemd/network/examples/10-vmbr0.netdev /etc/systemd/network/
cp /etc/systemd/network/examples/20-vmbr0.network /etc/systemd/network/
# Edit 20-vmbr0.network with your IP/gateway
networkctl reload
```

---

## 9. Troubleshooting

### Missing Perl module at runtime

If pvemanager fails with `Can't locate Some/Module.pm`:

```bash
# Find the Gentoo package providing it
e-file Some/Module.pm
# Or search
emerge --search "libsome-module-perl"
```

### Rust build failures

pxvirt's Rust packages require Rust >= 1.75. Ensure:

```bash
emerge dev-lang/rust
rustc --version
```

If the system Rust is too old, try `rust-bin`:

```bash
emerge dev-lang/rust-bin
```

### QEMU fails to start VMs (KVM not available)

Check kernel module and hardware:

```bash
modprobe kvm_arm64    # ARM
modprobe kvm          # x86
ls /dev/kvm           # must exist
```

Ensure your CPU supports hardware virtualization and it is enabled in firmware/BIOS.

### pve-network fails to configure bridges

On Gentoo, `pve-network`'s Debian backend will not work. Use the Gentoo-specific integration
described in [networking.md](networking.md). Alternatively, pre-configure bridges manually
and use pxvirt's "manual" network mode.

### Keyword errors

```
!!! All ebuilds that could satisfy "..." have been masked.
```

Add the required `~arm64` or `~loong` keyword to
`/etc/portage/package.accept_keywords/pxvirt`.
