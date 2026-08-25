{
  # step-agent.nix is mirrored here from smallstep/agent (extra/step-agent.nix),
  # where it lives beside the systemd units it translates. Edit it there --
  # the agent's nix-module-mirror workflow overwrites this copy on merge.
  step-agent = ./step-agent.nix;
}
