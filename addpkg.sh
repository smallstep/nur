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

if [ "$OS" = "Mac" ]; then
    xsed() {
        sed -i "" "$@"
    }
else
    xsed() {
        sed -i "$@"
    }
fi

if ! grep -Eqs "${pkg_with_version}[[:blank:]]*=" default.nix; then
    echo "Adding new package entry to default.nix: pkg=$pkg  version=$version"

    xsed "/<package-list>/a\\
  ${pkg_name} = ${nix_entry}" default.nix
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
