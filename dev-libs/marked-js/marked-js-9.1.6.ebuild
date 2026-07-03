# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Marked — fast markdown parser and compiler (JavaScript library)"
HOMEPAGE="https://marked.js.org https://www.npmjs.com/package/marked"

# Sourced from the npm registry tarball which contains both marked.js and
# marked.min.js. Version 9.x is the LTS-era version used by Proxmox
# bookworm/trixie builds.
MY_P="marked-9.1.6"
SRC_URI="https://registry.npmjs.org/marked/-/${MY_P}.tgz -> ${MY_P}.tgz"
S="${WORKDIR}/package"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~loong"

RDEPEND=""
BDEPEND=""

src_compile() { :; }

src_install() {
	# Install to the path expected by proxmox-widget-toolkit's Makefile:
	# MARKEDJS=/usr/share/javascript/marked/marked.js
	insinto /usr/share/javascript/marked
	newins marked.min.js marked.js
}
