# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Produces the pmxcfs FUSE daemon and IPCC Perl XS module.
#
# Source: upstream proxmox.com pve-cluster 9.1.6 (NOT pxvirt 9.0.6).
# Upstream is newer and already includes all pxvirt feature additions
# (WireGuard paths, SDN paths, token-coefficient, HA auto-rebalance,
# dynamic CRS mode) PLUS critical security/bug fixes that pxvirt lacks:
#   - 0750 permissions on /etc/pve, /var/lib/pve-cluster, /run/pve-cluster
#   - No /tmp race in SSL cert generation (uses /run/pve-cluster/)
#   - sqlite3_close() on init failure (connection leak fix)
#   - memfree/memavailable RRD migration handling
#
# One pxvirt-specific patch applied:
#   0001 — /cluster/vmlist UUID endpoint (UUID-annotated VM list API)
#
# Three Gentoo atoms from one source (vs 4 Debian packages):
#   sys-cluster/pve-cluster         — pmxcfs daemon + IPCC.so XS + PVE::Cluster
#   dev-perl/libpve-cluster-perl    — pure Perl library + PVE::Notify
#   dev-perl/libpve-cluster-api-perl — REST API + pvecm CLI

inherit git-r3 perl-module linux-info

DESCRIPTION="Proxmox VE cluster filesystem daemon (pmxcfs) and Perl XS IPC bridge"
HOMEPAGE="https://git.proxmox.com/?p=pve-cluster.git"

EGIT_REPO_URI="https://git.proxmox.com/git/pve-cluster"
EGIT_BRANCH="master"
EGIT_COMMIT="7091d92e594952dba65c1e57568b3d7cc244e960"  # upstream 9.1.6

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS=""
IUSE="test"
RESTRICT="!test? ( test )"

# C daemon dependencies — all confirmed in ::gentoo
DEPEND="
	dev-db/sqlite:3
	dev-libs/glib:2
	net-analyzer/rrdtool
	sys-cluster/corosync
	sys-cluster/libqb
	sys-fs/fuse:0
"

# IPCC.so XS build deps
DEPEND+="
	dev-lang/perl:=
	dev-perl/ExtUtils-MakeMaker
	sys-cluster/libqb
"

BDEPEND="
	dev-lang/perl
	dev-perl/ExtUtils-MakeMaker
	test? ( dev-libs/check )
"

# Runtime: corosync needed for cluster mode; optional for single-node
RDEPEND="
	${DEPEND}
	dev-lang/perl:=
	dev-perl/libpve-common-perl
"

S="${WORKDIR}/${PN}"

PATCHES=(
	"${FILESDIR}/0001-pxvirt-cluster-vmlist-uuid-endpoint.patch"
)

pkg_setup() {
	# Check for FUSE kernel support
	CONFIG_CHECK="~FUSE_FS"
	WARNING_FUSE_FS="CONFIG_FUSE_FS is required for pmxcfs to mount /etc/pve/"
	linux-info_pkg_setup
}

src_compile() {
	# ── 1. Build pmxcfs C daemon ──────────────────────────────────────────
	emake -C src/pmxcfs

	# ── 2. Build IPCC.so Perl XS module (IPC bridge via libqb) ───────────
	cd "${S}/src/PVE" || die

	# Generate IPCC.c from IPCC.xs
	xsubpp -noversioncheck IPCC.xs > IPCC.c || die "xsubpp failed"

	# Compile as position-independent shared library
	local PERL_INC
	PERL_INC=$(perl -MExtUtils::Embed -e perl_inc) || die
	local QB_CFLAGS QB_LIBS
	QB_CFLAGS=$(pkg-config --cflags libqb) || die
	QB_LIBS=$(pkg-config --libs libqb) || die

	gcc -fPIC -Wall -Werror -Wno-strict-aliasing -g -O2 -shared \
		${PERL_INC} ${QB_CFLAGS} \
		-c -o IPCC.o IPCC.c \
		|| die "IPCC.c compile failed"

	gcc -fPIC -shared -Wl,-z,relro \
		-o IPCC.so IPCC.o ${QB_LIBS} \
		|| die "IPCC.so link failed"

	# ── 3. Generate IPCConst.pm from cfs-ipc-ops.h via awk ───────────────
	cd "${S}/src/PVE/Cluster" || die
	awk -f IPCConst.pm.awk "${S}/src/pmxcfs/cfs-ipc-ops.h" > IPCConst.pm \
		|| die "IPCConst.pm generation failed"
}

src_test() {
	emake -C src/pmxcfs check
}

src_install() {
	# ── pmxcfs binaries ───────────────────────────────────────────────────
	dobin src/pmxcfs/pmxcfs
	dobin src/pmxcfs/create_pmxcfs_db

	# ── IPCC.so — must land in Perl's vendorarch auto-load path ──────────
	local VENDORARCH
	VENDORARCH=$(perl -MConfig -e 'print $Config{vendorarch}') || die
	insinto "${VENDORARCH}/auto/PVE/IPCC"
	doins src/PVE/IPCC.so

	# ── Perl modules for sys-cluster/pve-cluster (uses IPCC) ─────────────
	local VENDORLIB
	VENDORLIB=$(perl -MConfig -e 'print $Config{installvendorlib}') || die
	insinto "${VENDORLIB}"
	doins src/PVE/Cluster.pm
	doins src/PVE/IPCC.pm
	insinto "${VENDORLIB}/PVE/Cluster"
	doins src/PVE/Cluster/IPCConst.pm

	# ── sysctl settings (bridge-nf, aio — needed for VMs/containers) ─────
	insinto /usr/lib/sysctl.d
	newins debian/sysctl.d/10-pve.conf 10-pve-cluster.conf

	# ── systemd service unit ──────────────────────────────────────────────
	insinto /usr/lib/systemd/system
	doins debian/pve-cluster.service

	# ── OpenRC init script ────────────────────────────────────────────────
	doinitd "${FILESDIR}/pve-cluster.initd"
	# The installed file is named after the ebuild PN by doinitd;
	# but our initd file is pve-cluster.initd → installed as pve-cluster
	mv "${ED}/etc/init.d/pve-cluster.initd" "${ED}/etc/init.d/pve-cluster" \
		2>/dev/null || true

	# ── Runtime directory (pmxcfs creates most dirs itself) ───────────────
	keepdir /var/lib/pve-cluster
	fperms 0750 /var/lib/pve-cluster

	# ── Database directory ────────────────────────────────────────────────
	keepdir /etc/pve
	fperms 0750 /etc/pve
}

pkg_postinst() {
	# Remove legacy SDN fabrics directory (upgrade from < 9.0.1)
	rmdir --ignore-fail-on-non-empty /etc/pve/sdn/fabrics/ 2>/dev/null || true

	elog ""
	elog "pmxcfs (Proxmox cluster filesystem) has been installed."
	elog ""
	elog "Single-node quickstart (no corosync required):"
	elog "  1. create_pmxcfs_db /var/lib/pve-cluster/config.db"
	elog "  2. rc-service pve-cluster start   (or: systemctl start pve-cluster)"
	elog "  3. echo 'user:root@pam:1:0:::root@localhost::' > /etc/pve/user.cfg"
	elog "  4. touch /etc/pve/priv/shadow.cfg"
	elog ""
	elog "The sysctl settings in /usr/lib/sysctl.d/10-pve-cluster.conf"
	elog "(bridge netfilter bypass, aio-max-nr) are required for VMs/containers."
	elog "Apply with: sysctl -p /usr/lib/sysctl.d/10-pve-cluster.conf"
}
