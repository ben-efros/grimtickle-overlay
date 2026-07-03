# pve-http-server → dev-perl/libpve-http-server-perl

## Overview

`pve-http-server` provides the AnyEvent-based HTTP/HTTPS server used by `pveproxy` and
`pvedaemon`. It implements the REST API server infrastructure, including TLS termination,
keep-alive, and chunked transfer.

## Upstream

- **pxvirt source:** `packages/pve-http-server/pve-http-server/`
- **Debian package:** `libpve-http-server-perl`
- **Build system:** Makefile + Perl

## Portage Atom

```
dev-perl/libpve-http-server-perl
```

## Key Dependencies

| Debian | Gentoo atom |
|--------|-------------|
| `libanyevent-perl` | `dev-perl/AnyEvent` |
| `libanyevent-http-perl` | `dev-perl/AnyEvent-HTTP` |
| `libhttp-message-perl` | `dev-perl/HTTP-Message` |
| `libpve-common-perl` | `dev-perl/libpve-common-perl` |
| `libnet-ssleay-perl` | `dev-perl/Net-SSLeay` |
| `libio-socket-ssl-perl` | `dev-perl/IO-Socket-SSL` |

## Ebuild Notes

- Use `inherit perl-module`
- Pure Perl, no XS
- Install configuration for TLS certificates references `/etc/pve/` paths

## Architecture Notes

Pure Perl; arch-independent (`KEYWORDS="~arm64 ~loong ~amd64"`).
