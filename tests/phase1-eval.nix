let
  flake = builtins.getFlake (toString ./..);
  workspace = flake.workspace;
  system = flake.nixosConfigurations.vault-dev.config;
  installer = flake.nixosConfigurations.vault-dev-installer.config;
  hyprlandConfig = system.environment.etc."xdg/hypr/hyprland.conf".text;
  packageNames = map (package: package.pname or package.name) system.environment.systemPackages;
  shellPackageNames = map (
    package: package.pname or package.name
  ) flake.devShells.aarch64-darwin.default.nativeBuildInputs;
in
assert workspace.product == "vault";
assert workspace.environment == "dev";
assert workspace.vmName == "vault-dev";
assert workspace.vmPath == "vault/dev";
assert system.networking.hostName == "vault-dev";
assert system.programs.hyprland.enable;
assert builtins.length (builtins.split "bordercolor" hyprlandConfig) == 1;
assert builtins.hasAttr "tart-guest-agent" system.systemd.services;
assert builtins.hasAttr "tart-guest-agent" installer.systemd.services;
assert system.programs.firefox.enable;
assert builtins.elem "firefox" packageNames;
assert builtins.elem "ghostty" packageNames;
assert builtins.elem "neovim" packageNames;
assert builtins.elem "starship" packageNames;
assert builtins.elem "quickshell" packageNames;
assert builtins.elem "openaws-vpn-client" packageNames;
assert
  flake.packages.aarch64-linux.openaws-vpn-client == builtins.head (
    builtins.filter (
      package: (package.pname or "") == "openaws-vpn-client"
    ) system.environment.systemPackages
  );
assert builtins.elem "curl" shellPackageNames;
assert builtins.elem "openssh" shellPackageNames;
assert builtins.elem "tart" shellPackageNames;
true
