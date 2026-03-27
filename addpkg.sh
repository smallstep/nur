#!/bin/bash

[ $# -lt 1 ] && {
    echo "usage: $0 <package_name>"
    exit 1
}

pkg="$1"
pkg_with_version=$(basename $(ls -1 pkgs/${pkg}/${pkg}_* | sort -Vr | head -n 1) .nix)
pkg_name="$(echo ${pkg_with_version} | tr '.' '_')"
nix_entry="pkgs.callPackage ./pkgs/${pkg}/${pkg_with_version}.nix { };"

unameOut="$(uname -s)"
OS=Linux

case "${unameOut}" in
Darwin*) OS=Mac ;;
esac

# Handle differences between MacOS and Linux sed implementation.
if [ "$OS" = "Mac" ]; then
    xsed() {
        sed -i "" "$@"
    }
else
    xsed() {
        sed -i "$@"
    }
fi

# Add a new entry for the package version to default.nix, including rc and dev releases.
# Example, for a ${pkg_with_version} = "step-agent_0_65_0-rc11", the entry below would be added:
# step-agent_0_65_0-rc11 = pkgs.callPackage ./pkgs/step-agent/step-agent_0.65.0-rc11.nix { };
if ! grep -Eqs "${pkg_with_version}[[:blank:]]*=" default.nix; then
    echo "Adding new package entry to default.nix: pkg=$pkg  version=$version"

    xsed "/<package-list>/a\\
  ${pkg_name} = ${nix_entry}" default.nix
fi

# Check if package is a stable release, if so we update the default step-agent package entry to point to it.
# Otherwise quit.
if [[ ! "$pkg_with_version" =~ _[0-9]+_[0-9]+_[0-9]+$ ]]; then
    echo "Non stable release $pkg_with_version, skipping default package update."
    exit 0
fi

# patch default package name to point to the latest version
if ! grep -Eqs "${pkg}[[:blank:]]*=" default.nix; then
    echo "Adding default $pkg package entry..."

    xsed "/<package-list>/a\\
  ${pkg} = ${nix_entry}" default.nix
else
    echo "Updating $pkg to point to new version $version"

    xsed "s#^.*${pkg} *=.*\$#  ${pkg} = ${nix_entry}#" default.nix
fi
