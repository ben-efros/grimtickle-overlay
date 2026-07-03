# `dev-perl/libpve-common-perl` — PVE Base Perl Library

## Package Overview

| Field | Value |
|-------|-------|
| Ebuild | `dev-perl/libpve-common-perl/libpve-common-perl-9.0.11.ebuild` |
| Source | `github.com/jiangcuo/pve-common` (pxvirt fork) |
| Build system | Pure Perl — `make install` only |
| Output | 28 Perl modules under `PVE::` namespace |
| Priority | **Critical path** — required by every other pxvirt Perl package |

## What This Package Provides

The foundation library for the entire pxvirt/Proxmox VE Perl management stack.
Every daemon (`pvedaemon`, `pveproxy`, `pvescheduler`) and every Perl component
imports from `PVE::Tools`, `PVE::JSONSchema`, or `PVE::RESTHandler`.

### Key Modules

| Module | Purpose |
|--------|---------|
| `PVE::Tools` | Core utilities: `run_command`, `lock_file`, `file_read_*`, logging |
| `PVE::JSONSchema` | API parameter validation, schema definition DSL |
| `PVE::INotify` | inotify-based config file watching; `/etc/network/interfaces` parser |
| `PVE::SectionConfig` | INI-style sectioned config file parser (storage, firewall, etc.) |
| `PVE::RESTHandler` | Base class for all REST API handlers |
| `PVE::RESTEnvironment` | Per-request context object |
| `PVE::CLIHandler` | CLI command dispatch (pvesh, pveceph, etc.) |
| `PVE::Network` | Network interface config parsing (reads `/etc/network/interfaces`) |
| `PVE::ProcFSTools` | `/proc` parsing: memory, CPU, network stats |
| `PVE::CGroup` | cgroup v2 helpers |
| `PVE::Daemon` | Daemonisation, signal handling, pidfile management |
| `PVE::Ticket` | API authentication ticket (cookie) generation |
| `PVE::CalendarEvent` | Cron-like schedule parsing (VEVENT format) |
| `PVE::OTP` | TOTP/HOTP implementation |
| `PVE::Systemd` | systemd unit management via D-Bus |
| `PVE::Job::Registry` | Scheduled job registry |

## Dependency Audit (2025-07-03)

All 20 runtime Perl dependencies confirmed in Gentoo portage tree:

| Debian package | Gentoo package | Status |
|----------------|----------------|--------|
| libanyevent-perl | dev-perl/AnyEvent | ✅ in tree |
| libclone-perl | dev-perl/Clone | ✅ in tree |
| libcrypt-openssl-random-perl | dev-perl/Crypt-OpenSSL-Random | ✅ in tree |
| libcrypt-openssl-rsa-perl | dev-perl/Crypt-OpenSSL-RSA | ✅ in tree |
| libdevel-cycle-perl | dev-perl/Devel-Cycle | ✅ in tree |
| libfilesys-df-perl | dev-perl/Filesys-Df | ✅ in tree |
| libhttp-daemon-perl | dev-perl/HTTP-Daemon | ✅ in tree |
| libhttp-message-perl | dev-perl/HTTP-Message | ✅ in tree |
| libio-stringy-perl | dev-perl/IO-stringy | ✅ in tree |
| libjson-perl | dev-perl/JSON | ✅ in tree |
| liblinux-inotify2-perl | dev-perl/Linux-Inotify2 | ✅ in tree |
| libmime-base32-perl | dev-perl/MIME-Base32 | ✅ in tree |
| libnet-dbus-perl | dev-perl/Net-DBus | ✅ in tree |
| libnet-ip-perl | dev-perl/Net-IP | ✅ in tree |
| libnetaddr-ip-perl | dev-perl/NetAddr-IP | ✅ in tree |
| libstring-shellquote-perl | dev-perl/String-ShellQuote | ✅ in tree |
| libtimedate-perl | dev-perl/TimeDate | ✅ in tree |
| liburi-perl | dev-perl/URI | ✅ in tree |
| libwww-perl | dev-perl/libwww-perl | ✅ in tree |
| libyaml-libyaml-perl | dev-perl/YAML-LibYAML | ✅ in tree |

### Deferred Dependencies (not yet ported)

| Debian package | Status | Notes |
|----------------|--------|-------|
| `libproxmox-rs-perl` | ⏳ todo | `common/` workspace of proxmox-perl-rs; provides `Proxmox::RS::*` base |
| `libproxmox-acme-perl` | ⏳ todo | ACME/Let's Encrypt client; runtime for cert management only |

## Gentoo-Specific Notes

### Network Configuration (`PVE::INotify`, `PVE::Network`)

`INotify.pm` watches `/etc/network/interfaces` and `Network.pm` reads it.
On Gentoo with `systemd-networkd` or `NetworkManager`, this file does not exist.

- `PVE::INotify` watches a non-existent file — harmless, no callbacks fire
- `PVE::Network::read_etc_network_interfaces()` returns empty config
- GUI **Network** tab shows no interfaces — expected until `network-backend-plugin`

No patches needed; the Gentoo network backend plugin adapts at the pve-network layer.

### `ifupdown2` Detection

`Network.pm:1527` does `if (-e '/usr/share/ifupdown2/ifupdown2')` at runtime.
Always false on Gentoo — harmless.

## Phase Position

Phase 1 critical path. Unblocks:

```
libpve-common-perl (THIS)
  ├── libpve-http-server-perl → pveproxy web server
  │     └── libpve-access-control → auth, users, realms
  │           ├── libpve-storage-perl
  │           └── libpve-network-perl
  └── libpve-guest-common-perl
        ├── pve-container
        └── qemu-server
```

## Status

| Task | Status |
|------|--------|
| Ebuild written | ✅ 2025-07-03 |
| All 20 Perl deps confirmed in tree | ✅ |
| Build test on Gentoo | ⏳ pending |
| Network.pm behaviour documented | ✅ |
