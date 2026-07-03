# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3

DESCRIPTION="ExtJS 7 cross-browser JavaScript library (Proxmox/pxvirt edition)"
HOMEPAGE="https://www.sencha.com/ https://git.proxmox.com/?p=extjs.git"

# Proxmox maintains a patched ExtJS 7 tree with additional locales (Georgian etc.)
# and Proxmox-specific adjustments. Fetch from Proxmox git.
# EGIT_COMMIT corresponds to libjs-extjs 7.0.0-5 (bookworm).
EGIT_REPO_URI="git://git.proxmox.com/git/extjs.git"
EGIT_COMMIT="HEAD"  # TODO: pin to exact commit for reproducible builds
# To find the commit: git ls-remote git://git.proxmox.com/git/extjs.git

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~loong"
IUSE=""

# No build deps — pre-built JS/CSS in the repo's build/ directory.
# The Proxmox extjs repo ships the compiled output; there is no build step.
BDEPEND=""
RDEPEND=""
DEPEND=""

src_unpack() {
	git-r3_src_unpack
}

src_configure() { :; }
src_compile() { :; }

src_install() {
	local destdir=/usr/share/javascript/extjs

	# Install pre-built JS bundles
	insinto "${destdir}"
	doins build/ext-all.js
	doins build/ext-all-debug.js

	# Classic theme locale files (all locales shipped by Proxmox)
	doins -r build/classic/locale

	# Crisp theme (the theme used by Proxmox web UI)
	doins -r build/classic/theme-crisp

	# Charts extension
	insinto "${destdir}/packages/charts/classic"
	doins build/packages/charts/classic/charts.js
	doins build/packages/charts/classic/charts-debug.js
	doins -r build/packages/charts/classic/crisp
}
