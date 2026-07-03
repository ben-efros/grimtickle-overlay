# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit linux-info autotools

DESCRIPTION="OSI Certified implementation of a complete cluster engine"
HOMEPAGE="https://corosync.github.io/corosync/"
SRC_URI="https://github.com/${PN}/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="BSD-2 public-domain"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~loong ~hppa ~ppc ~ppc64 ~sparc ~x86"
IUSE="augeas dbus doc selinux snmp systemd watchdog xml"

DEPEND="
	dev-libs/nss
	>=sys-cluster/libqb-2.0.0:=
	sys-cluster/kronosnet:=
	augeas? ( app-admin/augeas )
	dbus? ( sys-apps/dbus )
	snmp? ( net-analyzer/net-snmp )
	systemd? ( sys-apps/systemd:= )
	watchdog? ( sys-kernel/linux-headers )
"
RDEPEND="
	${DEPEND}
	selinux? ( sec-policy/selinux-corosync )
"
BDEPEND="
	virtual/pkgconfig
	doc? ( sys-apps/groff )
"

# Two operational patches not yet submitted upstream:
#   0001 — PrivateTmp=yes in systemd service units (security hardening)
#   0002 — ConditionPathExists for corosync.conf (prevents spurious failure on
#           nodes not yet joined to a cluster)
#
# Patches 0003-0005 from pxvirt's corosync-pve (knet ping timer fix,
# CVE-2026-35091, CVE-2026-35092) are already merged in upstream 3.1.10.
PATCHES=(
	"${FILESDIR}/0001-systemd-Enable-PrivateTmp-in-service-files.patch"
	"${FILESDIR}/0002-systemd-Only-start-if-corosync.conf-exists.patch"
)

DOCS=( README.recovery AUTHORS )

pkg_setup() {
	if use watchdog; then
		linux-info_pkg_setup
		elog "Checking for suitable kernel configuration options..."
		if linux_config_exists; then
			if ! linux_chkconfig_present WATCHDOG; then
				ewarn "CONFIG_WATCHDOG: is not set when it should be."
				elog "Please check to make sure these options are set correctly."
			fi
		else
			ewarn "Could not check if CONFIG_WATCHDOG is enabled in your kernel."
			elog "Please check to make sure these options are set correctly."
		fi
	fi
}

src_prepare() {
	default

	sed -i 's/$SEC_FLAGS $OPT_CFLAGS $GDB_FLAGS/$OS_CFLAGS/' configure.ac || die 'sed failed'

	if ! use doc; then
		sed -i 's/BUILD_HTML_DOCS, test/BUILD_HTML_DOCS, false/' configure.ac || die 'sed failed'
	fi

	eautoreconf
}

src_configure() {
	local econf_opts=(
		--disable-static
		--localstatedir=/var
		$(use_enable augeas)
		$(use_enable dbus)
		$(use_enable snmp)
		$(use_enable systemd)
		$(use_enable watchdog)
		$(use_enable xml xmlconf)
	)
	use doc && econf_opts+=( --enable-doc )
	econf "${econf_opts[@]}"
}

src_install() {
	default
	newinitd "${FILESDIR}"/${PN}.initd ${PN}

	insinto /etc/logrotate.d
	newins "${FILESDIR}"/${PN}.logrotate ${PN}

	keepdir /var/lib/corosync /var/log/cluster

	find "${D}" -name '*.la' -delete || die
}

pkg_postinst() {
	if [[ ${REPLACING_VERSIONS} ]]; then
		elog "Default token timeout was changed from 1 seconds to 3 seconds."
		elog "If you need to keep the old timeout, add 'token: 1000' to the"
		elog "totem {} section of your corosync.conf"
	fi
}
