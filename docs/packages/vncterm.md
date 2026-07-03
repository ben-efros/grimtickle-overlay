# vncterm → app-emulation/vncterm

## Overview

`vncterm` is a VNC server that wraps a PTY-based terminal emulator. It provides the
VNC backend for the pxvirt console feature, allowing the web UI to show a terminal
session via noVNC. It is used for both VM serial consoles and LXC console access.

## Upstream

- **pxvirt source:** `packages/vncterm/vncterm/`
- **Debian package:** `vncterm`
- **Build system:** CMake

## Portage Atom

```
app-emulation/vncterm
```

## Key Dependencies

| Debian | Gentoo atom |
|--------|-------------|
| `libgnutls30` | `net-libs/gnutls` |
| `cmake` | `dev-build/cmake` (build) |

## Ebuild Notes

- Use `inherit cmake`
- Standard `cmake_src_configure` + `cmake_src_compile` + `cmake_src_install`
- Binary installed to `/usr/bin/vncterm`
- `KEYWORDS="~arm64 ~loong ~amd64"`

## Architecture Notes

C source; needs to be compiled for target arch. Should work on ARM64 and LoongArch
without patches (no architecture-specific assembly).

## Porting Challenges

- Verify `gnutls` version compatibility; `vncterm` uses TLS for VNC auth
- CMake minimum version: check `CMakeLists.txt` for `cmake_minimum_required`
