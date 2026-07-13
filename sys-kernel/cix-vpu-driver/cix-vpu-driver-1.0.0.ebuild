# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit linux-mod-r1

DESCRIPTION="ArmChina Linlon VPU (amvx) out-of-tree kernel driver for CIX SKY1"
HOMEPAGE="https://github.com/cixtech/cix_opensource__vpu_driver"

MY_TAG="p1_v1.0.0"
SRC_URI="https://github.com/cixtech/cix_opensource__vpu_driver/archive/refs/tags/${MY_TAG}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/cix_opensource__vpu_driver-${MY_TAG}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~arm64"

# This driver targets the CIX SKY1 SoC (ARM64).  The kernel must be built
# with CONFIG_ARCH_CIX.  sys-kernel/cix-sources provides a suitable tree.
# The module also requires V4L2 device support (VIDEO_DEV).
CONFIG_CHECK="~ARCH_CIX ~VIDEO_DEV"
MODULES_KERNEL_MIN="6.6"

src_compile() {
	local modlist=(
		# name=install-subdir:source-dir::make-target
		# "updates" matches DEST_MODULE_LOCATION from the upstream dkms.conf.
		# Explicit "all" target triggers the mono_v4l2 rule that sets
		# CONFIG_VIDEO_LINLON=m and friends in the environment before handing
		# off to kbuild.
		amvx=updates:driver::all
	)
	local modargs=(
		# The driver Makefile uses KDIR for the kernel build tree.
		KDIR="${KV_OUT_DIR}"
	)
	linux-mod-r1_src_compile
}

src_install() {
	linux-mod-r1_src_install

	# Install the V4L2 extension controls header for userspace consumers.
	insinto /usr/include/linux
	doins driver/linux/mvx-v4l2-controls.h
}
