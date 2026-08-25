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
5. Add smallstep repository to `flake.nix`, this example also installs the latest `step-agent` package available.

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
						smallstep.packages.${pkgs.system}.step-agent
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

**Note**: The first time you execute the commands above it will take a bit longer to finish.

7. Check that `step-agent` program was successfully installed by typing the following commmand on a terminal:
```
$ step-agent version
```

8. More information about `step-agent` can be found on the following page: [Step Agent docs](https://smallstep.com/docs/platform/smallstep-app/)

## Packaging

Attributes are generated from the contents of `pkgs/`. Every
`pkgs/<name>/<name>_<version>.nix` is registered automatically as
`<name>_<version>`, with `.` replaced by `_`:

| File | Attribute |
|------|-----------|
| `pkgs/step-agent/step-agent_0.69.0.nix` | `step-agent_0_69_0` |
| `pkgs/step-agent/step-agent_0.69.1-rc1.nix` | `step-agent_0_69_1-rc1` |

The unsuffixed `step-agent` attribute is the highest **stable** version present
— prereleases are only reachable by their explicit attribute.

Releasing is therefore just committing the derivation: goreleaser writes the
file from `smallstep/agent` and there is no package list to keep in sync.

<!-- Remove this if you don't use github actions -->
![Build and populate cache](https://github.com/smallstep/nur/workflows/Build%20and%20populate%20cache/badge.svg)
