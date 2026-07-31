# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 systemd

DESCRIPTION="Smart PVR for newsgroup and BitTorrent users"
HOMEPAGE="
    https://sonarr.tv/
    https://github.com/Sonarr/Sonarr
"

#EGIT_REPO_URI="https://github.com/Sonarr/Sonarr.git"
EGIT_REPO_URI="https://github.com/ben-efros/Sonarr.git"
EGIT_BRANCH="v5-develop"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""
IUSE="systemd"

# Both NuGet restore and Yarn dependency installation access the network.
#
# This is acceptable for an experimental live ebuild, but not acceptable for
# submission to the official Gentoo repository. A proper non-live ebuild would
# need all NuGet and JavaScript dependencies represented in SRC_URI or supplied
# from local package caches.
RESTRICT="
    network-sandbox
    strip
"

BDEPEND="
    >=virtual/dotnet-sdk-10.0
    >=net-libs/nodejs-20
    =sys-apps/yarn-1.22*
"

RDEPEND="
    acct-group/sonarr
    acct-user/sonarr
    dev-db/sqlite:3
    dev-libs/icu:=
    media-video/mediainfo
"

DEPEND="${RDEPEND}"

SONARR_INSTALL_DIR="/opt/sonarr"
SONARR_DATA_DIR="/var/lib/sonarr"

sonarr_set_build_environment() {
    export HOME="${T}/home"
    export DOTNET_CLI_HOME="${T}/dotnet-home"
    export NUGET_PACKAGES="${T}/nuget-packages"
    export YARN_CACHE_FOLDER="${T}/yarn-cache"

    export DOTNET_CLI_TELEMETRY_OPTOUT=1
    export DOTNET_NOLOGO=1
    export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
    export NUGET_XMLDOC_MODE=skip

    # Prevent Node/Corepack from silently selecting a different Yarn major.
    export COREPACK_ENABLE_PROJECT_SPEC=0

    mkdir -p \
        "${HOME}" \
        "${DOTNET_CLI_HOME}" \
        "${NUGET_PACKAGES}" \
        "${YARN_CACHE_FOLDER}" ||
        die "Unable to create build cache directories"
}

sonarr_get_rid() {
    local libc

    case "${ARCH}" in
        amd64)
            libc="x64"
            ;;
        arm64)
            libc="arm64"
            ;;
        arm)
            libc="arm"
            ;;
        x86)
            libc="x86"
            ;;
        *)
            die "Unsupported architecture: ${ARCH}"
            ;;
    esac

    if use elibc_musl; then
        case "${ARCH}" in
            amd64|arm64)
                printf '%s\n' "linux-musl-${libc}"
                ;;
            *)
                die "Sonarr does not define a musl RID for ${ARCH}"
                ;;
        esac
    else
        printf '%s\n' "linux-${libc}"
    fi
}

src_prepare() {
    default

    sonarr_set_build_environment

    local installed_sdk
    local requested_sdk

    installed_sdk="$(dotnet --version)" ||
        die "Unable to determine installed .NET SDK"

    requested_sdk="$(
        sed -n \
            's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
            global.json |
            head -n 1
    )"

    [[ -n "${requested_sdk}" ]] ||
        die "Unable to determine Sonarr's requested SDK from global.json"

    einfo "Sonarr requests .NET SDK ${requested_sdk}"
    einfo "Installed .NET SDK is ${installed_sdk}"

    if [[ "${installed_sdk}" != "${requested_sdk}" ]]; then
        ewarn "The installed SDK does not exactly match global.json."
        ewarn "Rewriting global.json to use ${installed_sdk} with feature-band"
        ewarn "roll-forward enabled."

        cat > global.json <<-EOF || die "Unable to rewrite global.json"
	{
	  "sdk": {
	    "version": "${installed_sdk}",
	    "rollForward": "latestFeature",
	    "allowPrerelease": false
	  }
	}
	EOF
    fi
}

src_configure() {
    sonarr_set_build_environment
}

src_compile() {
    sonarr_set_build_environment

    local rid
    rid="$(sonarr_get_rid)" || die

    einfo "Building Sonarr for ${rid}"

    einfo "Installing JavaScript dependencies"
    yarn install \
        --frozen-lockfile \
        --non-interactive \
        --ignore-scripts=false ||
        die "Yarn dependency installation failed"

    einfo "Building Sonarr web interface"
    yarn build ||
        die "Sonarr frontend build failed"

    einfo "Restoring .NET dependencies"
    dotnet restore \
        src/Sonarr.sln \
        --runtime "${rid}" \
        -p:RuntimeIdentifiers="${rid}" ||
        die "Sonarr NuGet restore failed"

    einfo "Publishing Sonarr.Console"
    dotnet publish \
        src/NzbDrone.Console/Sonarr.Console.csproj \
        --configuration Release \
        --runtime "${rid}" \
        --self-contained true \
        --no-restore \
        --output "${S}/_publish" \
        -p:Platform=Posix \
        -p:RuntimeIdentifiers="${rid}" \
        -p:PublishReadyToRun=false \
        -p:PublishSingleFile=false \
        -p:DebugSymbols=false \
        -p:DebugType=None \
        -p:EnableAnalyzers=false ||
        die "Sonarr backend build failed"

    [[ -x "${S}/_publish/Sonarr" ]] ||
        die "Published Sonarr executable was not produced"

    if [[ ! -d "${S}/_output/UI" ]]; then
        die "Frontend build did not produce _output/UI"
    fi
}

src_install() {
    dodir "${SONARR_INSTALL_DIR}"

    cp -a "${S}/_publish/." \
        "${ED}${SONARR_INSTALL_DIR}/" ||
        die "Unable to install Sonarr backend"

    dodir "${SONARR_INSTALL_DIR}/UI"

    cp -a "${S}/_output/UI/." \
        "${ED}${SONARR_INSTALL_DIR}/UI/" ||
        die "Unable to install Sonarr frontend"

    # Sonarr looks for MediaInfo next to its executable on some platforms.
    # Gentoo provides it system-wide, so do not bundle another copy.
    find "${ED}${SONARR_INSTALL_DIR}" \
        -type f \
        \( -name 'libmediainfo.so*' -o -name 'libzen.so*' \) \
        -delete ||
        die "Unable to remove bundled MediaInfo libraries"

    # The installation is package-managed. Sonarr's built-in updater must not
    # modify /opt/sonarr behind Portage's back.
    fowners -R root:root "${SONARR_INSTALL_DIR}"
    fperms -R go-w "${SONARR_INSTALL_DIR}"

    keepdir "${SONARR_DATA_DIR}"
    fowners sonarr:sonarr "${SONARR_DATA_DIR}"
    fperms 0750 "${SONARR_DATA_DIR}"

    newinitd "${FILESDIR}/sonarr.initd" sonarr
    newconfd "${FILESDIR}/sonarr.confd" sonarr

    systemd_dounit "${FILESDIR}/sonarr.service"

    dodoc README.md
}

pkg_postinst() {
    elog "Sonarr was installed in:"
    elog "  ${SONARR_INSTALL_DIR}"
    elog
    elog "Its mutable application data is stored in:"
    elog "  ${SONARR_DATA_DIR}"
    elog
    elog "OpenRC:"
    elog "  rc-update add sonarr default"
    elog "  rc-service sonarr start"
    elog
    elog "systemd:"
    elog "  systemctl enable --now sonarr.service"
    elog
    elog "The default web interface is normally available at:"
    elog "  http://127.0.0.1:8989"
    elog
    elog "Disable Sonarr's built-in automatic updater. Files under"
    elog "${SONARR_INSTALL_DIR} are owned by Portage and intentionally"
    elog "not writable by the sonarr account."
}
