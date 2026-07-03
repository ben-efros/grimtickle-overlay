# Copyright 2024-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..14} )

inherit meson python-any-r1 systemd

DESCRIPTION="Linux containers userspace tools (pxvirt fork of LXC)"
HOMEPAGE="https://linuxcontainers.org/lxc/ https://pxvirt.lierfang.com/"
SRC_URI="https://linuxcontainers.org/downloads/lxc/lxc-${PV}.tar.gz"

S="${WORKDIR}/lxc-${PV}"

LICENSE="LGPL-2.1+"
SLOT="0"
KEYWORDS="~arm64 ~loong"

IUSE="+apparmor +capabilities criu doc +seccomp selinux"

DEPEND="
	apparmor? ( sys-apps/apparmor:= )
	capabilities? ( sys-libs/libcap:= )
	net-libs/gnutls:=
	seccomp? ( sys-libs/libseccomp:= )
	selinux? ( sys-libs/libselinux:= )
	sys-apps/dbus
	sys-apps/systemd:=
"

RDEPEND="
	${DEPEND}
	criu? ( sys-process/criu )
	net-misc/bridge-utils
	sys-apps/shadow
	sys-fs/lxcfs
"

BDEPEND="
	${PYTHON_DEPS}
	virtual/pkgconfig
	doc? (
		app-doc/doxygen
		app-text/docbook2X
	)
	$(python_gen_any_dep '
		dev-python/jinja2[${PYTHON_USEDEP}]
	')
"

# pxvirt patches applied on top of upstream lxc-6.0.5:
#   0001-PVE-Config-deny-rw-mounting-of-sys-and-proc.patch
#     Prevents rw remounting of /sys and /proc from inside containers (security).
#   0002-PVE-Config-attach-always-use-getent.patch
#     Forces lxc-attach to use getent for user lookup (NSS segfault workaround).
#   0001-apparmor-allow-lxc-start-to-create-user-namespaces.patch
#     Adds 'userns' permission to AppArmor start-container profile.
#   0002-apparmor-use-abi-directive-in-apparmor-profiles.patch
#     Adds abi <abi/lxc> directive so profiles don't require global feature pinning.
PATCHES=(
	"${FILESDIR}/0001-PVE-Config-deny-rw-mounting-of-sys-and-proc.patch"
	"${FILESDIR}/0002-PVE-Config-attach-always-use-getent.patch"
	"${FILESDIR}/0001-apparmor-allow-lxc-start-to-create-user-namespaces.patch"
	"${FILESDIR}/0002-apparmor-use-abi-directive-in-apparmor-profiles.patch"
)

python_check_deps() {
	python_has_version -b "dev-python/jinja2[${PYTHON_USEDEP}]"
}

pkg_setup() {
	python-any-r1_pkg_setup
}

src_configure() {
	local emesonargs=(
		# Match pxvirt's Debian build configuration (debian/rules)
		-Dcgroup-pattern=lxc/%n
		-Dexamples=false
		-Dinit-script=systemd
		-Dspecfile=false
		-Dtests=false

		$(meson_use apparmor)
		$(meson_use capabilities)
		$(meson_use doc man)
		$(meson_use seccomp)
		$(meson_use selinux)
	)

	meson_src_configure
}

src_install() {
	meson_src_install

	# Runtime state directories
	keepdir /var/cache/lxc
	keepdir /var/lib/lxc
	keepdir /var/log/lxc

	# lxc-user-nic must be setuid root for unprivileged container networking.
	# Debian's dh_fixperms explicitly excludes this binary from normalization.
	local usernic
	for usernic in "${ED}"/usr/lib*/lxc/lxc-user-nic \
	               "${ED}"/usr/libexec/lxc/lxc-user-nic; do
		[[ -f "${usernic}" ]] && fperms 4755 "${usernic#${ED}}"
	done
}

pkg_postinst() {
	# Establish subuid/subgid range for root so that unprivileged containers
	# owned by root can use user namespace ID mapping.
	if getent passwd root > /dev/null 2>&1; then
		usermod -v 100000-165535 -w 100000-165535 root 2>/dev/null || \
			ewarn "Could not set subuid/subgid range for root." \
			      "Add manually to /etc/subuid and /etc/subgid if needed."
	fi

	if use apparmor; then
		elog "AppArmor profiles have been installed to /etc/apparmor.d/."
		elog "Load or reload them with:"
		elog "  apparmor_parser -r /etc/apparmor.d/lxc-containers"
		elog "  apparmor_parser -r /etc/apparmor.d/usr.bin.lxc-start"
		elog "  apparmor_parser -r /etc/apparmor.d/usr.bin.lxc-copy"
		elog ""
	fi

	elog "This is lxc-pve — the pxvirt fork of LXC ${PV}."
	elog "pxvirt patches applied:"
	elog "  - Deny rw remounting of /sys and /proc (security hardening)"
	elog "  - lxc-attach: always use getent for user lookup (NSS fix)"
	elog "  - AppArmor: allow lxc-start to create user namespaces"
	elog "  - AppArmor: use abi directive (no global feature pinning required)"
	elog ""
	elog "To use lxc-pve with pxvirt, install app-emulation/pve-container."
	elog "For standalone LXC use: lxc-create / lxc-start / lxc-ls"
}
