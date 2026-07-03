# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# DEFERRED — see docs/packages/termproxy.md
#
# This ebuild skeleton is intentionally incomplete.
# It requires a Cargo vendor tarball which must be generated before this
# ebuild can build. See the instructions below.
#
# TO COMPLETE THIS EBUILD:
#
#   1. Fetch the source:
#        git clone git://git.proxmox.com/git/pve-xtermjs.git
#        cd pve-xtermjs/termproxy
#
#   2. Generate vendor tarball:
#        cargo vendor vendor
#        tar czf proxmox-termproxy-2.0.2-vendor.tar.gz vendor/
#        # Copy tarball to your DISTDIR or a reachable URL
#
#   3. Update SRC_URI with the vendor tarball location.
#
#   4. Remove this header comment and the `die` in pkg_setup.
#
# See also: docs/packages/termproxy.md

inherit cargo

DESCRIPTION="WebSocket-to-PTY proxy for pxvirt xterm.js console backend"
HOMEPAGE="https://git.proxmox.com/?p=pve-xtermjs.git"

# Source: termproxy/ subdir of the pve-xtermjs git repo
# Proxmox package: proxmox-termproxy 2.0.2
COMMIT="HEAD"  # TODO: pin to exact commit
SRC_URI="
	git://git.proxmox.com/git/pve-xtermjs.git
	https://your-distfiles-server/proxmox-termproxy-${PV}-vendor.tar.gz
"

# Rust deps (from Cargo.toml):
#   anyhow = "1"               -> dev-libs/anyhow (in Gentoo tree)
#   libc = "0.2.107"           -> dev-libs/libc (in Gentoo tree)
#   mio = "1" (net, os-ext)    -> dev-libs/mio (in Gentoo tree)
#   nix = "0.29" (fs,ioctl..)  -> dev-libs/nix (in Gentoo tree)
#   pico-args = "0.5"          -> dev-libs/pico-args (check tree)
#   proxmox-io = "1"           -> must be in vendor tarball
#   form_urlencoded = "1.2"    -> dev-libs/url (in Gentoo tree as part of url crate)

S="${WORKDIR}/pve-xtermjs/termproxy"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~loong"
IUSE=""

BDEPEND="virtual/rust"
RDEPEND=""
DEPEND=""

pkg_setup() {
	die "proxmox-termproxy ebuild is a skeleton — vendor tarball not yet generated. See docs/packages/termproxy.md"
}

src_compile() {
	cargo_src_compile --bin proxmox-termproxy
}

src_install() {
	cargo_src_install
	# termproxy is invoked by pveproxy as a subprocess; it does not run as a daemon.
	# No service file needed.
}
