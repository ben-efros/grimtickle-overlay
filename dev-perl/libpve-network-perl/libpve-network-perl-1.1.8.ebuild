# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# libpve-network-perl provides the Proxmox VE SDN (Software-Defined Networking)
# Perl library stack:
#
#   PVE::Network::SDN                  — top-level orchestration
#   PVE::Network::SDN::Zones/*         — zone plugins (VLAN, VxLAN, EVPN, QinQ, Simple, Faucet)
#   PVE::Network::SDN::Controllers/*   — routing plugins (BGP, EVPN, ISIS, Faucet)
#   PVE::Network::SDN::Ipams/*         — IPAM backends (PVE built-in, NetBox, phpIPAM)
#   PVE::Network::SDN::Dns/*           — DNS backends (PowerDNS)
#   PVE::Network::SDN::Dhcp/*          — DHCP backends (Dnsmasq via D-Bus)
#   PVE::Network::SDN::Fabrics         — WireGuard fabric config (pxvirt addition; upstream since 9.x)
#   PVE::API2::Network::SDN/*          — REST API endpoints
#
# HOST BRIDGE NETWORKING NOTE:
#   This package does NOT manage the host's main bridge interface.
#   Host bridge setup (vmbr0 etc.) is handled by PVE::INotify in
#   libpve-common-perl, which reads /etc/network/interfaces (Debian ifupdown
#   format). The Gentoo network backend plugin (USE=networkd or USE=nm) is a
#   separate package: net-misc/pve-network-backend.
#   See docs/packages/pve-network-moddoc.md for the full design.
#
# SDN writes /etc/network/interfaces.d/sdn — a Debian-format interfaces
# snippet that ifupdown2 or the Gentoo backend plugin then applies.

inherit git-r3 perl-module

DESCRIPTION="Proxmox VE SDN (Software-Defined Networking) Perl library"
HOMEPAGE="https://git.proxmox.com/?p=pve-network.git"

EGIT_REPO_URI="https://git.proxmox.com/git/pve-network"
EGIT_BRANCH="master"
# HEAD = 1.1.8 (upstream, 2025-09-16)
EGIT_COMMIT="a2b0e828b9e260990469d81f7f24d902ddb6c2a2"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS=""
IUSE="faucet"

RDEPEND="
	dev-lang/perl
	dev-perl/JSON
	dev-perl/libpve-access-control
	dev-perl/libpve-cluster-perl
	dev-perl/libpve-common-perl
	dev-perl/LWP-UserAgent
	dev-perl/Net-DBus
	dev-perl/Net-IP
	dev-perl/Net-SSLeay
	dev-perl/Net-Subnet
	dev-perl/NetAddr-IP
	dev-perl/UUID
	virtual/perl-Digest-SHA
	virtual/perl-HTTP-Tiny
	faucet? ( dev-perl/CPAN-Meta )
"

BDEPEND="dev-lang/perl"

S="${WORKDIR}/${PN}"

src_compile() { :; }

src_install() {
	local VENDORLIB
	VENDORLIB=$(perl -MConfig -e 'print $Config{installvendorlib}') || die

	insinto "${VENDORLIB}"

	# Top-level SDN module
	doins src/PVE/Network/SDN.pm

	# SDN sub-hierarchy
	doins -r src/PVE/Network/SDN

	# REST API hierarchy
	doins -r src/PVE/API2/Network

	# systemd drop-in: dnsmasq must start after networking
	# On OpenRC systems, dnsmasq already depends on net — this is a no-op.
	insinto /usr/lib/systemd/system/dnsmasq@.service.d
	doins src/services/00-dnsmasq-after-networking.conf

	# Remove Faucet SDN controller unless USE=faucet
	if ! use faucet; then
		rm -f "${ED}${VENDORLIB}/PVE/Network/SDN/Controllers/FaucetPlugin.pm" || die
		rm -f "${ED}${VENDORLIB}/PVE/Network/SDN/Zones/FaucetPlugin.pm" || die
	fi
}
