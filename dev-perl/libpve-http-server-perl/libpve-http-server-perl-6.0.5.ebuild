# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Pure Perl HTTP server library — no XS, no compilation.

inherit git-r3 perl-module

DESCRIPTION="Proxmox VE async HTTP server library (AnyEvent-based REST/WebSocket server)"
HOMEPAGE="https://git.proxmox.com/?p=pve-http-server.git"

EGIT_REPO_URI="https://git.proxmox.com/git/pve-http-server"
EGIT_BRANCH="master"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS=""
IUSE="html-browser"

# All Perl deps confirmed in Gentoo tree (2025-07-03)
RDEPEND="
	dev-lang/perl
	dev-perl/AnyEvent
	dev-perl/AnyEvent-HTTP
	dev-perl/Crypt-SSLeay
	dev-perl/HTML-Parser
	dev-perl/HTTP-Date
	dev-perl/HTTP-Message
	dev-perl/IO-Socket-SSL
	dev-perl/JSON
	dev-perl/Net-IP
	dev-perl/URI
	dev-perl/libpve-common-perl
	html-browser? ( www-apps/bootstrap )
"

BDEPEND="dev-lang/perl"

S="${WORKDIR}/${PN}"

src_compile() {
	# Pure Perl — nothing to compile
	:
}

src_install() {
	local VENDORLIB
	VENDORLIB=$(perl -MConfig -e 'print $Config{installvendorlib}')

	cd src || die

	insinto "${VENDORLIB}"
	doins -r PVE
}
