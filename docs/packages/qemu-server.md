# qemu-server → app-emulation/qemu-server

## Overview

`qemu-server` is the Perl management daemon for KVM virtual machines. It provides `qm`
(the VM CLI), `qmrestore`, `qmrestore`, and the QAPI bindings that the web UI calls to
start, stop, migrate, and configure VMs. It drives `pve-qemu-kvm` under the hood.

## Upstream

- **pxvirt source:** `packages/qemu-server/qemu-server/`
- **Debian package:** `qemu-server`
- **Build system:** Makefile + Perl

## Portage Atom

```
app-emulation/qemu-server
```

## Key Dependencies

| Debian | Gentoo atom | Notes |
|--------|-------------|-------|
| `pve-qemu-kvm` | `app-emulation/pve-qemu-kvm` | The QEMU binary |
| `libpve-storage-perl` | `dev-perl/libpve-storage-perl` | |
| `libpve-common-perl` | `dev-perl/libpve-common-perl` | |
| `libpve-access-control` | `dev-perl/libpve-access-control` | |
| `libpve-guest-common-perl` | `dev-perl/libpve-guest-common-perl` | |
| `conntrack` | `net-firewall/conntrack-tools` | Connection tracking |
| `nbd-client` | `sys-block/nbd` | NBD storage |
| `socat` | `net-misc/socat` | VM serial console |
| `ovmf` | `sys-firmware/edk2` or `pve-edk2-firmware` | UEFI firmware |
| `libfile-readbackwards-perl` | `dev-perl/File-ReadBackwards` | Log tailing |
| `libjson-perl` | `dev-perl/JSON` | |

## Ebuild Notes

- Use `inherit perl-module`
- Installs: `qm`, `qmrestore`, `qmrestore`, `qemu-server` service files
- systemd units: `qemu-server.service` — enable with `systemctl enable qemu-server`
- UEFI firmware: `pve-edk2-firmware` ships ARM64 + LoongArch UEFI blobs; on Gentoo,
  use `sys-firmware/edk2` with appropriate USE flags, or install the prebuilt blobs from
  the pxvirt release.

## USE Flags

| Flag | Effect |
|------|--------|
| `spice` | Enable SPICE USB redirection agents |
| `uefi` | Pull in UEFI firmware package |

## Porting Challenges

- `qemu-server` at runtime invokes `kvm` via the absolute path `/usr/bin/kvm` (a symlink
  on Debian). On Gentoo, ensure `/usr/bin/kvm` → `qemu-system-aarch64` or
  `qemu-system-loongarch64` as appropriate, or patch the Perl invocation.
- Migration uses SSH tunnels — no special Gentoo handling needed but firewall rules
  (port 60000–60050) must be open between cluster nodes.

## Architecture Notes

Pure Perl runtime; arch-dependent only due to the QEMU binary dependency.
`KEYWORDS="~arm64 ~loong"`.
