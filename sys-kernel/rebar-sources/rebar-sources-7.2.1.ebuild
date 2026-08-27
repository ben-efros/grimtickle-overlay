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

DESCRIPTION="Full sources including the Gentoo patchset and Resizable BAR / PCI realloc patches for the ${KV_MAJOR}.${KV_MINOR} kernel tree"
HOMEPAGE="https://dev.gentoo.org/~mpagano/genpatches"
SRC_URI="${KERNEL_URI} ${GENPATCHES_URI} ${ARCH_URI}"
KEYWORDS="~amd64 ~x86"
IUSE=""

src_prepare() {
	eapply "${FILESDIR}"/*.patch
	eapply_user
}

pkg_postinst() {
	kernel-2_pkg_postinst
	einfo "This kernel includes additional PCI patches to allow the kernel's"
	einfo "'pci=realloc=on' boot option to reallocate BARs behind bridges that"
	einfo "do not otherwise release resources needed for Resizable BAR / large"
	einfo "BAR relocation (e.g. Lenovo P920 / Intel C621 boards without native"
	einfo "Resizable BAR support in firmware)."
	einfo "For more info on the base patchset, and how to report problems, see:"
	einfo "${HOMEPAGE}"
}

pkg_postrm() {
	kernel-2_pkg_postrm
}
