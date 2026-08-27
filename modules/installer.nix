{ pkgs, workspace, ... }:

{
  imports = [ ./tart-guest-agent.nix ];

  networking.hostName = "${workspace.vmName}-installer";
  networking.networkmanager.enable = true;
  services.openssh.enable = true;

  environment.systemPackages = [
    pkgs.git
    pkgs.neovim
  ];

  isoImage.volumeID = "VAULTDEV";
  system.stateVersion = "26.05";
}
