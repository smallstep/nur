# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
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

{
  # The `lib`, `modules`, and `overlays` names are special
  lib = import ./lib { inherit pkgs; }; # functions
  modules = import ./modules; # NixOS modules
  overlays = import ./overlays; # nixpkgs overlays

  # <package-list>: DO NOT REMOVE THIS LINE
  step-agent_0_65_2 = pkgs.callPackage ./pkgs/step-agent/step-agent_0.65.2.nix { };
  step-agent_0_65_1 = pkgs.callPackage ./pkgs/step-agent/step-agent_0.65.1.nix { };
  step-agent_0_65_0-rc21 = pkgs.callPackage ./pkgs/step-agent/step-agent_0.65.0-rc21.nix { };
  step-agent_0_65_0-rc20 = pkgs.callPackage ./pkgs/step-agent/step-agent_0.65.0-rc20.nix { };
  step-agent_0_65_0-rc19 = pkgs.callPackage ./pkgs/step-agent/step-agent_0.65.0-rc19.nix { };
  step-agent = pkgs.callPackage ./pkgs/step-agent/step-agent_0.65.0-rc11.nix { };
  step-agent_0_65_0-rc11 = pkgs.callPackage ./pkgs/step-agent/step-agent_0.65.0-rc11.nix { };
}
