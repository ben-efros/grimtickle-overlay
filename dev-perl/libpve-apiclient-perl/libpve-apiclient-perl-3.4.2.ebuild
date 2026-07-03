# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 perl-module

DESCRIPTION="Proxmox VE REST API client library (PVE::APIClient::LWP)"
HOMEPAGE="https://git.proxmox.com/?p=pve-apiclient.git"

EGIT_REPO_URI="https://git.proxmox.com/git/pve-apiclient.git"
EGIT_BRANCH="master"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS=""
IUSE=""

# All confirmed in ::gentoo
RDEPEND="
	dev-lang/perl
	dev-perl/IO-Socket-SSL
	dev-perl/JSON
	dev-perl/libwww-perl
	dev-perl/Net-SSLeay
	dev-perl/URI
	virtual/perl-HTTP-Message
"

BDEPEND="dev-lang/perl"

S="${WORKDIR}/${PN}"

src_compile() {
	:
}

src_install() {
	local VENDORLIB
	VENDORLIB=$(perl -MConfig -e 'print $Config{installvendorlib}')
	insinto "${VENDORLIB}"
	doins -r src/PVE
}
