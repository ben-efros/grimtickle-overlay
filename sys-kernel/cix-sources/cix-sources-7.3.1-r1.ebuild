# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="8"
ETYPE="sources"
K_WANT_GENPATCHES="base extras"
K_GENPATCHES_VER="2"
K_NO_VERSION_CHECK="True"

inherit kernel-2
detect_version
detect_arch

DESCRIPTION="Full sources including the Gentoo patchset and CIX hardware patches for the ${KV_MAJOR}.${KV_MINOR} kernel tree"
HOMEPAGE="https://github.com/cixtech/cix-linux-main"
SRC_URI="${KERNEL_URI} ${GENPATCHES_URI} ${ARCH_URI}"
KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~loong ~m68k ~mips ~ppc ~ppc64 ~riscv ~s390 ~sparc ~x86"
IUSE=""

src_prepare() {
	eapply "${FILESDIR}/${KV_MAJOR}.${KV_MINOR}/"*.patch
	eapply_user
}

pkg_postinst() {
	kernel-2_pkg_postinst
	einfo "For more info on this patchset, and how to report problems, see:"
	einfo "${HOMEPAGE}"
	ewarn "MS-R1 / CIX Sky1 config: set '# CONFIG_RT_GROUP_SCHED is not set'."
	ewarn "With RT_GROUP_SCHED=y under cgroup-v2, rtkit/PipeWire cannot get"
	ewarn "SCHED_RR and audio XRUNs under load. See docs/config-notes.md."
}

pkg_postrm() {
	kernel-2_pkg_postrm
}
