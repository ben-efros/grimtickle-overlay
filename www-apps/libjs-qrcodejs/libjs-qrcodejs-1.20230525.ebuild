# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Cross-browser JavaScript library for generating QR codes"
HOMEPAGE="https://davidshimjs.github.io/qrcodejs/"

# Proxmox libjs-qrcodejs 1.20230525 uses the davidshimjs/qrcodejs master branch.
# The upstream repo has had no commits since 2021; 20230525 is the Proxmox package date.
# We fetch the last upstream commit from GitHub.
GITHUB_COMMIT="d511223"  # last commit on davidshimjs/qrcodejs master
SRC_URI="https://github.com/davidshimjs/qrcodejs/archive/${GITHUB_COMMIT}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~loong"
IUSE="minify"

# uglify-js is needed only when USE=minify.
# Without it, the unminified source is installed as qrcode.min.js — functionally identical.
BDEPEND="minify? ( dev-nodejs/uglify-js )"
RDEPEND=""
DEPEND=""

S="${WORKDIR}/qrcodejs-${GITHUB_COMMIT}"

src_configure() { :; }

src_compile() {
	if use minify; then
		uglifyjs -m -c -o qrcode.min.js qrcode.js \
			|| die "uglifyjs minification failed"
	else
		cp qrcode.js qrcode.min.js || die
	fi
}

src_install() {
	# pveproxy maps /qrcode.min.js -> /usr/share/javascript/qrcodejs/qrcode.min.js
	# The path is hardcoded in PVE/Service/pveproxy.pm — do not change.
	insinto /usr/share/javascript/qrcodejs
	doins qrcode.min.js
	# Also install source for debugging
	doins qrcode.js
}
