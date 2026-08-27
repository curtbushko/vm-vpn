let
  flake = builtins.getFlake (toString ./..);
  identity = import ../lib/identity.nix;
  mkWorkspace = import ../lib/mkWorkspace.nix;
  resolved = flake.workspaceRegistry."vault/dev";
  second = flake.workspaceRegistry."consul/lab";
  invalid = builtins.tryEval (
    identity.resolve {
      productName = "Vault!";
      environmentName = "dev";
      product = import ../products/vault.nix;
      environment = import ../environments/dev.nix;
      workspace = import ../workspaces/vault/dev.nix;
    }
  );
  missing = builtins.tryEval (
    identity.resolve {
      productName = "missing";
      environmentName = "dev";
      product = null;
      environment = import ../environments/dev.nix;
      workspace = { };
    }
  );
  duplicate = builtins.tryEval (
    mkWorkspace.registry [
      resolved
      resolved
    ]
  );
  system = flake.nixosConfigurations.${resolved.vmName}.config;
in
assert resolved.product == "vault";
assert resolved.environment == "dev";
assert resolved.vmName == "vault-dev";
assert resolved.vmPath == "vault/dev";
assert resolved.displayName == "Vault - Development";
assert resolved.productIcon != "";
assert resolved.environmentIcon != "";
assert second.vmName == "consul-lab";
assert second.vmPath == "consul/lab";
assert second.colors != resolved.colors;
assert builtins.length flake.workspaceMatrix == 10;
assert invalid.success == false;
assert missing.success == false;
assert duplicate.success == false;
assert system.networking.hostName == resolved.vmName;
assert builtins.hasAttr "vm-vpn/wallpaper.svg" system.environment.etc;
assert
  builtins.match ".*${resolved.statusText}.*"
    system.environment.etc."xdg/quickshell/${resolved.vmName}/shell.qml".text != null;
true
