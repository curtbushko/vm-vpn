{ pkgs, ... }:

let
  tartGuestAgent = pkgs.callPackage ../packages/tart-guest-agent.nix { };
in
{
  environment.systemPackages = [ tartGuestAgent ];

  systemd.services.tart-guest-agent = {
    description = "Tart guest RPC agent";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      ExecStart = "${tartGuestAgent}/bin/tart-guest-agent --run-rpc";
      Restart = "always";
      RestartSec = 1;
    };
  };
}
