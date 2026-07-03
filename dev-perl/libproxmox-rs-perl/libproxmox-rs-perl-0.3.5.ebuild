# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Pure Perl bridge package — no Rust compilation.
# Runs genpackage.pl to generate Proxmox::RS::* stub modules that delegate
# to the already-loaded libpve_rs.so (from dev-perl/proxmox-perl-rs).
#
# Source: common/pkg/ subdirectory of the proxmox-perl-rs git repo.

inherit git-r3 perl-module

DESCRIPTION="Common Perl bridge for Proxmox Rust XS bindings (Proxmox::RS::* stubs)"
HOMEPAGE="https://git.proxmox.com/?p=proxmox-perl-rs.git"

EGIT_REPO_URI="https://github.com/jiangcuo/proxmox-perl-rs.git"
EGIT_BRANCH="master"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS=""
IUSE=""

RDEPEND="
	dev-lang/perl
	dev-perl/proxmox-perl-rs
"

BDEPEND="
	dev-lang/perl
	dev-perl/perlmod-bin
"

# S points to the common/pkg/ subdirectory which contains the Makefile,
# pre-committed Perl files, and is where genpackage.pl output lands.
S="${WORKDIR}/proxmox-perl-rs/common/pkg"

src_compile() {
	local GENPACKAGE=/usr/lib/perlmod/genpackage.pl
	[[ -x "${GENPACKAGE}" ]] || die "genpackage.pl not found; install dev-perl/perlmod-bin"

	"${GENPACKAGE}" \
		--lib=- \
		--lib-tag=proxmox \
		--lib-package=Proxmox::Lib::Common \
		--lib-prefix=Proxmox \
		Proxmox::RS::APT::Repositories \
		Proxmox::RS::CalendarEvent \
		Proxmox::RS::Notify \
		Proxmox::RS::OIDC \
		Proxmox::RS::SharedCache \
		Proxmox::RS::Subscription \
		|| die "genpackage.pl failed"
}

src_install() {
	local VENDORLIB
	VENDORLIB=$(perl -MConfig -e 'print $Config{installvendorlib}')

	insinto "${VENDORLIB}"

	# Install pre-committed files: Proxmox::Lib::Common, Proxmox::Lib::SslProbe
	# and PVE::RS::CalendarEvent (compat stub)
	doins -r Proxmox/Lib
	doins -r PVE

	# Install genpackage.pl-generated Proxmox::RS::* stubs
	doins -r Proxmox/RS
}
