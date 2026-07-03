# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3

DESCRIPTION="xterm.js-based terminal frontend for pxvirt (HTML/JS assets)"
HOMEPAGE="https://xtermjs.org/ https://git.proxmox.com/?p=pve-xtermjs.git"

# The xterm.js src/ directory contains pre-extracted npm tarballs:
#   @xterm/xterm 5.5.0  — xterm.js + xterm.css
#   @xterm/addon-fit 0.9.0  — addon-fit.js
#   @xterm/addon-webgl 0.17.0  — addon-webgl.js
# These are committed directly to the Proxmox git repo (no npm run at build time).
# Fetch from Proxmox git; only the xterm.js/ subdirectory is used by this ebuild.
# (The termproxy/ subdir is a separate Rust package: sys-apps/proxmox-termproxy)
EGIT_REPO_URI="git://git.proxmox.com/git/pve-xtermjs.git"
EGIT_COMMIT="HEAD"  # TODO: pin to commit for reproducible builds

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~loong"
IUSE=""

# No runtime deps — pure static JS/CSS served by pveproxy.
# Depends: proxmox-termproxy at runtime (pveproxy config), not a package dep.
BDEPEND=""
RDEPEND="sys-apps/proxmox-termproxy"
DEPEND=""

src_unpack() {
	git-r3_src_unpack
}

src_configure() { :; }

src_compile() {
	# Substitute @VERSION@ placeholder in the two HTML template files.
	# Mirrors debian/rules: sed -e 's/@VERSION@/$(DEB_VERSION)/' src/index.html.tpl.in
	# The ?version= query string busts browser caches after upgrades.
	sed -e "s/@VERSION@/${PV}-pve/g" \
		xterm.js/src/index.html.tpl.in > xterm.js/src/index.html.tpl \
		|| die "sed index.html.tpl.in failed"
	sed -e "s/@VERSION@/${PV}-pve/g" \
		xterm.js/src/index.html.hbs.in > xterm.js/src/index.html.hbs \
		|| die "sed index.html.hbs.in failed"
}

src_install() {
	# pveproxy maps /xtermjs/* -> /usr/share/pve-xtermjs/
	# (configured in PVE/Service/pveproxy.pm)
	insinto /usr/share/pve-xtermjs
	doins xterm.js/src/xterm.js
	doins xterm.js/src/xterm.js.map
	doins xterm.js/src/xterm.css
	doins xterm.js/src/addon-fit.js
	doins xterm.js/src/addon-fit.js.map
	doins xterm.js/src/addon-webgl.js
	doins xterm.js/src/addon-webgl.js.map
	doins xterm.js/src/main.js
	doins xterm.js/src/util.js
	doins xterm.js/src/style.css
	doins xterm.js/src/index.html.tpl
	doins xterm.js/src/index.html.hbs
}
