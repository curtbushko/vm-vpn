{ pkgs, workspace, ... }:

{
  boot.initrd.availableKernelModules = [
    "virtio_blk"
    "virtio_pci"
    "virtio_scsi"
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  time.timeZone = "America/Toronto";
  services.chrony.enable = true;
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  users.mutableUsers = false;
  users.users.vpn = {
    isNormalUser = true;
    description = "VPN Workspace";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    initialPassword = "vpn";
    shell = pkgs.zsh;
  };
  security.sudo.wheelNeedsPassword = false;

  programs.zsh.enable = true;
  programs.starship.enable = true;
  programs.starship.settings = {
    add_newline = false;
    format = "[${workspace.statusText}](bold purple) $all";
  };

  environment.systemPackages = [
    pkgs.curl
    pkgs.git
    pkgs.gnutar
    pkgs.jq
    pkgs.starship
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "26.05";
}
