# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit linux-mod-r1

DESCRIPTION="ArmChina Zhouyi NPU (aipu) out-of-tree kernel driver for CIX SKY1"
HOMEPAGE="https://github.com/cixtech/cix_opensource__npu_driver"

MY_TAG="p1_7.0_v6.2.0"
SRC_URI="https://github.com/cixtech/cix_opensource__npu_driver/archive/refs/tags/${MY_TAG}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/cix_opensource__npu_driver-${MY_TAG}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~arm64"

# This driver targets the CIX SKY1 SoC (ARM64).  The kernel must be built
# with CONFIG_ARCH_CIX.  sys-kernel/cix-sources provides a suitable tree.
CONFIG_CHECK="~ARCH_CIX"
MODULES_KERNEL_MIN="6.6"

src_compile() {
	local modlist=(
		# name=install-subdir:source-dir
		# "updates" matches DEST_MODULE_LOCATION from the upstream dkms.conf
		aipu=updates:driver
	)
	local modargs=(
		# Point to the configured kernel build tree
		COMPASS_DRV_BTENVAR_KPATH="${KV_OUT_DIR}"
		# Architecture/platform selection mirroring the upstream dkms.conf
		BUILD_AIPU_VERSION_KMD=BUILD_ZHOUYI_V3
		BUILD_TARGET_PLATFORM_KMD=BUILD_PLATFORM_SKY1
		BUILD_NPU_DEVFREQ=y
		COMPASS_DRV_BTENVAR_KMD_VERSION="${PV}"
	)
	linux-mod-r1_src_compile
}

src_install() {
	linux-mod-r1_src_install

	# Install the UAPI header so userspace (UMD) can use the aipu ioctl API.
	insinto /usr/include/misc
	doins driver/armchina-npu/include/armchina_aipu.h
}
