# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Pure Perl API + CLI package — no compilation.
# Provides the /cluster/* REST endpoints and pvecm command.
#
# Runtime tools used by PVE::Cluster::Setup (node join/leave, cert management):
#   faketime  — sys-libs/libfaketime
#   rsync     — net-misc/rsync  (already in libpve-cluster-perl RDEPEND)
#   openssl   — dev-libs/openssl
#   ssh-keygen — net-misc/openssh

inherit git-r3 perl-module

DESCRIPTION="Proxmox VE cluster API endpoints and pvecm CLI"
HOMEPAGE="https://git.proxmox.com/?p=pve-cluster.git"

EGIT_REPO_URI="https://git.proxmox.com/git/pve-cluster"
EGIT_BRANCH="master"
EGIT_COMMIT="7091d92e594952dba65c1e57568b3d7cc244e960"  # upstream 9.1.6

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS=""
IUSE=""

RDEPEND="
	dev-lang/perl
	dev-libs/openssl:=
	dev-perl/Digest-HMAC
	dev-perl/libpve-access-control
	dev-perl/libpve-apiclient-perl
	dev-perl/libpve-cluster-perl
	dev-perl/libpve-common-perl
	dev-perl/Net-IP
	dev-perl/UUID
	net-misc/openssh
	net-misc/rsync
	sys-libs/libfaketime
	virtual/perl-Digest-SHA
	virtual/perl-MIME-Base64
	virtual/perl-Time-HiRes
"

BDEPEND="dev-lang/perl"

S="${WORKDIR}/${PN}"

src_compile() { :; }

src_install() {
	local VENDORLIB
	VENDORLIB=$(perl -MConfig -e 'print $Config{installvendorlib}') || die

	insinto "${VENDORLIB}"

	# REST API: /cluster/* endpoints
	doins -r src/PVE/API2

	# CLI: pvecm command module
	doins -r src/PVE/CLI

	# Node join/leave + SSL cert generation
	insinto "${VENDORLIB}/PVE/Cluster"
	doins src/PVE/Cluster/Setup.pm

	# pvecm binary (shell wrapper that invokes PVE::CLI::pvecm)
	dobin src/PVE/pvecm
}
