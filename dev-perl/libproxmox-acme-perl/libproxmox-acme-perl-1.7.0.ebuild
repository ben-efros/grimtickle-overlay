# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Pure Perl ACME (Let's Encrypt) client library.
# Provides PVE::ACME, PVE::ACME::Challenge, PVE::ACME::DNSChallenge,
# PVE::ACME::StandAlone — used by pve-manager for certificate management.

inherit git-r3 perl-module

DESCRIPTION="Proxmox ACME/Let's Encrypt Perl client library"
HOMEPAGE="https://git.proxmox.com/?p=proxmox-acme.git"

EGIT_REPO_URI="https://git.proxmox.com/git/proxmox-acme"
EGIT_BRANCH="master"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS=""
IUSE=""

# All Perl deps confirmed in Gentoo tree (2025-07-03)
RDEPEND="
	dev-lang/perl
	dev-perl/Crypt-OpenSSL-RSA
	dev-perl/HTTP-Daemon
	dev-perl/HTTP-Message
	dev-perl/JSON
	dev-perl/TimeDate
	dev-perl/libwww-perl
	dev-perl/libpve-common-perl
	virtual/perl-Digest-SHA
	virtual/perl-MIME-Base64
"

BDEPEND="dev-lang/perl"

S="${WORKDIR}/${PN}"

src_compile() {
	:
}

src_install() {
	local VENDORLIB
	VENDORLIB=$(perl -MConfig -e 'print $Config{installvendorlib}')

	cd src || die

	insinto "${VENDORLIB}"
	doins -r PVE
}
