# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# pve-ha-manager provides the Proxmox VE High Availability stack:
#
#   watchdog-mux     — C daemon: multiplexes /dev/watchdog for CRM+LRM
#   pve-ha-crm       — Perl daemon: Cluster Resource Manager (one per cluster)
#   pve-ha-lrm       — Perl daemon: Local Resource Manager (one per node)
#   ha-manager       — CLI tool for HA resource management
#   Perl modules     — PVE::HA::*, PVE::API2::HA::*, PVE::CLI::ha_manager
#
# Source: upstream proxmox.com 5.2.4 (NOT pxvirt 5.0.4).
# pxvirt 5.0.4 has no pxvirt-specific changes — it's just 2 minor versions
# behind upstream. Upstream 5.2.4 adds:
#   - "disarm" mode: graceful maintenance without triggering fencing
#   - Helpers.pm: factored-out helper functions
#   - Optional static/dynamic scheduling (loaded via eval — degrades gracefully)
#   - watchdog-mux: /dev/watchdog held open for daemon lifetime (safety)
#   - update_service_config() API change: hashref $changes vs sid/param/delete
#   - Fence log level: 'warn' → 'warning' (matches syslog priority spec)
#
# Gentoo package structure vs Debian:
#   Debian: pve-ha-manager (main) + pve-ha-simulator (Gtk3 UI)
#   Gentoo: sys-cluster/pve-ha-manager (USE=simulator gates Gtk3 simulator)
#
# HA is OPTIONAL for single-node operation — pvedaemon starts without it.
# Install pve-ha-manager only on multi-node cluster nodes that need HA.

inherit git-r3 flag-o-matic linux-info

DESCRIPTION="Proxmox VE High Availability Manager"
HOMEPAGE="https://git.proxmox.com/?p=pve-ha-manager.git"

EGIT_REPO_URI="https://git.proxmox.com/git/pve-ha-manager"
EGIT_BRANCH="master"
# HEAD = upstream 5.2.4
EGIT_COMMIT="ecaa0330ee6ab576856082c7f944feef4a14a3e0"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS=""
IUSE="simulator"

RDEPEND="
	dev-lang/perl
	dev-perl/JSON
	dev-perl/libpve-access-control
	dev-perl/libpve-cluster-perl
	dev-perl/libpve-cluster-api-perl
	dev-perl/libpve-common-perl
	dev-perl/libpve-guest-common-perl
	dev-perl/libpve-storage-perl
	simulator? (
		dev-perl/Glib
		dev-perl/Glib-Object-Introspection
		dev-perl/Gtk3
	)
"

BDEPEND="
	dev-lang/perl
	virtual/pkgconfig
"

CONFIG_CHECK="~WATCHDOG"

S="${WORKDIR}/${PN}"

src_compile() {
	# watchdog-mux is the only C binary — pure libc, no extra deps
	emake -C src watchdog-mux
}

src_install() {
	local VENDORLIB
	VENDORLIB=$(perl -MConfig -e 'print $Config{installvendorlib}') || die

	# ── C daemon ──────────────────────────────────────────────────────────────
	dosbin src/watchdog-mux

	# ── Perl service daemons (used as executables, not libraries) ────────────
	dosbin src/pve-ha-crm
	dosbin src/pve-ha-lrm
	dosbin src/ha-manager

	# ── Perl modules ─────────────────────────────────────────────────────────
	insinto "${VENDORLIB}"
	doins -r src/PVE/HA
	doins -r src/PVE/API2/HA
	insinto "${VENDORLIB}/PVE/CLI"
	doins src/PVE/CLI/ha_manager.pm
	insinto "${VENDORLIB}/PVE/Service"
	doins src/PVE/Service/pve_ha_crm.pm
	doins src/PVE/Service/pve_ha_lrm.pm

	# ── Simulator (optional, requires Gtk3) ──────────────────────────────────
	if use simulator; then
		dobin src/pve-ha-simulator
		insinto "${VENDORLIB}"
		doins -r src/PVE/HA/Sim
	fi

	# ── HA notification templates ─────────────────────────────────────────────
	insinto /usr/share/pve-manager/templates
	doins -r src/templates/default

	# ── OpenRC init scripts ───────────────────────────────────────────────────
	newinitd "${FILESDIR}/watchdog-mux.initd" watchdog-mux
	newinitd "${FILESDIR}/pve-ha-crm.initd"   pve-ha-crm
	newinitd "${FILESDIR}/pve-ha-lrm.initd"   pve-ha-lrm

	# ── systemd units (pass-through for systemd users) ────────────────────────
	insinto /usr/lib/systemd/system
	newins "${S}/debian/watchdog-mux.service"  watchdog-mux.service
	newins "${S}/debian/pve-ha-crm.service"    pve-ha-crm.service
	newins "${S}/debian/pve-ha-lrm.service"    pve-ha-lrm.service
}

pkg_postinst() {
	elog "pve-ha-manager installed (upstream 5.2.4)."
	elog ""
	elog "HA is optional for single-node deployments."
	elog "For multi-node HA clusters, enable and start in order:"
	elog "  rc-update add watchdog-mux default"
	elog "  rc-update add pve-ha-crm default"
	elog "  rc-update add pve-ha-lrm default"
	elog ""
	elog "Watchdog: /dev/watchdog must be present for fencing to work."
	elog "If no hardware watchdog is available, load softdog:"
	elog "  echo 'softdog' >> /etc/modules-load.d/pve-ha.conf"
	elog "  modprobe softdog"
	elog ""
	elog "LRM stop timeout: default 300s. Override with PVEHA_STOP_TIMEOUT in"
	elog "/etc/conf.d/pve-ha-lrm if VMs take longer to migrate."
	if use simulator; then
		elog ""
		elog "HA simulator: /usr/bin/pve-ha-simulator (requires running display)"
	fi
}
