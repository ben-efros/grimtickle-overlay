# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Pure Perl library — no XS, no compilation.
# Source: jiangcuo/pve-common fork of Proxmox pve-common.

inherit perl-module

DESCRIPTION="Proxmox VE base Perl library (Tools, JSONSchema, INotify, SectionConfig, …)"
HOMEPAGE="https://git.proxmox.com/?p=pve-common.git"

# Using a snapshot tarball from the jiangcuo pxvirt fork
# Commit pinned to what pxvirt builds at version 9.0.11
MY_COMMIT="HEAD"
SRC_URI="https://github.com/jiangcuo/pve-common/archive/refs/heads/master.tar.gz
	-> ${P}.tar.gz"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~loong"
IUSE="test"
RESTRICT="!test? ( test )"

# Runtime: all Perl module deps confirmed in Gentoo tree (audited 2025-07-03)
RDEPEND="
	dev-lang/perl
	dev-perl/AnyEvent
	dev-perl/Clone
	dev-perl/Crypt-OpenSSL-Random
	dev-perl/Crypt-OpenSSL-RSA
	dev-perl/Devel-Cycle
	dev-perl/Filesys-Df
	dev-perl/HTTP-Daemon
	dev-perl/HTTP-Message
	dev-perl/IO-stringy
	dev-perl/JSON
	dev-perl/Linux-Inotify2
	dev-perl/MIME-Base32
	dev-perl/Net-DBus
	dev-perl/Net-IP
	dev-perl/NetAddr-IP
	dev-perl/String-ShellQuote
	dev-perl/TimeDate
	dev-perl/URI
	dev-perl/libwww-perl
	dev-perl/YAML-LibYAML
	dev-perl/proxmox-perl-rs
"
# libproxmox-acme-perl and libproxmox-rs-perl are RDEPEND once ported;
# they are not strictly required for the core library to load on Gentoo.
# Add them when those ebuilds are complete:
#   grimtickle-overlay/dev-perl/proxmox-acme
#   grimtickle-overlay/dev-libs/libproxmox-rs-perl

BDEPEND="
	${RDEPEND}
	test? (
		dev-perl/Test-MockModule
	)
"

S="${WORKDIR}/pve-common-master"

src_compile() {
	# Pure Perl — nothing to compile
	:
}

src_install() {
	local PERLDIR
	PERLDIR=$(perl -MConfig -e 'print $Config{installvendorlib}')

	cd src || die

	# Install all PVE::* library modules
	insinto "${PERLDIR}"
	doins -r PVE

	cd "${S}" || die
	dodoc README.dev
}

src_test() {
	cd test || die
	emake check
}
