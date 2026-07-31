# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 systemd

DESCRIPTION="Free software media server"
HOMEPAGE="https://jellyfin.org/ https://github.com/jellyfin/jellyfin"

#EGIT_REPO_URI="https://github.com/jellyfin/jellyfin.git"
EGIT_REPO_URI="https://github.com/ben-efros/jellyfin.git"
EGIT_BRANCH="master"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS=""
IUSE="debug"

# dotnet restore downloads NuGet packages and runtime packs.
RESTRICT="
    network-sandbox
    strip
"

BDEPEND="
    >=virtual/dotnet-sdk-10.0
"

RDEPEND="
    acct-group/jellyfin
    acct-user/jellyfin
    dev-libs/icu:=
    dev-libs/openssl:=
    media-libs/fontconfig
    media-libs/freetype
    media-video/ffmpeg
    media-video/jellyfin-web
    sys-libs/zlib
"

DEPEND="${RDEPEND}"

JELLYFIN_INSTALL_DIR="/usr/lib/jellyfin"
JELLYFIN_WEB_DIR="/usr/share/jellyfin/web"
JELLYFIN_DATA_DIR="/var/lib/jellyfin"
JELLYFIN_CONFIG_DIR="/etc/jellyfin"
JELLYFIN_CACHE_DIR="/var/cache/jellyfin"
JELLYFIN_LOG_DIR="/var/log/jellyfin"

jellyfin_set_build_environment() {
    export HOME="${T}/home"
    export DOTNET_CLI_HOME="${T}/dotnet-home"
    export NUGET_PACKAGES="${T}/nuget-packages"

    export DOTNET_CLI_TELEMETRY_OPTOUT=1
    export DOTNET_NOLOGO=1
    export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
    export NUGET_XMLDOC_MODE=skip

    mkdir -p \
        "${HOME}" \
        "${DOTNET_CLI_HOME}" \
        "${NUGET_PACKAGES}" ||
        die "Unable to create .NET build directories"
}

jellyfin_get_rid() {
    local cpu

    case "${ARCH}" in
        amd64)
            cpu="x64"
            ;;
        arm64)
            cpu="arm64"
            ;;
        arm)
            cpu="arm"
            ;;
        x86)
            cpu="x86"
            ;;
        riscv)
            cpu="riscv64"
            ;;
        *)
            die "Unsupported Jellyfin architecture: ${ARCH}"
            ;;
    esac

    if use elibc_musl; then
        printf '%s\n' "linux-musl-${cpu}"
    else
        printf '%s\n' "linux-${cpu}"
    fi
}
src_prepare() {
    default
    jellyfin_set_build_environment

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
        die "Unable to read requested SDK version from global.json"

    einfo "Jellyfin requests .NET SDK ${requested_sdk}"
    einfo "Installed .NET SDK is ${installed_sdk}"

    if [[ "${installed_sdk}" != "${requested_sdk}" ]]; then
        ewarn "Using installed .NET SDK ${installed_sdk} instead of ${requested_sdk}"

        {
            cat <<-EOF
		{
		  "sdk": {
		    "version": "${installed_sdk}",
		    "rollForward": "latestFeature",
		    "allowPrerelease": false
		  }
		}
		EOF
        } > global.json || die "Unable to rewrite global.json"
    fi
}

src_configure() {
    jellyfin_set_build_environment
}

src_compile() {
    jellyfin_set_build_environment

    local configuration
    local rid

    rid="$(jellyfin_get_rid)" || die

    if use debug; then
        configuration="Debug"
    else
        configuration="Release"
    fi

    einfo "Building Jellyfin ${configuration} for ${rid}"

    dotnet restore \
        Jellyfin.Server/Jellyfin.Server.csproj \
        --runtime "${rid}" \
        -p:RuntimeIdentifier="${rid}" ||
        die "Jellyfin NuGet restore failed"

    dotnet publish \
        Jellyfin.Server/Jellyfin.Server.csproj \
        --configuration "${configuration}" \
        --runtime "${rid}" \
        --self-contained true \
        --no-restore \
        --output "${S}/_publish" \
        -p:RuntimeIdentifier="${rid}" \
        -p:PublishSingleFile=false \
        -p:PublishReadyToRun=false \
        -p:DebugSymbols="$(usex debug true false)" \
        -p:DebugType="$(usex debug portable none)" \
        -p:UseAppHost=true ||
        die "Jellyfin server build failed"

    [[ -x "${S}/_publish/jellyfin" ]] ||
        die "Published Jellyfin executable was not produced"
}

src_install() {
    dodir "${JELLYFIN_INSTALL_DIR}"

    cp -a "${S}/_publish/." \
        "${ED}${JELLYFIN_INSTALL_DIR}/" ||
        die "Unable to install Jellyfin"

    # Jellyfin plugins live under the writable data directory, not in the
    # program installation. Keep the application itself Portage-owned.
    fowners -R root:root "${JELLYFIN_INSTALL_DIR}"
    fperms -R go-w "${JELLYFIN_INSTALL_DIR}"

    insinto "${JELLYFIN_CONFIG_DIR}"
    newins "${FILESDIR}/jellyfin.env" jellyfin.env

    keepdir \
        "${JELLYFIN_DATA_DIR}" \
        "${JELLYFIN_DATA_DIR}/plugins" \
        "${JELLYFIN_CONFIG_DIR}" \
        "${JELLYFIN_CACHE_DIR}" \
        "${JELLYFIN_LOG_DIR}"

    fowners jellyfin:jellyfin \
        "${JELLYFIN_DATA_DIR}" \
        "${JELLYFIN_DATA_DIR}/plugins" \
        "${JELLYFIN_CACHE_DIR}" \
        "${JELLYFIN_LOG_DIR}"

    fperms 0750 \
        "${JELLYFIN_DATA_DIR}" \
        "${JELLYFIN_DATA_DIR}/plugins" \
        "${JELLYFIN_CACHE_DIR}" \
        "${JELLYFIN_LOG_DIR}"

    # /etc/jellyfin must be writable because Jellyfin generates and updates
    # configuration files there.
    fowners jellyfin:jellyfin "${JELLYFIN_CONFIG_DIR}"
    fperms 0750 "${JELLYFIN_CONFIG_DIR}"

    newinitd "${FILESDIR}/jellyfin.initd" jellyfin
    newconfd "${FILESDIR}/jellyfin.confd" jellyfin

    systemd_dounit "${FILESDIR}/jellyfin.service"

    dodoc README.md
}

pkg_postinst() {
    elog "Jellyfin was installed in:"
    elog "  ${JELLYFIN_INSTALL_DIR}"
    elog
    elog "Web assets:"
    elog "  ${JELLYFIN_WEB_DIR}"
    elog
    elog "Data:"
    elog "  ${JELLYFIN_DATA_DIR}"
    elog
    elog "Configuration:"
    elog "  ${JELLYFIN_CONFIG_DIR}"
    elog
    elog "OpenRC:"
    elog "  rc-update add jellyfin default"
    elog "  rc-service jellyfin start"
    elog
    elog "systemd:"
    elog "  systemctl enable --now jellyfin.service"
    elog
    elog "The initial setup interface is normally available at:"
    elog "  http://127.0.0.1:8096"
}
