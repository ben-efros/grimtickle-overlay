# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DIST_AUTHOR=GOZER
DIST_VERSION=0.13

inherit perl-module

DESCRIPTION="Perl interface to strptime(3) — required by PVE::Storage::PBSPlugin"
HOMEPAGE="https://metacpan.org/release/POSIX-strptime"
SRC_URI="https://cpan.metacpan.org/authors/id/G/GO/${DIST_AUTHOR}/POSIX-strptime-${DIST_VERSION}.tar.gz"
S="${WORKDIR}/POSIX-strptime-${DIST_VERSION}"

LICENSE="|| ( Artistic GPL-1+ )"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~loong"

RDEPEND="dev-lang/perl"
BDEPEND="dev-lang/perl"
