# pve-common → dev-perl/libpve-common-perl

## Overview

`pve-common` provides the core Perl utility library used by virtually every other pxvirt
component. It includes helpers for JSON/REST API handling, configuration file parsing,
certificate management, task logging, and IPC.

## Upstream

- **pxvirt source:** `packages/pve-common/pve-common/`
- **Debian package:** `libpve-common-perl`
- **Build system:** Makefile + Perl module install

## Portage Atom

```
dev-perl/libpve-common-perl
```

## Key Dependencies

### Build deps
| Debian | Gentoo atom |
|--------|-------------|
| `perl` | `dev-lang/perl` |
| `debhelper` | (no equivalent needed) |
| `libproxmox-rs-perl` | `dev-perl/libproxmox-rs-perl` |

### Runtime deps
| Debian | Gentoo atom |
|--------|-------------|
| `libanyevent-perl` | `dev-perl/AnyEvent` |
| `libclone-perl` | `dev-perl/Clone` |
| `libcrypt-openssl-random-perl` | `dev-perl/Crypt-OpenSSL-Random` |
| `libcrypt-openssl-rsa-perl` | `dev-perl/Crypt-OpenSSL-RSA` |
| `libfilesys-df-perl` | `dev-perl/Filesys-Df` |
| `libhttp-daemon-perl` | `dev-perl/HTTP-Daemon` |
| `libhttp-message-perl` | `dev-perl/HTTP-Message` |
| `libio-stringy-perl` | `dev-perl/IO-stringy` |
| `libjson-perl` | `dev-perl/JSON` |
| `liblinux-inotify2-perl` | `dev-perl/Linux-Inotify2` |
| `libmime-base32-perl` | `dev-perl/MIME-Base32` |
| `libnet-dbus-perl` | `dev-perl/Net-DBus` |
| `libnet-ip-perl` | `dev-perl/Net-IP` |
| `libnetaddr-ip-perl` | `dev-perl/NetAddr-IP` |
| `libproxmox-rs-perl` | `dev-perl/libproxmox-rs-perl` |
| `libstring-shellquote-perl` | `dev-perl/String-ShellQuote` |
| `libyaml-libyaml-perl` | `dev-perl/YAML-LibYAML` |

## Ebuild Notes

- Use `inherit perl-module`
- Install to `$(perl_get_vendorlib)`
- The `Makefile` uses `PERL_VENDORLIB` — pass via `make install DESTDIR="${ED}" PREFIX=/usr`
- No compiled XS; pure Perl install

## Porting Challenges

- `libproxmox-rs-perl` is a Rust-generated XS module; it must be built first (see
  `packages/proxmox-perl-rs.md`).
- Some Perl modules may not exist in Gentoo's tree and will need overlay ebuilds.

## Architecture Notes

Pure Perl; `arch-independent` (`KEYWORDS="~arm64 ~loong ~amd64"`).
