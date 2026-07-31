# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3

DESCRIPTION="Web client for the Jellyfin media server"
HOMEPAGE="https://jellyfin.org/ https://github.com/jellyfin/jellyfin-web"

#EGIT_REPO_URI="https://github.com/jellyfin/jellyfin-web.git"
EGIT_REPO_URI="https://github.com/ben-efros/jellyfin-web.git"
EGIT_BRANCH="master"

LICENSE="GPL-2+"
SLOT="0"
KEYWORDS=""
IUSE="system-fonts"

# npm ci downloads the dependency tree described by package-lock.json.
#
# This is suitable for an experimental live ebuild, but not for the official
# Gentoo repository. A repository-quality package must make its complete
# dependency graph available before src_compile.
RESTRICT="
    network-sandbox
"

BDEPEND="
    >=net-libs/nodejs-24[npm]
"

WEB_INSTALL_DIR="/usr/share/jellyfin/web"

src_prepare() {
    default

    # Keep npm from phoning home with audit/funding requests during builds.
    export npm_config_audit=false
    export npm_config_fund=false
    export npm_config_update_notifier=false

    # Put npm's writable state under Portage's temporary directory.
    export npm_config_cache="${T}/npm-cache"

    mkdir -p "${npm_config_cache}" ||
        die "Unable to create npm cache"
}

src_configure() {
    export npm_config_audit=false
    export npm_config_fund=false
    export npm_config_update_notifier=false
    export npm_config_cache="${T}/npm-cache"

    if use system-fonts; then
        export USE_SYSTEM_FONTS=1
    else
        export USE_SYSTEM_FONTS=0
    fi

    # The webpack configuration embeds this value into the client.
    export JELLYFIN_VERSION="9999"
}

src_compile() {
    einfo "Installing locked Jellyfin Web dependencies"

    npm ci \
        --ignore-scripts=false \
        --foreground-scripts ||
        die "npm dependency installation failed"

    einfo "Building Jellyfin Web"

    npm run build:production ||
        die "Jellyfin Web production build failed"

    [[ -f dist/index.html ]] ||
        die "Jellyfin Web did not produce dist/index.html"
}

src_install() {
    insinto "${WEB_INSTALL_DIR}"
    doins -r dist/.

    # All web assets should be owned by Portage and immutable to Jellyfin.
    fowners -R root:root "${WEB_INSTALL_DIR}"
    fperms -R go-w "${WEB_INSTALL_DIR}"

    dodoc README.md
}

pkg_postinst() {
    elog "Jellyfin Web was installed in:"
    elog "  ${WEB_INSTALL_DIR}"
}
