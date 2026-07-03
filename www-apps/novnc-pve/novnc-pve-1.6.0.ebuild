# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="HTML5 VNC client with Proxmox/pxvirt patches"
HOMEPAGE="https://novnc.com/ https://git.proxmox.com/?p=novnc-pve.git"

# Upstream noVNC 1.6.0 with 20 Proxmox patches.
# Proxmox package: novnc-pve 1.6.0-3
SRC_URI="https://github.com/novnc/noVNC/archive/refs/tags/v${PV}.tar.gz -> noVNC-${PV}.tar.gz"

S="${WORKDIR}/noVNC-${PV}"

LICENSE="MPL-2.0"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~loong"
IUSE=""

# esbuild bundles app/ui.js and its imports into a single app.js ESM bundle.
# The resulting app.js is what pveproxy serves; no runtime JS toolchain is needed.
BDEPEND="dev-util/esbuild"
RDEPEND=""
DEPEND=""

PATCHES=(
	"${FILESDIR}/0001-add-PVE-specific-JS-code.patch"
	"${FILESDIR}/0002-add-custom-fbresize-event-on-rfb.patch"
	"${FILESDIR}/0003-change-scaling-when-toggling-fullscreen.patch"
	"${FILESDIR}/0004-add-pve-style.patch"
	"${FILESDIR}/0005-remove-vnc-logos.patch"
	"${FILESDIR}/0006-change-source-directory-for-fetching-images-js-files.patch"
	"${FILESDIR}/0007-add-pve-vnc-commands.patch"
	"${FILESDIR}/0008-add-replaceable-snippets-in-vnc.html.patch"
	"${FILESDIR}/0009-decrease-animation-time.patch"
	"${FILESDIR}/0010-use-only-app.js.patch"
	"${FILESDIR}/0011-add-localCursor-setting-to-rfb.patch"
	"${FILESDIR}/0012-pass-custom-command-to-vnc.patch"
	"${FILESDIR}/0013-Revert-Remove-the-default-value-of-wsProtocols.patch"
	"${FILESDIR}/0014-avoid-passing-deprecated-upgrade-parameter.patch"
	"${FILESDIR}/0015-create-own-class-for-hidden-buttons.patch"
	"${FILESDIR}/0016-hide-fullscreen-button-on-isFullscreen-get-variable.patch"
	"${FILESDIR}/0017-make-error-hideable.patch"
	"${FILESDIR}/0018-show-start-button-on-not-running-vm-ct.patch"
	"${FILESDIR}/0019-show-clipboard-button.patch"
	"${FILESDIR}/0020-Fix-appearance-of-extra-key-buttons.patch"
)

src_compile() {
	# Bundle app/ui.js and all its imports into a single ESM module.
	# Mirrors: esbuild --bundle --format=esm app/ui.js > app.js
	esbuild --bundle --format=esm app/ui.js > app.js || die "esbuild failed"

	# Generate index.html.tpl from vnc.html:
	# Append ?ver=<version> to all .css and .js references so browsers
	# don't serve stale cached assets after upgrades.
	cp vnc.html index.html.tpl || die
	sed -i -re "s/\.(css|js)/\.\\1?ver=${PV}-pve/g" index.html.tpl || die

	# Generate the package.json version marker used by pveproxy.
	echo "{ \"version\": \"${PV}-pve\" }" > package.json || die
}

src_install() {
	local destdir=/usr/share/novnc-pve

	# Static app assets
	insinto "${destdir}/app"
	doins -r app/images
	doins -r app/locale
	doins -r app/sounds
	doins -r app/styles
	doins app/error-handler.js

	# Built bundle + generated files
	insinto "${destdir}"
	doins app.js
	doins index.html.tpl
	doins package.json

	# Documentation
	doins -r docs
}
