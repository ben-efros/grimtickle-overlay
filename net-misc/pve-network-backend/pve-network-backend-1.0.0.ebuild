# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# pve-network-backend — Gentoo network backend for Proxmox VE
#
# Provides /usr/sbin/pve-ifreload, a drop-in replacement for ifupdown2's
# "ifreload -a" command. PVE calls ifreload to apply network changes made
# via the web UI or API. On Gentoo, this shim translates the standard PVE
# network config format (/etc/network/interfaces) to the active Gentoo
# network backend: systemd-networkd, NetworkManager, or netifrc.
#
# The pve-manager patch (0001-gentoo-replace-ifreload-with-pve-ifreload.patch)
# is carried in this package's files/ and must be applied to pve-manager's
# ebuild when building sys-apps/pve-manager. It makes pve-manager prefer
# /usr/sbin/pve-ifreload when present, falling back to ifreload for
# non-Gentoo deployments.
#
# /etc/network/interfaces role on Gentoo:
#   • PVE reads it to display network config in the web UI
#   • PVE writes it when you save changes via web UI or API
#   • pve-ifreload reads it and applies changes to the OS
#   • It is NOT read directly by systemd-networkd, NM, or netifrc
#   • It IS the source of truth for PVE's view of network config
#   See: /usr/share/doc/${PF}/networking.md

DESCRIPTION="Gentoo network backend for Proxmox VE (ifreload replacement)"
HOMEPAGE="https://github.com/grimtickle/grimtickle-overlay"
SRC_URI=""

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="networkd nm netifrc"
REQUIRED_USE="|| ( networkd nm netifrc )"

RDEPEND="
	networkd? ( sys-apps/systemd[network] )
	nm? ( net-misc/networkmanager )
	netifrc? ( net-misc/netifrc )
"

BDEPEND=""

S="${WORKDIR}"

src_unpack() { :; }
src_compile() { :; }

src_install() {
	# The main shim script
	dosbin "${FILESDIR}/pve-ifreload"

	# Example /etc/network/interfaces with Gentoo-specific comments
	insinto /usr/share/doc/${PF}
	doins "${FILESDIR}/interfaces.example"

	# Generate and install networking documentation
	insinto /usr/share/doc/${PF}
	newdoc "${FILESDIR}/interfaces.example" interfaces.example

	# Symlink: provide /sbin/pve-ifreload for scripts that use /sbin directly
	dosym /usr/sbin/pve-ifreload /sbin/pve-ifreload
}

pkg_postinst() {
	local ifile="/etc/network/interfaces"

	elog "pve-network-backend installed."
	elog ""
	elog "/usr/sbin/pve-ifreload replaces ifupdown2's 'ifreload -a'."
	elog "It reads ${ifile} and applies config to your"
	elog "active network backend (auto-detected from running services)."
	elog ""
	elog "To force a specific backend, set PVENET_BACKEND in the environment:"
	elog "  PVENET_BACKEND=networkd pve-ifreload"
	elog "  PVENET_BACKEND=nm       pve-ifreload"
	elog "  PVENET_BACKEND=netifrc  pve-ifreload"
	elog ""

	if [[ ! -f "${ifile}" ]]; then
		elog "NOTICE: ${ifile} does not exist."
		elog "Copy the example to get started:"
		elog "  cp /usr/share/doc/${PF}/interfaces.example ${ifile}"
		elog "Edit it to match your physical interface name and IP."
		elog ""
	fi

	if use netifrc; then
		elog "netifrc backend: pve-ifreload writes /etc/conf.d/net.pve."
		elog "Add this line to /etc/conf.d/net:"
		elog "  source /etc/conf.d/net.pve"
		elog "Then create symlinks for managed interfaces, e.g.:"
		elog "  ln -s net.lo /etc/init.d/net.vmbr0"
		elog "  rc-update add net.vmbr0 default"
		elog ""
	fi

	if use networkd; then
		elog "systemd-networkd backend: pve-ifreload writes"
		elog "  /run/systemd/network/10-*.{network,netdev}"
		elog "and calls 'networkctl reload'."
		elog ""
		elog "NOTE: /run/systemd/network/ is volatile — files are lost on reboot."
		elog "For persistent config, run pve-ifreload once after boot, or add it"
		elog "to a systemd oneshot service that runs after network-pre.target."
		elog ""
	fi

	elog "Full documentation: docs/networking/gentoo-networking.md"
	elog "  (in grimtickle-overlay source)"
}
