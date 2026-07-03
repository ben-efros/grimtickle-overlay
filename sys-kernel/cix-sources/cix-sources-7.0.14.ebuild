# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="8"
ETYPE="sources"
K_WANT_GENPATCHES="base extras"
K_GENPATCHES_VER="22"
K_NO_VERSION_CHECK="True"

inherit kernel-2
detect_version
detect_arch

CIX_PATCHES_COMMIT="main"

DESCRIPTION="Full sources including the Gentoo patchset and CIX hardware patches for the ${KV_MAJOR}.${KV_MINOR} kernel tree"
HOMEPAGE="https://github.com/cixtech/cix-linux-main"
SRC_URI="${KERNEL_URI} ${GENPATCHES_URI} ${ARCH_URI}
	https://github.com/cixtech/cix-linux-main/archive/refs/heads/${CIX_PATCHES_COMMIT}.tar.gz
		-> cix-linux-main-${CIX_PATCHES_COMMIT}.tar.gz"
KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~loong ~m68k ~mips ~ppc ~ppc64 ~riscv ~s390 ~sparc ~x86"
IUSE=""

src_unpack() {
	kernel-2_src_unpack
	unpack "cix-linux-main-${CIX_PATCHES_COMMIT}.tar.gz"
}

src_prepare() {
	eapply "${WORKDIR}/cix-linux-main-${CIX_PATCHES_COMMIT}/patches-${KV_MAJOR}.${KV_MINOR}/"*.patch
	eapply_user
}

pkg_postinst() {
	kernel-2_pkg_postinst
	einfo "For more info on this patchset, and how to report problems, see:"
	einfo "${HOMEPAGE}"
}

pkg_postrm() {
	kernel-2_pkg_postrm
}
