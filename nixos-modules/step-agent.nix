# NixOS module for the Smallstep agent.
#
# This is the NixOS translation of the units and post-install steps in this
# directory -- keep it in step with them:
#
#   step-agent.service            systemd.services.step-agent
#   step-agent-pkcs11.socket      systemd.sockets.step-agent-pkcs11
#   step-agent-restart.{path,service}
#                                 systemd.paths.step-agent-restart
#   step-agent-tmpfiles.conf      systemd.tmpfiles.rules
#   step-agent.conf (sysusers)    users.users.step-agent
#   step-agent.rules (polkit)     security.polkit.extraConfig
#   step-agent.module (p11-kit)   environment.etc."pkcs11/modules/..."
#   step-agent.postinst           tss group via security.tpm2.enable
#
# Published to https://files.smallstep.com/step-agent.nix, which customers
# download and import from configuration.nix, so it has to stay a single
# self-contained file -- it cannot read the sibling unit files at eval time.
#
# swtpm is deliberately not translated. The deb/rpm packages fall back to a
# software TPM on hosts with no /dev/tpmrm0 using helper scripts installed to
# /usr/libexec/step-agent; that path is FHS-specific and the nixpkgs package
# does not ship it. NixOS therefore requires a hardware TPM 2.0, which is what
# the agent documentation states.
{ config, lib, options, pkgs, ... }:

let
  cfg = config.services.step-agent;
in
{
  options.services.step-agent = {
    # nixpkgs packaging trails our releases -- by however far behind the
    # host's channel is -- so the daemon nixpkgs runs can be versions behind
    # the CLI a user installed from the smallstep NUR flake. This option is
    # how the two are kept in lockstep: point it at the NUR package.
    package = lib.mkPackageOption pkgs "step-agent" {
      extraDescription = ''
        The default, `pkgs.step-agent`, comes from the host's nixpkgs
        channel and trails Smallstep's releases. Set this to the package
        from the smallstep NUR flake (e.g. `smallstep.packages
        ''${pkgs.system}.step-agent`) to run the current release.
      '';
    };
  };

  config = {
    # The nixpkgs step-agent package is unfree. allowUnfreePackages, unlike
    # allowUnfreePredicate, is merged as list concatenation across modules, so
    # this cannot clobber (or be clobbered by) the host's own unfree
    # configuration. Both names are listed because nixpkgs builds the agent
    # with pname "step-agent" while the NUR derivations use
    # "step-agent-plugin".
    #
    # Skipped when the host passes an externally instantiated nixpkgs
    # (nixpkgs.pkgs): any nixpkgs.config definition is an eval error there,
    # and such hosts configure unfree on the instance they create.
    nixpkgs.config = lib.mkIf (!options.nixpkgs.pkgs.isDefined) {
      allowUnfreePackages = [ "step-agent" "step-agent-plugin" ];
    };

    environment.systemPackages = [ cfg.package ];

    # The agent talks to the TPM from user space, so it needs read/write access
    # to the TPM resource manager. This creates the tss group and the udev rules
    # that grant that group /dev/tpmrm0.
    security.tpm2.enable = true;

    users.groups.step-agent = { };
    users.users.step-agent = {
      isSystemUser = true;
      group = "step-agent";
      home = "/var/lib/step-agent";
      extraGroups = [ "tss" ];
    };

    # /run/step-agent holds the PKCS#11 and SSH sockets that other users connect
    # to. Create it with tmpfiles rather than systemd's RuntimeDirectory=, which
    # deletes the directory every time the service stops.
    systemd.tmpfiles.rules = [
      "d /run/step-agent 0755 step-agent step-agent - -"
    ];

    # Binding the PKCS#11 socket here rather than in the agent is what lets a
    # device whose only network path is EAP-TLS boot at all. NetworkManager needs
    # the endpoint's private key from this socket to authenticate, and the agent
    # needs the network to reach mission-control -- so whichever waits for the
    # other loses. systemd binds this socket before any service runs, so the
    # supplicant's first request waits in the accept queue until the agent is up
    # rather than finding nothing at the path.
    #
    # Waiting is the important part: p11-kit connects here exactly once per
    # process and never reconnects. A client that finds no socket does not retry
    # later, it stays broken until whatever process holds it is restarted.
    systemd.sockets.step-agent-pkcs11 = {
      description = "Smallstep Agent PKCS#11 socket";
      documentation = [ "https://u.step.sm/docs/agent" ];
      wantedBy = [ "sockets.target" ];

      socketConfig = {
        ListenStream = "/run/step-agent/step-agent-pkcs11.sock";
        # Must match pkcs11server.FileDescriptorName; it is how the agent
        # identifies this socket among the descriptors systemd passes it.
        FileDescriptorName = "pkcs11";
        SocketUser = "step-agent";
        SocketGroup = "step-agent";
        # Every local user's TLS client needs to reach the token, the same
        # permissions the agent applies when it binds the socket itself.
        SocketMode = "0666";
        Service = "step-agent.service";
      };
    };

    systemd.services.step-agent = {
      description = "Smallstep Agent";
      documentation = [ "https://u.step.sm/docs/agent" ];
      wantedBy = [ "multi-user.target" ];

      # Deliberately NOT ordered after network-online.target. The agent serves
      # the PKCS#11 key NetworkManager needs to bring an EAP-TLS link up, so
      # waiting for the network to be online would mean waiting for itself; it
      # boots from its cached configuration instead and reaches mission-control
      # once the link it unblocked exists.
      after = [ "step-agent-pkcs11.socket" ];
      # wants, not requires. The ordering above is what matters -- the socket
      # must be bound before the agent starts, so the agent inherits it rather
      # than binding its own -- and wants gives that without making the socket
      # load-bearing: a socket unit that cannot bind would otherwise take the
      # whole service down with it.
      wants = [ "step-agent-pkcs11.socket" ];

      # The agent starts once the device is registered and agent.yaml exists.
      unitConfig.ConditionPathIsReadWrite = "/etc/step-agent/agent.yaml";

      environment = {
        HOME = "/var/lib/step-agent";
        RUNTIME_DIRECTORY = "/run/step-agent";
      };

      serviceConfig = {
        Type = "notify";
        WatchdogSec = "60s";
        # The binary path is spelled out rather than lib.getExe: the NUR
        # derivations carry pname "step-agent-plugin" with no
        # meta.mainProgram, so getExe would resolve them to a path that does
        # not exist. Every build installs bin/step-agent.
        ExecStart = "${cfg.package}/bin/step-agent start";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        User = "step-agent";
        Group = "step-agent";
        ConfigurationDirectory = "step-agent";
        StateDirectory = "step-agent";
        Restart = "always";
        RestartSec = 10;

        ProtectSystem = true;
        ProtectHome = "read-only";
        PrivateTmp = true;
        SecureBits = "keep-caps";
        AmbientCapabilities = [ "CAP_IPC_LOCK" "CAP_CHOWN" "CAP_DAC_OVERRIDE" "CAP_FOWNER" ];
        CapabilityBoundingSet = [ "CAP_SYSLOG" "CAP_IPC_LOCK" "CAP_CHOWN" "CAP_DAC_OVERRIDE" "CAP_FOWNER" ];
        DeviceAllow = [ "/dev/tpmrm0 rw" ];
        ReadWritePaths = [ "-/dev/tpmrm0" ];

        LimitNOFILE = 65536;
        LimitMEMLOCK = "infinity";
      };
    };

    # Restart the agent when its configuration changes, such as after registering.
    systemd.paths.step-agent-restart = {
      wantedBy = [ "multi-user.target" ];
      pathConfig.PathChanged = "/etc/step-agent/agent.yaml";
    };

    systemd.services.step-agent-restart.serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.systemd.package}/bin/systemctl restart step-agent.service";
    };

    # Let the agent restart units and manage NetworkManager connections.
    security.polkit.enable = true;
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (subject.user == "step-agent") {
          if (action.id == "org.freedesktop.systemd1.manage-units") {
            return polkit.Result.YES;
          }
          if (action.id.indexOf("org.freedesktop.NetworkManager.") == 0) {
            return polkit.Result.YES;
          }
        }
      });
    '';

    # Publish the agent's PKCS#11 server to p11-kit clients. The module path has
    # to be explicit: the agent searches FHS locations that do not exist on NixOS.
    environment.etc."pkcs11/modules/step-agent.module".text = ''
      module: ${pkgs.p11-kit}/lib/pkcs11/p11-kit-client.so
      server-address: unix:path=/run/step-agent/step-agent-pkcs11.sock
    '';
  };
}
