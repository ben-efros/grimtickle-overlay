# pve-qemu → app-emulation/pve-qemu-kvm

## Overview

`pve-qemu` is QEMU patched with pxvirt-specific extensions: live migration enhancements,
Proxmox backup protocol (PBP) support, dirty-bitmap-based incremental backup, and
architecture-specific fixes for ARM64 and LoongArch.

## Upstream

- **pxvirt source:** `packages/pve-qemu/pve-qemu/`
- **Debian package:** `pve-qemu-kvm`
- **Build system:** GNU autotools (QEMU's `./configure` + `make`)

## Portage Atom

```
app-emulation/pve-qemu-kvm
```

## Key Dependencies

| Debian | Gentoo atom | Notes |
|--------|-------------|-------|
| `ceph-common` | `sys-cluster/ceph` | USE=ceph for RBD storage |
| `libgnutls-dev` | `net-libs/gnutls` | TLS support |
| `libusb-1.0-0-dev` | `dev-libs/libusb` | USB passthrough |
| `libspice-server-dev` | `app-emulation/spice` | SPICE display USE=spice |
| `libaio-dev` | `dev-libs/libaio` | Async I/O |
| `libpixman-1-dev` | `x11-libs/pixman` | 2D rasterization |
| `zlib1g-dev` | `sys-libs/zlib` | |
| `liblz4-dev` | `app-arch/lz4` | VM state compression |
| `libjpeg-dev` | `media-libs/libjpeg-turbo` | USE=vnc |
| `libpng-dev` | `media-libs/libpng` | USE=vnc |
| `libvncserver-dev` | `net-libs/libvncserver` | USE=vnc |
| `libslirp-dev` | `net-libs/libslirp` | User-mode networking |

## Configure Flags

The QEMU configure invocation for pve-qemu should specify:

```bash
./configure \
  --prefix=/usr \
  --sysconfdir=/etc \
  --localstatedir=/var \
  --target-list="aarch64-softmmu,loongarch64-softmmu" \
  --enable-kvm \
  --enable-linux-aio \
  --enable-spice \
  --enable-vnc \
  --enable-vnc-png \
  --enable-vnc-jpeg \
  --disable-gtk \
  --disable-sdl \
  --disable-opengl \
  --enable-gnutls \
  --enable-rbd           # USE=ceph
```

Adjust `--target-list` for your architecture. For amd64 also include `x86_64-softmmu`.

## USE Flags

| Flag | Effect |
|------|--------|
| `kvm` | Enable KVM acceleration (required for performance) |
| `spice` | Enable SPICE protocol; pulls in `app-emulation/spice` |
| `vnc` | Enable VNC display |
| `ceph` | Enable Ceph RBD block driver |
| `usbredir` | Enable USB redirection via SPICE |

## Porting Challenges

- **ARM64:** QEMU's `configure` supports `aarch64-softmmu`. pxvirt patches may add
  ARM-specific features; check `patches/series.arm64` in the pxvirt source.
- **LoongArch:** Target `loongarch64-softmmu`. LoongArch KVM requires kernel ≥ 6.4 with
  `CONFIG_KVM_LOONGARCH`.
- **Patch application:** Apply patches from `packages/pve-qemu/pve-qemu/debian/patches/`
  in series order before configuring.
- **Large compile:** Allow 30–90 minutes on first build; set `MAKEOPTS="-j$(nproc)"`.

## Architecture Notes

`KEYWORDS="~arm64 ~loong"`. Do not set `~amd64` unless tested. The pxvirt patch series may
differ by architecture — check `series` vs `series.arm64` / `series.loong` in the package.
