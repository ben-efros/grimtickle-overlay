# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Pure Perl package — no compilation needed.
# Build-time completions generation (pveum.bash-completion, pveum.zsh-completion)
# requires all runtime deps at BDEPEND time, which creates a circular
# dependency with libpve-cluster-perl. We skip completion generation here
# and install them as static files if/when they are pre-generated.
#
# man page generation requires pve-doc-generator (not yet ported) — skipped.

inherit git-r3 perl-module

DESCRIPTION="Proxmox VE access control library (RBAC, users, realms, TFA)"
HOMEPAGE="https://github.com/jiangcuo/pve-access-control"

EGIT_REPO_URI="https://github.com/jiangcuo/pve-access-control.git"
EGIT_BRANCH="master"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS=""
IUSE=""

# All confirmed present in ::gentoo
RDEPEND="
	dev-lang/perl
	dev-perl/Authen-PAM
	dev-perl/Crypt-OpenSSL-Random
	dev-perl/Crypt-OpenSSL-RSA
	dev-perl/JSON
	dev-perl/JSON-XS
	dev-perl/libpve-common-perl
	dev-perl/libproxmox-rs-perl
	dev-perl/MIME-Base32
	dev-perl/Net-SSLeay
	dev-perl/perl-ldap
	dev-perl/UUID
	virtual/perl-Digest-SHA
	virtual/perl-MIME-Base64
"

# libpve-cluster-perl not yet ported; add it when available
# dev-perl/libpve-cluster-perl

BDEPEND="
	dev-lang/perl
"

S="${WORKDIR}/${PN}"

src_compile() {
	# Nothing to compile — pure Perl library.
	# man pages and shell completions require pve-doc-generator (not yet ported)
	# and a fully wired runtime (all RDEPEND present), so we skip them.
	:
}

src_install() {
	local VENDORLIB
	VENDORLIB=$(perl -MConfig -e 'print $Config{installvendorlib}')

	cd "${S}/src" || die

	# Install PVE::AccessControl, PVE::RPCEnvironment, PVE::TokenConfig,
	# and all sub-namespace modules (Auth/*, API2/*, CLI/*, Jobs/*)
	doins -r PVE

	# Install binaries
	dosbin pveum
	dobin oathkeygen
}

pkg_postinst() {
	ewarn "libpve-access-control depends on libpve-cluster-perl (not yet ported)."
	ewarn "pvedaemon will fail to start until pve-cluster is also installed."
	ewarn "For single-node testing, see docs/packages/pve-access-control.md"
	ewarn "for bootstrapping /etc/pve/ without pmxcfs."
}
