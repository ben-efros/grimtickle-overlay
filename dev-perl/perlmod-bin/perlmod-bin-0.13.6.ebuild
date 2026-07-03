# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Script to generate Perl package files for perlmod Rust libraries"
HOMEPAGE="https://git.proxmox.com/?p=perlmod.git"
SRC_URI=""

LICENSE="Apache-2.0 MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~loong"

RDEPEND="
	dev-lang/perl
	dev-libs/binutils-libs
"

S="${FILESDIR}"

src_install() {
	insinto /usr/lib/perlmod
	doins genpackage.pl
	fperms 0755 /usr/lib/perlmod/genpackage.pl
}
