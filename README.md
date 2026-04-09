# Smallstep Nix User Repositories

**A collection of Smallstep software packaged for NixOS/nixpkgs**

## Setup for NixOS with flakes

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

## Setup for NixOS with npins

If you do not want to use flakes but still want to pin your dependencies you can use a tool like `npins`, `niv`, ...
This guide assumes that you have advanced knowledge of nix and you know how to rebuild your host.
We will use `npins` in this example.

1. Add this repository as an input

```
npins add github smallstep nur -b main --name smallstep
```

> If you want to manually update the package you can add the `--frozen` flag.

2. Configure your host to install `step-agent`

```nix
{
  sources, # or `sources ? (import ./npins)`
  pkgs, # or pkgs ? sources.nixpkgs,
  ...
}:
let
  smallstep = import sources.nur { inherit pkgs; }; # if you pass pkgs, `step-agent` will use your nixpkgs instead of the locked one (advised)
in
{
  environment.systemPackages = [
    smallstep.step-agent
  ];
  # [...]
}
```

3. Rebuild and test with `step-agent version`

## Clasical NixOS setup (discouraged)

```nix
{...}:
let
  smallstep = builtins.getFlake "github:smallstep/nur";
in
{
  environment.systemPackages = [
    smallstep.step-agent
  ];
}
```

More information about `step-agent` can be found on the following page: [Step Agent docs](https://smallstep.com/docs/platform/smallstep-app/)

   <!-- Remove this if you don't use github actions -->

![Build and populate cache](https://github.com/smallstep/nur/workflows/Build%20and%20populate%20cache/badge.svg)
