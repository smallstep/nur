{
  description = "My personal NUR repository";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    in
    {
      legacyPackages = forAllSystems (system: import ./default.nix {
        pkgs = import nixpkgs { inherit system; };
      });
      packages = forAllSystems (system: nixpkgs.lib.filterAttrs (_: v: nixpkgs.lib.isDerivation v) self.legacyPackages.${system});

      # Not per-system: a NixOS module is the same expression on every
      # platform, and importing it must not drag in an instantiated nixpkgs.
      # This is what lets a configuration.nix say
      #   imports = [ inputs.smallstep.nixosModules.step-agent ];
      nixosModules = import ./nixos-modules;
    };
}
