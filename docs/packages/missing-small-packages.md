# Missing Small Packages (Hard deps of pve-manager)

These three packages are **hard dependencies of pve-manager** that are not in the Gentoo
main tree. Each must have an overlay ebuild before `emerge sys-apps/pve-manager` will
succeed. They are small and their ebuilds should be straightforward.

---

## proxmox-mini-journalreader → sys-apps/proxmox-mini-journalreader

**pxvirt source:** `packages/proxmox-mini-journalreader/`

**Purpose:** A small C utility that reads systemd journal entries for display in the
pxvirt web UI task log panel. Provides the "Task History" and live log streaming feature.

**If missing:** `emerge sys-apps/pve-manager` refuses (hard `Depends:`). At runtime,
task logs in the web UI will not display.

**Build system:** Makefile (C with libsystemd)

**Portage atom:** `sys-apps/proxmox-mini-journalreader`

**Dependencies:**
| Dep | Gentoo atom |
|-----|-------------|
| `libsystemd-dev` | `sys-apps/systemd` (dev headers) |

**Ebuild notes:**
- Use basic Makefile install
- Binary: `/usr/bin/proxmox-mini-journalreader`
- Small compile, no complex deps beyond libsystemd

---

## proxmox-mail-forward → sys-apps/proxmox-mail-forward

**pxvirt source:** `packages/proxmox-mail-forward/`

**Purpose:** Helper that integrates pxvirt's notification system with a local MTA
(postfix). Forwards task failure and alert emails from pvedaemon to the configured
mail address.

**If missing:** `emerge sys-apps/pve-manager` refuses (hard `Depends:`). At runtime,
email notifications from pxvirt alerts will silently fail.

**Build system:** Rust or shell (check source — `proxmox-mail-forward` is Rust-based)

**Portage atom:** `sys-apps/proxmox-mail-forward`

**Dependencies:**
| Dep | Gentoo atom |
|-----|-------------|
| `postfix` (or any MTA) | `mail-mta/postfix` ✅ |
| Rust (if Rust-based) | `dev-lang/rust` |

**Ebuild notes:**
- If Rust: use `inherit cargo` with vendored crates
- Binary: `/usr/lib/proxmox-mail-forward/proxmox-mail-forward` (or `/usr/bin/`)
- Installed as a sendmail-compatible wrapper or systemd socket service

---

## proxmox-rrd-migration-tool → sys-apps/proxmox-rrd-migration-tool

**pxvirt source:** `packages/proxmox-rrd-migration-tool/`

**Purpose:** Migrates RRD (Round-Robin Database) statistics files from the old format
used in earlier Proxmox/pxvirt versions to the current format. Needed when upgrading
from older installations.

**If missing:** `emerge sys-apps/pve-manager` refuses (hard `Depends:`). At runtime,
fresh installs are completely unaffected — this tool is only invoked during upgrade.
However, it must be installed for pve-manager to emerge.

**Build system:** Rust (check source)

**Portage atom:** `sys-apps/proxmox-rrd-migration-tool`

**Dependencies:**
| Dep | Gentoo atom |
|-----|-------------|
| Rust | `dev-lang/rust` |

**Ebuild notes:**
- If Rust: use `inherit cargo` with vendored crates
- Binary: `/usr/bin/proxmox-rrd-migration-tool`
- For fresh Gentoo installs, the binary just needs to exist and exit successfully
  — actual migration logic is irrelevant

---

## libjs-qrcodejs → www-apps/libjs-qrcodejs

**pxvirt source:** `packages/libjs-qrcodejs/`

**Purpose:** A small JavaScript library that renders QR codes in the browser. Used in
pxvirt's web UI for TOTP (Time-based One-Time Password) 2FA enrollment — the setup
dialog shows a QR code that users scan with an authenticator app.

**If missing:** `emerge sys-apps/pve-manager` refuses (hard `Depends:`). At runtime,
2FA enrollment QR codes don't render; users must manually enter the TOTP secret.

**Build system:** Static file install (single `.js` file)

**Portage atom:** `www-apps/libjs-qrcodejs`

**Dependencies:** None

**Ebuild notes:**
- Trivial: `src_install` copies `qrcode.min.js` to `/usr/share/javascript/qrcodejs/`
- `KEYWORDS="~arm64 ~loong ~amd64"` (arch-independent)
- License: MIT

---

## spiceterm → app-emulation/spiceterm

**pxvirt source:** `packages/spiceterm/`

**Purpose:** A SPICE server that wraps a PTY terminal, providing SPICE protocol access
to VM consoles. Used alongside the SPICE display in QEMU to provide clipboard sharing,
USB redirection, and audio.

**Not in Gentoo tree.** Not a hard dependency of pve-manager — VNC/noVNC still works.
Safe to defer to Phase 2 or later.

**If missing:** SPICE console tab in web UI is broken; VNC console (vncterm + novnc)
still works for all VMs. Clipboard sharing, audio forwarding unavailable.

**Build system:** Makefile + C (uses libspice-server)

**Portage atom:** `app-emulation/spiceterm`

**Dependencies:**
| Dep | Gentoo atom |
|-----|-------------|
| `libspice-server-dev` | `app-emulation/spice` |
| `libglib2.0-dev` | `dev-libs/glib` |

**Ebuild notes:**
- `KEYWORDS="~arm64 ~loong ~amd64"`
- Binary: `/usr/bin/spiceterm`
- Acceptable to defer — not blocking Phase 1 or Phase 2
