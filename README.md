# Smallstep Nix User Repositories

**A collection of Smallstep software packaged for NixOS/nixpkgs**

## Setup for NixOS

Flakes is the suggested way to install the packages available on this repository, following are quick instructions to get it working.

1. Ensure flakes and experimental features are enabled in `/etc/nixos/configuration.nix`:
```
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```
2. Ensure Git is installed: Flakes require git to clone dependencies:
```
environment.systemPackages = with pkgs; [
  git
];
```
3. Rebuild: Run the following command to apply the changes:
```
sudo nixos-rebuild switch
```
4. Initialize flakes:
```
cd /etc/nixos
sudo nix flake init
```
5. Add smallstep repository to flake.nix, this example also installs the latest step-agent-plugin.

Important:
- Update `<host>` to match your NixOS configured host name, as listed in `networking.hostName` in configuration.nix.
- Update `"x86_64-linux"` to your CPU architecture, e.g. `"aarch64-linux"`. It will autodetect by default if builtins are available.

```
{
	inputs = {
		# Or change to your preferred NixOS channel
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
		smallstep = {
			url = "github:smallstep/nur";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = { self, nixpkgs, smallstep, ... }: 
		let
		system = if builtins ? currentSystem
			then builtins.currentSystem
			else "x86_64-linux";
		in
		{
		    nixosConfigurations.<host> = nixpkgs.lib.nixosSystem {
			inherit system;
			modules = [ ./configuration.nix 
				({ pkgs, ... }: {
					programs.nix-ld.enable = true;
					environment.systemPackages = with pkgs; [
						smallstep.packages.${pkgs.system}.step-agent-plugin
					];
				})
			];
		    };
		};
}
```
6. Update flakes and install packages:
```
sudo nix flake update
sudo nixos-rebuild switch
```

<!-- Remove this if you don't use github actions -->
![Build and populate cache](https://github.com/smallstep/nur/workflows/Build%20and%20populate%20cache/badge.svg)
