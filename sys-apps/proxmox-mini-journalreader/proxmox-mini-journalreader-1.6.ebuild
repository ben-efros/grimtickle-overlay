# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 toolchain-funcs

DESCRIPTION="Minimal systemd journal reader used by pxvirt node management"
HOMEPAGE="https://git.proxmox.com/?p=proxmox-mini-journal.git"

EGIT_REPO_URI="git://git.proxmox.com/git/proxmox-mini-journal.git"
EGIT_COMMIT="HEAD"  # TODO: pin to commit for reproducible builds
# proxmox-mini-journalreader 1.6 (trixie)

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~loong"
IUSE=""

BDEPEND="
	app-text/scdoc
	virtual/pkgconfig
"
DEPEND="sys-apps/systemd:="
RDEPEND="${DEPEND}"

# Source lives in the src/ subdirectory of the git repo
S="${WORKDIR}/${PN}/src"

src_unpack() {
	git-r3_src_unpack
}

src_compile() {
	# Respect Gentoo CC/CFLAGS; don't hardcode gcc
	emake CC="$(tc-getCC)" \
		CFLAGS="${CFLAGS} -Wall -Wextra -Wl,-z,relro -fstack-protector-strong -D_FORTIFY_SOURCE=2 --std=gnu11" \
		LDFLAGS="${LDFLAGS}"
}

src_install() {
	# Installs to /usr/libexec/ — pveproxy spawns this as a subprocess
	# to tail the systemd journal for the node log view in the web UI.
	emake install \
		DESTDIR="${D}" \
		LIBEXEC_DIR="${D}/usr/libexec" \
		MAN1_DIR="${D}/usr/share/man/man1"
}
