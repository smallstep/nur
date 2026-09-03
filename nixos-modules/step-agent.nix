# NixOS module for the Smallstep agent: services.step-agent.
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
# The option surface (enable, package, settings) deliberately matches the
# module proposed for nixpkgs in NixOS/nixpkgs#555971. Once that lands, a host
# drops the import line and keeps its services.step-agent block unchanged.
#
# swtpm is deliberately not translated. The deb/rpm packages fall back to a
# software TPM on hosts with no /dev/tpmrm0 using helper scripts installed to
# /usr/libexec/step-agent; that path is FHS-specific and the nixpkgs package
# does not ship it. NixOS therefore requires a hardware TPM 2.0, which is what
# the agent documentation states.
{ config, lib, options, pkgs, ... }:

let
  cfg = config.services.step-agent;

  settingsFormat = pkgs.formats.yaml { };
  settingsFile = settingsFormat.generate "agent.yaml" cfg.settings;

  # Whether agent.yaml is declared here or written by `step-agent register`.
  declarative = cfg.settings != { };
in
{
  options.services.step-agent = {
    enable = lib.mkEnableOption "the Smallstep agent";

    # nixpkgs packaging trails our releases by however far behind the host's
    # channel is. This option is how a host runs a newer build than its channel
    # carries: an overrideAttrs of pkgs.step-agent pointing at an edge tarball
    # on packages.smallstep.com, as shown in the agent documentation.
    package = lib.mkPackageOption pkgs "step-agent" {
      extraDescription = ''
        The default, `pkgs.step-agent`, comes from the host's nixpkgs
        channel. To run a newer or edge release, override its `version` and
        `src` with the tarball URL and the `sha256_sri` hash from the
        version's manifest under
        <https://packages.smallstep.com/edge/step-agent/linux/> -- see
        <https://smallstep.com/docs/platform/smallstep-agent/#nixos>.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = settingsFormat.type;
      };
      default = { };
      example = {
        team = "acme";
        fingerprint = "4052...0826";
      };
      description = ''
        Contents of {file}`/etc/step-agent/agent.yaml`, which holds the
        defaults for `step-agent start` flags (see `step-agent start --help`).

        `team` is the team slug (the value after `/app/` in the Smallstep
        console URL) and `fingerprint` is the SHA-256 root fingerprint of the
        team's Smallstep Agents authority. With those two set, a device that
        has been added to the team's inventory enrolls itself on first start
        with no interactive `step-agent register`; every host in a fleet gets
        the same two values, nothing in the file is per-device.

        Leave this empty to register interactively with
        `sudo step-agent register <team>` instead, which writes the file.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # The nixpkgs step-agent package is unfree. allowUnfreePackages, unlike
    # allowUnfreePredicate, is merged as list concatenation across modules, so
    # this cannot clobber (or be clobbered by) the host's own unfree
    # configuration.
    #
    # Skipped when the host passes an externally instantiated nixpkgs
    # (nixpkgs.pkgs): any nixpkgs.config definition is an eval error there,
    # and such hosts configure unfree on the instance they create.
    nixpkgs.config = lib.mkIf (!options.nixpkgs.pkgs.isDefined) {
      allowUnfreePackages = [ "step-agent" ];
    };

    environment.systemPackages = [ cfg.package ];

    # The declared config is served from the store at the same path the
    # imperative flow writes, so the daemon and the CLI (`doctor`, `reset`)
    # resolve the one file.
    #
    # The agent uses the standard systemd directories, which the unit below
    # sets: config is read from /etc/step-agent (ConfigurationDirectory=),
    # state is written under /var/lib/step-agent (StateDirectory=), and the
    # sockets live in /run/step-agent (RUNTIME_DIRECTORY). The daemon never
    # writes to the config directory. Only `step-agent register` does, which
    # is why a host with declared settings runs it with --skip-config.
    environment.etc."step-agent/agent.yaml" = lib.mkIf declarative {
      source = settingsFile;
    };

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

      # The agent starts once agent.yaml exists: declared above, or written by
      # `step-agent register`. Without it, `start` exits immediately and
      # Restart=always would loop every 10s.
      #
      # ConditionPathExists=, not ConditionPathIsReadWrite= as in the deb/rpm
      # unit: the latter tests the mount, not the file, and a config served
      # from the (read-only) Nix store would make systemd skip the unit.
      unitConfig.ConditionPathExists = "/etc/step-agent/agent.yaml";

      # A change to the declared settings is a new store path, not a new unit,
      # so tell nixos-rebuild switch to restart the agent on it.
      restartTriggers = lib.optional declarative settingsFile;

      environment = {
        HOME = "/var/lib/step-agent";
        RUNTIME_DIRECTORY = "/run/step-agent";
      };

      serviceConfig = {
        Type = "notify";
        WatchdogSec = "60s";
        # The binary path is spelled out rather than lib.getExe so that an
        # overridden package without meta.mainProgram still resolves. Every
        # build installs bin/step-agent.
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
