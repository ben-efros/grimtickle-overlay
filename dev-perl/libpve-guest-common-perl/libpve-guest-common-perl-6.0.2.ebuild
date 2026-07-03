# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Pure Perl package — no compilation needed.
#
# Runtime dep proxmox-websocket-tunnel (Rust binary) is not yet ported.
# It is invoked at runtime by PVE::Tunnel::fork_websocket_tunnel() for
# VM/CT migration tunneling; its absence does NOT prevent the Perl module
# from loading. Local operations work; live migration tunneling fails until
# the binary is available.
#
# Runtime dep libpve-cluster-perl (pmxcfs) is not yet ported.
# ReplicationConfig, ReplicationState, and AbstractConfig read cluster
# state from /etc/pve/ via PVE::Cluster — fails gracefully on single-node.

inherit git-r3 perl-module

DESCRIPTION="Proxmox VE common guest modules (VMs and containers)"
HOMEPAGE="https://git.proxmox.com/?p=pve-guest-common.git"

EGIT_REPO_URI="https://git.proxmox.com/git/pve-guest-common"
EGIT_BRANCH="master"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS=""
IUSE=""

RDEPEND="
	dev-lang/perl
	dev-perl/JSON
	dev-perl/libpve-access-control
	dev-perl/libpve-common-perl
	dev-perl/libpve-storage-perl
	dev-perl/URI
	virtual/perl-Time-HiRes
"

# Not yet ported — add when available:
#   dev-perl/libpve-cluster-perl   — cluster config reads from /etc/pve/
#   net-misc/proxmox-websocket-tunnel — runtime binary for live migration

BDEPEND="dev-lang/perl"

S="${WORKDIR}/${PN}"

src_compile() {
	:
}

src_install() {
	local VENDORLIB
	VENDORLIB=$(perl -MConfig -e 'print $Config{installvendorlib}')

	cd "${S}/src" || die

	# Install all modules: AbstractConfig, AbstractMigrate, GuestHelpers,
	# Replication{,Config,State}, StorageTunnel, Tunnel,
	# Mapping/{Dir,PCI,USB}, VZDump/{Common,JobBase,Plugin}
	insinto "${VENDORLIB}"
	doins -r PVE
}
