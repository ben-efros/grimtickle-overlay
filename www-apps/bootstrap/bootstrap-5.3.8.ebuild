# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Bootstrap 5 CSS/JS framework dist files"
HOMEPAGE="https://getbootstrap.com/"
SRC_URI="https://github.com/twbs/bootstrap/releases/download/v${PV}/bootstrap-${PV}-dist.zip
	-> ${P}-dist.zip"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~loong"

BDEPEND="app-arch/unzip"

S="${WORKDIR}/bootstrap-${PV}-dist"

src_install() {
	# pve-http-server's AnyEvent.pm serves /bootstrap5/ -> /usr/share/bootstrap-html/
	insinto /usr/share/bootstrap-html
	doins -r css js
}
