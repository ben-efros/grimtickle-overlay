# pve-access-control → dev-perl/libpve-access-control

## Overview

`pve-access-control` implements the pxvirt authentication and authorization system.
It handles user management, PAM authentication, two-factor auth (TOTP/U2F), API tokens,
permission trees, and realm management (pam, pve, ldap, ad).

## Upstream

- **pxvirt source:** `packages/pve-access-control/pve-access-control/`
- **Debian package:** `libpve-access-control`
- **Build system:** Makefile + Perl

## Portage Atom

```
dev-perl/libpve-access-control
```

## Key Dependencies

| Debian | Gentoo atom |
|--------|-------------|
| `libauthen-pam-perl` | `dev-perl/Authen-PAM` |
| `libcrypt-openssl-rsa-perl` | `dev-perl/Crypt-OpenSSL-RSA` |
| `libcrypt-ssleay-perl` | `dev-perl/Crypt-SSLeay` |
| `libnet-ldap-perl` | `dev-perl/perl-ldap` |
| `libpve-common-perl` | `dev-perl/libpve-common-perl` |
| `libpve-rs-perl` | `dev-perl/libpve-rs-perl` |
| `libproxmox-rs-perl` | `dev-perl/libproxmox-rs-perl` |

## Ebuild Notes

- Use `inherit perl-module`
- Installs `pveum` command-line tool to `/usr/bin/`
- Installs PAM helper binary (`pveauth`) — requires `sys-libs/pam`
- Configuration directory: `/etc/pve/` (created by pve-cluster at runtime)

## USE Flags to Consider

| Flag | Effect |
|------|--------|
| `ldap` | Pull in `dev-perl/perl-ldap` for LDAP/AD realm support |
| `u2f` | Pull in `libpve-u2f-server-perl` for hardware 2FA |

## Architecture Notes

Perl + small C helper; keyword `~arm64 ~loong ~amd64`.
