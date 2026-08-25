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

## NixOS module

The steps above install the `step-agent` binary. They do not set up the service
that runs it. `nixosModules.step-agent` does that: it declares the `step-agent`
system user, the systemd service and its restart path unit, the PKCS#11 socket
that publishes the agent's token to `p11-kit` clients (NetworkManager,
`wpa_supplicant`, browsers), and the polkit rules the agent needs to manage
network connections.

Add it to the same `modules` list as your `configuration.nix`, and point
`services.step-agent.package` at this repository's package:

```
nixosConfigurations.<host> = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
        ./configuration.nix
        smallstep.nixosModules.step-agent
        {
            services.step-agent.package =
                smallstep.packages.${system}.step-agent;
        }
    ];
};
```

Without `services.step-agent.package`, the service falls back to
`pkgs.step-agent` from nixpkgs, which follows your nixpkgs channel and lags
behind the releases here — the daemon can run an older version than the
`step-agent` CLI installed above. Setting the option makes them the same
package.

Then register the device with your team:

```
$ sudo step-agent register [team name]
```

Registration writes `agent.yaml` into `/etc/step-agent`, which systemd creates
and keeps writable through `ConfigurationDirectory=`. Do not manage
`agent.yaml` with `environment.etc`: that produces a read-only symlink into the
Nix store, and the service refuses to start.

**A hardware TPM 2.0 is required.** The Debian and RPM packages fall back to a
software TPM on hosts without one, but the helper scripts that set that up are
FHS-specific and are not part of the nixpkgs package.

The module is maintained in
[smallstep/agent](https://github.com/smallstep/agent) as `extra/step-agent.nix`,
beside the systemd units it translates, and mirrored here on merge. Send changes
there, not to this repository.

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
