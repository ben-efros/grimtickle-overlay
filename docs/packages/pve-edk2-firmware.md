# pve-edk2-firmware → sys-firmware/pve-edk2-firmware

## Overview

`pve-edk2-firmware` ships pre-built UEFI firmware blobs for **ARM64 (AArch64)** and
**LoongArch64** virtual machines. These are used by QEMU when a VM is configured to boot
via UEFI (OVMF).

> ⚠️ **Critical for ARM64/LoongArch VM usability.** The Gentoo main tree provides
> `sys-firmware/edk2-bin` but it is **x86-only** (amd64/i386). ARM64 and LoongArch UEFI
> firmware is not included. Without `pve-edk2-firmware`, nearly all ARM64 cloud images
> will refuse to boot.

## Upstream

- **pxvirt source:** `packages/pve-edk2-firmware/pve-edk2-firmware/`
- **Debian package:** `pve-edk2-firmware`
- **Build system:** EDK2 cross-compilation (very complex) — **use pre-built blobs**

## Portage Atom

```
sys-firmware/pve-edk2-firmware
```

## Why This is a Phase 1 Blocker for ARM64

Most ARM64 Linux distributions ship cloud images that:
- Use an EFI-signed GRUB2 bootloader
- Require the system to present a UEFI environment
- Will not fall back to legacy BIOS boot

Without UEFI firmware:
- Ubuntu, Debian, Fedora, Rocky ARM64 cloud images → **will not boot**
- Custom-built legacy-BIOS ARM64 images may boot, but this is an atypical setup
- LoongArch has no viable legacy BIOS path at all; UEFI is mandatory

## Build Approach: Use Pre-built Blobs

Building EDK2 from source requires a complex cross-compilation toolchain
(`gcc-aarch64-linux-gnu`, `gcc-i686-linux-gnu`, `iasl`, `nasm`, `mtools`, etc.).
For the overlay ebuild, **use the pre-built blobs** that pxvirt packages and ships.

```bash
# The Debian package bundles:
# /usr/share/pve-edk2-firmware/aarch64/
#   AAVMF_CODE.fd        ← read-only code ROM
#   AAVMF_VARS.fd        ← read-write variable store template
# /usr/share/pve-edk2-firmware/loongarch64/
#   LOONGARCH_CODE.fd
#   LOONGARCH_VARS.fd
```

## Ebuild Notes

- Fetch the pre-built blobs from the pxvirt release (or extract from the `.deb`)
- No compilation — `src_install` only
- Install to `/usr/share/pve-edk2-firmware/{aarch64,loongarch64}/`
- `KEYWORDS="~arm64 ~loong ~amd64"` (arch-independent blobs)
- Create a compatibility symlink if qemu-server looks for firmware at
  `/usr/share/AAVMF/` (Debian path):

```bash
dosym ../pve-edk2-firmware/aarch64/AAVMF_CODE.fd /usr/share/AAVMF/AAVMF_CODE.fd
dosym ../pve-edk2-firmware/aarch64/AAVMF_VARS.fd /usr/share/AAVMF/AAVMF_VARS.fd
```

## Key Dependencies

None — pure firmware blobs.

## Relationship to sys-firmware/edk2-bin

| Package | Architectures | Use case |
|---------|--------------|---------|
| `sys-firmware/edk2-bin` (Gentoo tree) | x86, i386 | x86_64 VMs on any host |
| `sys-firmware/pve-edk2-firmware` (this overlay) | aarch64, loongarch64 | ARM64/LoongArch VMs |

Both can be installed simultaneously — they install to different paths.

## Architecture Notes

Firmware blobs are architecture-neutral data files; the ebuild itself is
`KEYWORDS="~arm64 ~loong ~amd64"`. The blobs run *inside* the VM guest (the VM's
virtual firmware), not on the host CPU directly.
