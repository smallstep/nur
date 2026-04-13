{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.services.step-agent;
in
{
  options.services.step-agent = {
    enable = lib.mkEnableOption "Smallstep step-agent-plugin service https://github.com/smallstep/step-agent-plugin";

    # TODO: make user / group configurable
    settings = {
      config = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The configuration file to use";
      };

      kms = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The KMS uri to use";
      };

      att = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The attester KMS uri to use";
      };

      certificate = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The certificate to use for bootstrapping";
      };

      token = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The login token to use";
      };

      tokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "The path to the login token to use";
      };

      contact = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The contact email to use in the acme accounts";
      };

      cloud = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "aws"
            "gcp"
            "azure"
          ]
        );
        default = null;
        description = "Force agent to run as if cloud was detected (aws, gcp, azure)";
      };

      skipCloud = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Skip cloud detection";
      };

      team = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The team slug";
      };

      teamId = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The uuid of the team";
      };

      hostId = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The uuid of the host";
      };

      caUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The certificate authority 'url' used to get the bootstrap token";
      };

      fingerprint = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The certificate authority root fingerprint";
      };

      provisioner = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The certificate authority provisioner to use";
      };

      password = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The password of a JWK provisioner key";
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "The file containing the password of JWK provisioner key";
      };

      apiUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The url where the Smallstep API can be found";
      };

      attestationCaUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The url for the Smallstep Attestation CA";
      };

      attestationCaSlug = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The slug for the Attestation CA to use";
      };

      tpmDevice = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The name of the TPM device to use";
      };

      tpmStorageDirectory = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "The TPM storage directory path";
      };

      x5cCert = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The uri or file containing the certificate chain to use with an X5C provisioner";
      };

      x5cKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The uri or file containing the key to use with an X5C provisioner";
      };

      permanentIdentifier = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The permanent-identifier value to use";
      };

      identityToken = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "A one-time-token for accessing the CA during the agent identity signing request";
      };

      agentPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The path to the directory to write the service certificates";
      };

      pidfile = lib.mkOption {
        type = lib.types.str;
        default = "/run/step-agent/step-agent.pid";
        description = "The path to the file to read the process ID from";
      };

      ipc = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The path to the UNIX socket the IPC service binds on. May be prefixed with an '@' to denote an abstract socket";
      };

      disableReloader = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Disable endpoint reloader server";
      };

      reloader = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The path to the UNIX socket the endpoint reloader service binds on. May be prefixed with an '@' to denote an abstract socket";
      };

      register = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Register this host with the provided login token";
      };

      ipcBootstrap = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Wait for bootstrapping via IPC";
      };

      login = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use the interactive login method";
      };

      loginDomain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Specify the login domain";
      };

      pkcs11 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The path to the UNIX socket the PKCS11 server binds on";
      };

      sshAgent = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "The path to the UNIX socket the ssh-agent service binds on";
      };

      sshKey = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "The path to the SSH key";
      };

      logDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Directory path for storing agent logs";
      };

      logLevel = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "debug"
            "info"
            "warn"
            "error"
          ]
        );
        default = null;
        description = "Log level: debug, info, warn or error";
      };

      pprof = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable the pprof server for debugging";
      };
    };

    package = lib.mkPackageOption pkgs "step-agent" { };
  };

  config = lib.mkIf cfg.enable {
    users = {
      users.step-agent = {
        isSystemUser = true;
        group = "step-agent";
        home = "/var/lib/step-agent";
        createHome = false;
      };
      groups.step-agent = { };
    };

    systemd.services.step-agent = {
      after = [
        "network-online.target"
        "step-agent-swtpm.service"
      ];
      description = "Smallstep Agent";
      documentation = [
        "https://u.step.sm/docs/agent"
      ];
      requires = [
        "network-online.target"
      ];
      wantedBy = [
        "multi-user.target"
      ];
      wants = [
        "step-agent-swtpm.service"
      ];
      environment = {
        HOME = "/var/lib/step-agent";
        RUNTIME_DIRECTORY = "/run/step-agent";
      };
      unitConfig = {
        ConditionPathIsReadWrite = "/etc/step-agent/agent.yaml";
      };
      serviceConfig = {
        User = "step-agent";
        Group = "step-agent";
        ConfigurationDirectory = "step-agent";
        StateDirectory = "step-agent";
        Type = "notify";
        WatchdogSec = "60s";
        # ProtectSystem = "yes"; # what stops us from using strict
        # ProtectHome = "read-only";
        # PrivateTmp = true;
        # SecureBits = "keep-caps";
        # AmbientCapabilities = "CAP_IPC_LOCK CAP_CHOWN CAP_DAC_OVERRIDE CAP_FOWNER";
        # CapabilityBoundingSet = "CAP_SYSLOG CAP_IPC_LOCK CAP_CHOWN CAP_DAC_OVERRIDE CAP_FOWNER";
        ExecStart =
          let
            flags = lib.cli.toGNUCommandLine { } {
              config = cfg.settings.config;
              kms = cfg.settings.kms;
              att = cfg.settings.att;
              certificate = cfg.settings.certificate;
              token = cfg.settings.token;
              token-file = cfg.settings.tokenFile;
              contact = cfg.settings.contact;
              cloud = cfg.settings.cloud;
              skip-cloud = cfg.settings.skipCloud;
              team = cfg.settings.team;
              team-id = cfg.settings.teamId;
              host-id = cfg.settings.hostId;
              ca-url = cfg.settings.caUrl;
              fingerprint = cfg.settings.fingerprint;
              provisioner = cfg.settings.provisioner;
              password = cfg.settings.password;
              password-file = cfg.settings.passwordFile;
              api-url = cfg.settings.apiUrl;
              attestation-ca-url = cfg.settings.attestationCaUrl;
              attestation-ca-slug = cfg.settings.attestationCaSlug;
              tpm-device = cfg.settings.tpmDevice;
              tpm-storage-directory = cfg.settings.tpmStorageDirectory;
              x5c-cert = cfg.settings.x5cCert;
              x5c-key = cfg.settings.x5cKey;
              permanent-identifier = cfg.settings.permanentIdentifier;
              identity-token = cfg.settings.identityToken;
              agent-path = cfg.settings.agentPath;
              pidfile = cfg.settings.pidfile;
              ipc = cfg.settings.ipc;
              disable-reloader = cfg.settings.disableReloader;
              reloader = cfg.settings.reloader;
              register = cfg.settings.register;
              ipc-bootstrap = cfg.settings.ipcBootstrap;
              login = cfg.settings.login;
              login-domain = cfg.settings.loginDomain;
              pkcs11 = cfg.settings.pkcs11;
              ssh-agent = cfg.settings.sshAgent;
              ssh-key = cfg.settings.sshKey;
              log-dir = cfg.settings.logDir;
              log-level = cfg.settings.logLevel;
              pprof = cfg.settings.pprof;
            };
          in
          "${lib.getExe cfg.package} start ${lib.escapeShellArgs flags}";

        ExecReload = "/bin/kill -HUP $MAINPID";
        DeviceAllow = "/dev/tpmrm0 rw";
        # ReadWritePaths = [
        #   "-/dev/tpmrm0"
        #   "-/run/step-agent/swtpm.sock"
        #   cfg.settings.agentPath
        # ];
        LimitNOFILE = 65536;
        LimitMEMLOCK = "infinity";
        Restart = "always";
        RestartSec = 10;
      };

    };
    systemd.tmpfiles.rules = [
      "d /run/step-agent 0750 step-agent step-agent - -"
    ];
  };
}
