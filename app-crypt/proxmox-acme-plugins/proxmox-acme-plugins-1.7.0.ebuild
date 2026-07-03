# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# DNS API plugins for proxmox-acme (acme.sh 3.1.1 bundled copy + wrapper).
# 150+ DNS provider shell scripts; runtime deps are bash, curl, sed only.
# Note: Gentoo has app-crypt/acme-sh 3.1.3, but proxmox-acme uses a bundled
# copy patched for the proxmox-acme wrapper interface — do not substitute.

inherit git-r3

DESCRIPTION="Proxmox ACME DNS API plugins (acme.sh wrapper for Let's Encrypt DNS challenges)"
HOMEPAGE="https://git.proxmox.com/?p=proxmox-acme.git"

EGIT_REPO_URI="https://git.proxmox.com/git/proxmox-acme"
EGIT_BRANCH="master"

LICENSE="AGPL-3 GPL-3"
SLOT="0"
KEYWORDS=""
IUSE=""

RDEPEND="
	app-shells/bash
	net-misc/curl
	sys-apps/sed
	net-dns/bind-tools
"

S="${WORKDIR}/${PN}"

src_compile() {
	:
}

src_install() {
	cd src || die

	# Install the proxmox-acme wrapper script
	exeinto /usr/share/proxmox-acme
	doexe proxmox-acme

	# Install dns-challenge schema
	insinto /usr/share/proxmox-acme
	doins dns-challenge-schema.json

	# Install all acme.sh DNS API plugins
	insinto /usr/share/proxmox-acme/dnsapi
	doins acme.sh/dnsapi/*.sh
}
