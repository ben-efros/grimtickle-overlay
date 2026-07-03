# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Build process:
#  1. Concatenate JS source files + marked.js → proxmoxlib.js
#  2. Minify with uglifyjs → proxmoxlib.min.js
#  3. Compile SCSS dark theme with sassc → theme-proxmox-dark.css
#  4. Install pre-existing ext6-pmx.css and static images
#
# All build tools confirmed in ::gentoo:
#   dev-util/uglifyjs, dev-lang/sassc, dev-libs/marked-js (overlay)
#
# No Perl modules — this is a pure JS/CSS package.

inherit git-r3

DESCRIPTION="Proxmox widget toolkit — ExtJS components and utilities for Proxmox web UIs"
HOMEPAGE="https://github.com/jiangcuo/proxmox-widget-toolkit"

EGIT_REPO_URI="https://github.com/jiangcuo/proxmox-widget-toolkit.git"
EGIT_BRANCH="master"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS=""
IUSE=""

RDEPEND=""
BDEPEND="
	dev-lang/sassc
	dev-util/uglifyjs
	dev-libs/marked-js
"

S="${WORKDIR}/${PN}"

WWWBASEDIR="/usr/share/javascript/proxmox-widget-toolkit"

src_compile() {
	cd "${S}/src" || die

	local MARKEDJS=/usr/share/javascript/marked/marked.js
	[[ -f "${MARKEDJS}" ]] || die "marked.js not found — install dev-libs/marked-js"

	# Ordered JS source list (matches Makefile JSSRC)
	local JSSRC=(
		Utils.js Schema.js Toolkit.js Logo.js Parser.js
		mixin/CBind.js
		data/reader/JsonObject.js data/ProxmoxProxy.js data/UpdateStore.js
		data/DiffStore.js data/ObjectStore.js data/RRDStore.js
		data/TimezoneStore.js data/model/NotificationConfig.js
		data/model/Realm.js data/model/Certificates.js data/model/ACME.js
		form/BandwidthSelector.js form/DisplayEdit.js form/ExpireDate.js
		form/IntegerField.js form/TextField.js form/TextAreaField.js
		form/VlanField.js form/DateTimeField.js form/Checkbox.js
		form/KVComboBox.js form/LanguageSelector.js form/ComboGrid.js
		form/RRDTypeSelector.js form/BondModeSelector.js
		form/NetworkSelector.js form/RealmComboBox.js form/PruneKeepField.js
		form/RoleSelector.js form/DiskSelector.js form/MultiDiskSelector.js
		form/TaskTypeSelector.js form/ACME.js form/UserSelector.js
		form/ThemeSelector.js form/FingerprintField.js
		button/Button.js button/AltText.js button/HelpButton.js
		grid/ObjectGrid.js grid/PendingObjectGrid.js
		panel/AuthView.js panel/DiskList.js panel/EOLNotice.js
		panel/InputPanel.js panel/InfoWidget.js panel/LogView.js
		panel/NodeInfoRepoStatus.js panel/NotificationConfigView.js
		panel/JournalView.js panel/PermissionView.js panel/PruneKeepPanel.js
		panel/RRDChart.js panel/GaugeWidget.js panel/GotifyEditPanel.js
		panel/Certificates.js panel/ACMEAccount.js panel/ACMEPlugin.js
		panel/ACMEDomains.js panel/EmailRecipientPanel.js
		panel/SendmailEditPanel.js panel/SmtpEditPanel.js
		panel/StatusView.js panel/TfaView.js panel/NotesView.js
		panel/WebhookEditPanel.js
		window/Edit.js window/PasswordEdit.js window/SafeDestroy.js
		window/PackageVersions.js window/TaskViewer.js window/LanguageEdit.js
		window/DiskSmart.js window/ZFSDetail.js window/Certificates.js
		window/ConsentModal.js window/ACMEAccount.js window/ACMEPluginEdit.js
		window/ACMEDomains.js window/EndpointEditBase.js
		window/NotificationMatcherEdit.js window/FileBrowser.js
		window/AuthEditBase.js window/AuthEditOpenId.js window/AuthEditLDAP.js
		window/AuthEditAD.js window/AuthEditSimple.js window/TfaWindow.js
		window/AddTfaRecovery.js window/AddTotp.js window/AddWebauthn.js
		window/AddYubico.js window/TfaEdit.js window/NotesEdit.js
		window/ThemeEdit.js window/SyncWindow.js
		node/APT.js node/APTRepositories.js node/NetworkEdit.js
		node/NetworkView.js node/DNSEdit.js node/HostsView.js
		node/DNSView.js node/Tasks.js node/ServiceView.js
		node/TimeEdit.js node/TimeView.js
	)

	# Build proxmoxlib.js: version header + all JS sources + marked.js
	local BUILD_VERSION
	BUILD_VERSION=$(git -C "${S}" rev-parse --short HEAD 2>/dev/null || echo "${PVR}")
	{
		echo "// v${BUILD_VERSION}"
		cat "${JSSRC[@]}" "${MARKEDJS}"
	} > proxmoxlib.js || die "Failed to concatenate JS sources"

	# Minify
	uglifyjs proxmoxlib.js -c -m -o proxmoxlib.min.js \
		|| die "uglifyjs minification failed"

	# Compile dark theme SCSS
	sassc -t compressed \
		proxmox-dark/scss/ProxmoxDark.scss \
		proxmox-dark/theme-proxmox-dark.css \
		|| die "sassc failed"
}

src_install() {
	local DEST="${ED}${WWWBASEDIR}"

	# JS bundles
	insinto "${WWWBASEDIR}"
	doins src/proxmoxlib.js src/proxmoxlib.min.js

	# Pre-existing CSS (no compilation needed)
	insinto "${WWWBASEDIR}/css"
	doins src/css/ext6-pmx.css

	# Compiled dark theme
	insinto "${WWWBASEDIR}/themes"
	doins src/proxmox-dark/theme-proxmox-dark.css

	# Static images
	insinto "${WWWBASEDIR}/images"
	doins \
		src/images/pmx-clear-trigger.png \
		src/images/openid-icon-100x100.png \
		src/images/icon-cpu.svg \
		src/images/icon-ram.svg \
		src/images/debian-swirl-openlogo.svg \
		src/images/proxmox-symbol-x.svg
}
