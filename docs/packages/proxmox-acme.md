# proxmox-acme → dev-perl/libproxmox-acme-perl

## Overview

`proxmox-acme` provides the ACME/Let's Encrypt client integration for pxvirt. It handles
automatic TLS certificate provisioning and renewal for the web UI (`pveproxy`), replacing
the default self-signed certificate.

## Upstream

- **pxvirt source:** `packages/proxmox-acme/proxmox-acme/`
- **Debian packages:** `libproxmox-acme-perl`, `libproxmox-acme-plugins`
- **Build system:** Makefile + Perl

## Portage Atom

```
dev-perl/libproxmox-acme-perl
```

## Key Dependencies

| Debian | Gentoo atom |
|--------|-------------|
| `libpve-common-perl` | `dev-perl/libpve-common-perl` |
| `curl` | `net-misc/curl` |
| `openssl` | `dev-libs/openssl` |
| `libio-socket-ssl-perl` | `dev-perl/IO-Socket-SSL` |
| `libmozilla-ca-perl` | `dev-perl/Mozilla-CA` |

## Ebuild Notes

- Use `inherit perl-module`
- Installs ACME plugin scripts to `/usr/share/proxmox-acme/`
- Plugin scripts support dns-01 challenges via DNS providers (Cloudflare, Route53, etc.)
- The `libproxmox-acme-plugins` sub-package ships shell scripts for DNS plugins;
  install in the same ebuild or as a separate split package with USE=dns-plugins

## Post-Install

```bash
# Configure ACME account via web UI:
# Datacenter → ACME → Add Account

# Or via CLI:
pvenode acme account register default admin@example.com

# Request certificate for the node:
pvenode acme cert order
```

## Architecture Notes

Pure Perl + shell; arch-independent (`KEYWORDS="~arm64 ~loong ~amd64"`).
