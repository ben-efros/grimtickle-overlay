# corosync-pve → sys-cluster/corosync-pve

## Overview

`corosync-pve` is pxvirt's patched build of Corosync, the cluster membership and
messaging layer. pxvirt adds patches for additional quorum modes, improved ARM support,
and integration with the pxvirt cluster management stack.

## Upstream

- **pxvirt source:** `packages/corosync-pve/corosync-pve/`
- **Debian package:** `corosync` (pve-patched)
- **Build system:** autotools

## Portage Atom

```
sys-cluster/corosync-pve
```

> **Check first:** Upstream `sys-cluster/corosync` may exist in the Gentoo tree. Only
> create an overlay ebuild if pxvirt's patches are required (they likely are).

## Key Dependencies

| Debian | Gentoo atom |
|--------|-------------|
| `libqb-dev` | `sys-libs/libqb` |
| `kronosnet` | `sys-cluster/kronosnet` |
| `libknet-dev` | `sys-cluster/kronosnet` (dev headers) |
| `libgrp-dev` | `sys-libs/libgrp` or similar |
| `libnss3-dev` | `dev-libs/nss` |
| `libcrypto++-dev` | `dev-libs/crypto++` (optional) |
| `doxygen` | `app-doc/doxygen` (build, for docs) |

## Ebuild Notes

- Use `inherit autotools`
- Conflicts with `sys-cluster/corosync` from Gentoo tree — add `!sys-cluster/corosync`
  to `CONFLICTS`
- Installs: `corosync`, `corosync-notifyd`, `corosync-vqsim`, `corosync-cfgtool`
- systemd units: `corosync.service`
- Config: `/etc/corosync/corosync.conf`

## Configuration

Minimal `corosync.conf` for a 2-node cluster (replace IPs):

```conf
totem {
    version: 2
    cluster_name: pxvirt
    transport: knet
    crypto_hash: sha256
    crypto_cipher: aes256
}

nodelist {
    node {
        ring0_addr: 192.168.1.10
        name: node1
        nodeid: 1
    }
    node {
        ring0_addr: 192.168.1.11
        name: node2
        nodeid: 2
    }
}

quorum {
    provider: corosync_votequorum
    two_node: 1
}

logging {
    to_syslog: yes
}
```

## Architecture Notes

C source. ARM64 support improved in pxvirt patches. `KEYWORDS="~arm64 ~loong"`.
