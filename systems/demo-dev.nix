{ modulesPath, workspace, ... }:

{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    ../modules/base.nix
    ../modules/desktop.nix
    ../modules/applications.nix
    ../modules/identity.nix
    ../modules/tart-guest-agent.nix
  ];

  networking.hostName = workspace.vmName;

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };
}
