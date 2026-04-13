# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage

{
  pkgs ? import <nixpkgs> { },
}:

rec {
  # The `lib`, `modules`, and `overlays` names are special
  lib = import ./lib { inherit pkgs; }; # functions
  overlays = import ./overlays; # nixpkgs overlays

  nixosModules.step-agent = {
    imports = [ ./modules/step-agent.nix ];
    services.step-agent.package = pkgs.lib.mkDefault packages.step-agent;
  };

  packages = {
    step-agent_0_65_0-rc19 = pkgs.callPackage ./pkgs/step-agent/step-agent_0.65.0-rc19.nix { };
    step-agent = pkgs.callPackage ./pkgs/step-agent/step-agent_0.65.0-rc11.nix { };
    step-agent_0_65_0-rc11 = pkgs.callPackage ./pkgs/step-agent/step-agent_0.65.0-rc11.nix { };
  };
}
