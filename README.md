# grimtickle-overlay

A personal Gentoo Portage overlay.

This repository contains extra ebuilds that are not part of the main Gentoo repository, or local versions of packages maintained for my own systems.

## What is this?

This repository is a Gentoo overlay, also called an additional Portage repository.

Once added to a Gentoo system, packages from this overlay can be installed with emerge like normal Gentoo packages.

## Requirements

You need a Gentoo system with Portage installed.

Recommended helper package:

    emerge --ask app-eselect/eselect-repository

## Installing this overlay

The recommended way to add this overlay is with eselect-repository.

    eselect repository add grimtickle-overlay git https://github.com/benefros/grimtickle-overlay.git

Then sync the overlay:

    emaint sync -r grimtickle-overlay

Or sync all configured repositories:

    emerge --sync

## Installing packages

After the overlay has been synced, packages can be installed normally.

Example:

    emerge --ask category/package-name

For example, if this overlay contains:

    app-misc/example-tool/example-tool-1.0.0.ebuild

you would install it with:

    emerge --ask app-misc/example-tool

## Updating the overlay

To update only this overlay:

    emaint sync -r grimtickle-overlay

To update all repositories:

    emerge --sync

## Removing the overlay

To remove the overlay if it was added with eselect-repository:

    eselect repository remove grimtickle-overlay

You may also remove the local repository directory if it still exists:

    rm -rf /var/db/repos/grimtickle-overlay

## Manual installation

If you do not want to use eselect-repository, you can configure the overlay manually.

Create a Portage repository config file:

    mkdir -p /etc/portage/repos.conf
    nano /etc/portage/repos.conf/grimtickle-overlay.conf

Add this:

    [grimtickle-overlay]
    location = /var/db/repos/grimtickle-overlay
    sync-type = git
    sync-uri = https://github.com/benefros/grimtickle-overlay.git
    auto-sync = yes

Then sync it:

    emaint sync -r grimtickle-overlay

## Repository layout

This overlay uses the standard Gentoo repository layout.

Minimum required files:

    metadata/layout.conf
    profiles/repo_name
    profiles/eapi

Example layout:

    my-overlay/
        README.md
        metadata/
            layout.conf
        profiles/
            eapi
            repo_name
        app-misc/
            example-tool/
                Manifest
                metadata.xml
                example-tool-1.0.0.ebuild

## Example profiles/repo_name

    grimtickle-overlay

## Example profiles/eapi

    8

## Example metadata/layout.conf

    masters = gentoo
    thin-manifests = true


## Maintaining packages

When adding or changing ebuilds, regenerate the Manifest:

    pkgdev manifest

Or for one package:

    ebuild category/package/package-version.ebuild manifest

Run QA checks before committing:

    pkgcheck scan

Then commit the changes:

    git add .
    git commit -m "Add package-name"
    git push

## Package keywords

Packages in this overlay may use unstable keywords such as:

    KEYWORDS="~amd64"

That means the package is available for testing on that architecture.

Do not assume packages are stable unless clearly marked. Overlay packages are often less polished than official Gentoo packages. That is the tax we pay for freedom and questionable life choices.

## Accepting keywords

If Portage says a package is masked by keyword, you may need to accept the keyword locally.

Example:

    echo "category/package-name ~amd64" >> /etc/portage/package.accept_keywords/grimtickle-overlay

Then try again:

    emerge --ask category/package-name

## Unmasking packages

If a package is masked, Portage may ask you to unmask it.

Example:

    echo "category/package-name" >> /etc/portage/package.unmask/grimtickle-overlay

Only do this if you trust the package and understand why it is masked.

## License notes

Packages in this overlay may have different licenses.

If Portage asks you to accept a license, review it first. Example:

    echo "category/package-name license-name" >> /etc/portage/package.license/grimtickle-overlay

## Reporting issues

If something fails, please include:

    The package name
    The exact emerge command used
    The build log
    Your architecture
    Your Gentoo profile

Useful commands:

    emerge --info

    emerge --pretend --verbose category/package-name

Build logs are usually found under:

    /var/tmp/portage/category/package-name/temp/build.log

## Disclaimer

This overlay is provided as-is.

Packages may be experimental, locally maintained, temporarily broken, or tailored for specific systems. Use at your own risk.

If it breaks, your problem.
