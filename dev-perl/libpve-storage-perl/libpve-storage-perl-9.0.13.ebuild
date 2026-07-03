# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Pure Perl storage management library — no compilation of Perl code.
# ceph-rbdnamer-pve (udev helper) is a shell script — installed always.
#
# Storage backend system-tool dependencies are gated by USE flags:
#   ceph  — RBDPlugin, CephFSPlugin (ceph-common, ceph-fuse, librados2-perl)
#   nfs   — NFSPlugin     (net-fs/nfs-utils)
#   samba — CIFSPlugin    (net-fs/samba)
#   iscsi — ISCSIPlugin, ISCSIDirectPlugin (sys-block/open-iscsi)
#   esxi  — ESXiPlugin    (app-emulation/vmware-tools, rarely needed)
#
# All plugin .pm files are ALWAYS installed regardless of USE flags — the
# runtime tools are guarded, but Perl code must be loadable at startup.
# (PVE::Storage hard-'use's all plugins at module load time.)
#
# Skipped: man page + shell completions (require pve-doc-generator + full
# runtime stack at build time; see notes in libpve-access-control).

inherit git-r3 perl-module

DESCRIPTION="Proxmox VE storage management library (all storage backends)"
HOMEPAGE="https://github.com/jiangcuo/pve-storage"

EGIT_REPO_URI="https://github.com/jiangcuo/pve-storage.git"
EGIT_BRANCH="master"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS=""
IUSE="ceph esxi iscsi nfs samba"

# Core always-required deps
RDEPEND="
	dev-lang/perl
	dev-perl/File-chdir
	dev-perl/JSON
	dev-perl/libpve-access-control
	dev-perl/libpve-apiclient-perl
	dev-perl/libpve-common-perl
	dev-perl/Net-IP
	dev-perl/POSIX-strptime
	dev-perl/XML-LibXML
	virtual/perl-MIME-Base64
	app-arch/bzip2
	app-arch/lzop
	app-arch/zstd
	app-misc/cstream
	sys-apps/smartmontools
	sys-block/thin-provisioning-tools
	sys-fs/lvm2
"

# libpve-cluster-perl not yet ported — pve-storage can start without it on
# single-node (cluster config reads fall back to empty)
# dev-perl/libpve-cluster-perl

RDEPEND+="
	ceph?  (
		sys-cluster/ceph
		dev-perl/librados2-perl
	)
	nfs?   ( net-fs/nfs-utils )
	samba? ( net-fs/samba )
	iscsi? ( sys-block/open-iscsi )
"

BDEPEND="dev-lang/perl"

S="${WORKDIR}/${PN}"

src_compile() {
	:
}

src_install() {
	local VENDORLIB
	VENDORLIB=$(perl -MConfig -e 'print $Config{installvendorlib}')

	cd "${S}/src" || die

	# Perl library: PVE::Storage, all backends, Diskmanage, CephConfig, GuestImport
	insinto "${VENDORLIB}"
	doins -r PVE

	# CLI binary (pvesm, pvebcache) — no man page (pve-doc-generator not ported)
	dosbin bin/pvesm
	dosbin bin/pvebcache

	# udev helper for Ceph RBD device naming (shell script, always install)
	exeinto /usr/libexec
	doexe udev-rbd/ceph-rbdnamer-pve

	insinto /usr/lib/udev/rules.d
	doins udev-rbd/50-rbd-pve.rules
}

pkg_postinst() {
	ewarn "libpve-storage-perl depends on libpve-cluster-perl (not yet ported)."
	ewarn "Storage plugin config reads from /etc/pve/storage.cfg will fail"
	ewarn "without pmxcfs. Seed /etc/pve/storage.cfg manually for testing."
	if ! use ceph; then
		ewnote "USE=ceph is disabled. RBDPlugin and CephFSPlugin are installed"
		ewnote "but ceph-common, ceph-fuse and librados2-perl are not pulled in."
		ewnote "Add USE=ceph to enable Ceph RBD and CephFS storage backends."
	fi
}
