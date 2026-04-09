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
    package = lib.mkPackageOption pkgs "step-agent" { };

  };
  config = lib.mkIf cfg.enable {

    users = {
      users.step-agent = {
        isSystemUser = true;
        group = "step-agent";
        home = "/var/lib/step-agent";
      };
      groups.step-agent = { };
    };

    systemd.services.step-agent = {
      after = [
        "network-online.target"
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
      environment = {
        HOME = "/var/lib/step-agent";
      };
      unitConfig = {
        conditionPathIsReadWrite = "/etc/step-agent/agent.yaml";
      };
      serviceConfig = {
        User = "step-agent";
        Group = "step-agent";
        ConfigurationDirectory = "step-agent";
        RuntimeDirectory = "step-agent";
        StateDirectory = "step-agent";
        Type = "notify";
        WatchdogSec = "60s";
        ProtectSystem = "true";
        ProtectHome = "read-only";
        PrivateTmp = "true";
        SecureBits = "keep-caps";
        AmbientCapabilities = "CAP_IPC_LOCK CAP_CHOWN CAP_DAC_OVERRIDE CAP_FOWNER";
        CapabilityBoundingSet = "CAP_SYSLOG CAP_IPC_LOCK CAP_CHOWN CAP_DAC_OVERRIDE CAP_FOWNER";
        ExecStart = "${lib.getExe cfg.package} start";
        ExecReload = "/bin/kill -HUP $MAINPID";
        DeviceAllow = "/dev/tpmrm0 rw";
        ReadWritePaths = "-/dev/tpmrm0";
        LimitNOFILE = "65536";
        LimitMEMLOCK = "infinity";
        Restart = "always";
        RestartSec = "10";
      };
    };
  };
}
