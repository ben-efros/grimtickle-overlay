# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Rust XS library: builds libpve_rs.so via cargo, generates Perl wrappers
# via perlmod-bin's genpackage.pl.
#
# Vendor tarball generation (run once, then place in DISTDIR):
#   See docs/packages/proxmox-perl-rs.md for the full vendor generation procedure.
#   Quick summary:
#     cd pve-rs/
#     cargo vendor vendor/
#     # copy proxmox-* and perlmod path-deps into vendor/ (see docs)
#     tar czf libpve-rs-perl-0.9.4-vendor.tar.gz vendor/

PYTHON_COMPAT=( python3_{10..13} )

inherit cargo flag-o-matic toolchain-funcs

DESCRIPTION="PVE parts ported to Rust — Perl XS library (libpve_rs.so + wrapper modules)"
HOMEPAGE="https://git.proxmox.com/?p=proxmox-perl-rs.git"

# Source: pxvirt's pinned submodule of proxmox-perl-rs
# The vendor tarball is generated separately (see docs/packages/proxmox-perl-rs.md)
EGIT_REPO_URI="https://github.com/jiangcuo/proxmox-perl-rs.git"
EGIT_COMMIT="HEAD"

SRC_URI="
	https://github.com/jiangcuo/proxmox-perl-rs/archive/refs/heads/master.tar.gz
		-> proxmox-perl-rs-${PV}.tar.gz
	https://distfiles.grimtickle.local/${PN}/${P}-vendor.tar.gz
"

LICENSE="AGPL-3 Apache-2.0 MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~loong"
IUSE=""

# Build-time: need cargo, perl, perlmod-bin (genpackage.pl)
BDEPEND="
	>=virtual/rust-1.70.0
	dev-lang/perl
	dev-perl/perlmod-bin
"

# Runtime: the .so links against openssl and standard system libs
RDEPEND="
	dev-libs/openssl:=
	dev-libs/libproxmox-rs-perl
"

# pve-rs source lives in the pve-rs/ subdirectory of the repo
S="${WORKDIR}/proxmox-perl-rs-master/pve-rs"

RESTRICT="fetch"

PATCHES=(
	"${FILESDIR}/0001-Gentoo-remove-proxmox-apt-cache-feature-no-libapt-pkg.patch"
	"${FILESDIR}/0002-Gentoo-stub-Rust-APT-exports-no-libapt-pkg.patch"
)

pkg_nofetch() {
	eerror "The vendor tarball must be generated manually:"
	eerror "  See: ${PORTAGE_CONFIGROOT}usr/share/doc/${PF}/proxmox-perl-rs.md"
	eerror "  or:  grimtickle-overlay/docs/packages/proxmox-perl-rs.md"
	eerror ""
	eerror "After generation, place the file at:"
	eerror "  \${DISTDIR}/${P}-vendor.tar.gz"
}

src_unpack() {
	unpack "proxmox-perl-rs-${PV}.tar.gz"
	# Unpack vendor tarball alongside pve-rs source
	cd "${WORKDIR}/proxmox-perl-rs-master/pve-rs" || die
	unpack "${P}-vendor.tar.gz"
}

src_prepare() {
	default

	# Override cargo config to use vendored sources instead of
	# Debian's /usr/share/cargo/registry path registry
	mkdir -p .cargo
	cat > .cargo/config.toml <<-EOF
		[source.crates-io]
		replace-with = "vendored-sources"

		[source.vendored-sources]
		directory = "vendor"

		[profile.release]
		debug = false
		opt-level = 2
		lto = "thin"
	EOF
}

src_compile() {
	# Build the shared library
	cargo build --release $(usex debug "" "--release") \
		|| die "cargo build failed"

	# Generate Perl wrapper modules using perlmod-bin's genpackage.pl
	local GENPACKAGE=/usr/lib/perlmod/genpackage.pl
	[[ -x "${GENPACKAGE}" ]] || die "genpackage.pl not found; is dev-perl/perlmod-bin installed?"

	"${GENPACKAGE}" \
		--lib=pve_rs \
		--lib-tag=proxmox \
		--lib-package=Proxmox::Lib::PVE \
		--lib-prefix=PVE \
		--include-file=Fixup.pm \
		PVE::RS::APT::Repositories \
		PVE::RS::Firewall::SDN \
		PVE::RS::OpenId \
		PVE::RS::ResourceScheduling::Static \
		PVE::RS::TFA \
		|| die "genpackage.pl failed"
}

src_install() {
	local VENDORARCH
	VENDORARCH=$(perl -MConfig -e 'print $Config{installvendorarch}')
	local VENDORLIB
	VENDORLIB=$(perl -MConfig -e 'print $Config{installvendorlib}')

	# Install the shared library
	insinto "${VENDORARCH}/auto"
	newins target/release/libpve_rs.so libpve_rs.so

	# Install the perlmod loader module
	insinto "${VENDORLIB}/Proxmox/Lib"
	doins Proxmox/Lib/PVE.pm

	# Install generated PVE::RS::* wrapper modules
	find PVE -name "*.pm" -print0 | while IFS= read -r -d '' pm; do
		local dir
		dir="${VENDORLIB}/$(dirname "${pm}")"
		insinto "${dir}"
		doins "${pm}"
	done

	# Install documentation
	dodoc "${WORKDIR}/proxmox-perl-rs-master/README.md" 2>/dev/null || true
}

pkg_postinst() {
	elog "libpve_rs.so is now installed."
	elog ""
	elog "APT update functionality (PVE::RS::APT cache queries) has been"
	elog "stubbed out — Gentoo does not have libapt-pkg. The stub returns"
	elog "'not available on Gentoo' for those calls. This is expected."
	elog ""
	elog "PVE::API2::APT in pve-manager is also stubbed (HTTP 501). The"
	elog "GUI APT update panel will not function, which is correct for Gentoo."
}
