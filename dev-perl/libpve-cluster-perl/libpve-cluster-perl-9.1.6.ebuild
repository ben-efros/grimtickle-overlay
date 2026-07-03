# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Pure Perl library package — no compilation.
# Includes PVE::Notify (Debian's libpve-notify-perl) since it comes from
# the same source and has trivial deps.
#
# RDEPEND on net-analyzer/rrdtool[perl,graph] is required because PVE::RRD
# uses the RRDs Perl module. The 'graph' USE flag is required when 'perl'
# is enabled (enforced by rrdtool ebuild itself).

inherit git-r3 perl-module

DESCRIPTION="Proxmox VE cluster Perl library (Corosync, RRD, DataCenter config, Notify)"
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
	dev-perl/Digest-HMAC
	dev-perl/libpve-apiclient-perl
	dev-perl/libpve-common-perl
	dev-perl/libproxmox-rs-perl
	dev-perl/Net-SSLeay
	net-analyzer/rrdtool[perl,graph]
	net-misc/rsync
	~sys-cluster/pve-cluster-${PV}
"

BDEPEND="dev-lang/perl"

S="${WORKDIR}/${PN}"

src_compile() { :; }

src_install() {
	local VENDORLIB
	VENDORLIB=$(perl -MConfig -e 'print $Config{installvendorlib}') || die

	insinto "${VENDORLIB}"

	# PVE::Corosync     — parse/write corosync.conf
	# PVE::DataCenterConfig — datacenter.cfg schema and validation
	# PVE::RRD          — RRD metrics interface (uses RRDs from rrdtool[perl])
	# PVE::SSHInfo      — SSH key/fingerprint helpers
	# PVE::Notify       — notification dispatcher (uses Proxmox::RS::Notify)
	doins \
		src/PVE/Corosync.pm \
		src/PVE/DataCenterConfig.pm \
		src/PVE/RRD.pm \
		src/PVE/SSHInfo.pm \
		src/PVE/Notify.pm
}
