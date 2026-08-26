# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `nixosModules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage

{
  system ? builtins.currentSystem,
  sources ? import ./sources.nix,
  pkgs ? import sources.nixpkgs {
    inherit system;
  },
}:

let
  inherit (pkgs) lib;

  # Every derivation under pkgs/<name>/ is registered automatically, so this
  # attribute set can never drift from what goreleaser has committed. Releases
  # add a file and nothing else: there is no package list to keep in sync.
  #
  #   pkgs/step-agent/step-agent_0.69.0.nix  ->  step-agent_0_69_0
  #   pkgs/step-agent/step-agent_0.69.0-rc1.nix  ->  step-agent_0_69_0-rc1
  #
  # Version and attribute name differ only in the separator, so we keep both.
  releasesOf = name:
    let
      dir = ./pkgs + "/${name}";
      isRelease = file: type: type == "regular" && lib.hasSuffix ".nix" file;
      versionOf = file: lib.removePrefix "${name}_" (lib.removeSuffix ".nix" file);
    in
    lib.mapAttrsToList
      (file: _: rec {
        version = versionOf file;
        attr = "${name}_${builtins.replaceStrings [ "." ] [ "_" ] version}";
        package = pkgs.callPackage (dir + "/${file}") { };
      })
      (lib.filterAttrs isRelease (builtins.readDir dir));

  # A release is stable when its version carries no -rc/-dev/nightly suffix.
  isStable = release: builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" release.version != null;

  newest = releases:
    lib.head (lib.sort (a: b: builtins.compareVersions a.version b.version > 0) releases);

  # `nur.repos.smallstep.step-agent` is the obvious thing to type, so it has to
  # mean the current stable release rather than whichever file happens to sort
  # last -- `sort -V` ranks 0.68.0-rc1 above 0.68.0, and prerelease lines run
  # ahead of stable ones.
  packageSet = name:
    let
      releases = releasesOf name;
      byAttr = lib.listToAttrs
        (map (r: lib.nameValuePair r.attr r.package) releases);
      stable = lib.filter isStable releases;
    in
    byAttr // lib.optionalAttrs (stable != [ ]) {
      ${name} = (newest stable).package;
    };

in
{
  # The `lib`, `nixosModules`, and `overlays` names are special
  lib = import ./lib { inherit pkgs; }; # functions
  nixosModules = import ./nixos-modules; # NixOS modules
  overlays = import ./overlays; # nixpkgs overlays
}
// packageSet "step-agent"
