{
  description = "Declarative NixOS VPN workspace VMs on Tart";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.openaws-vpn-client = {
    url = "github:jhrldev/openaws-vpn-client";
    flake = false;
  };

  outputs =
    {
      self,
      nixpkgs,
      openaws-vpn-client,
    }:
    let
      workspaceFactory = import ./lib/mkWorkspace.nix;
      workspaces = [
        (workspaceFactory.make {
          productName = "vault";
          environmentName = "dev";
          workspace = import ./workspaces/vault/dev.nix;
        })
        (workspaceFactory.make {
          productName = "consul";
          environmentName = "lab";
          workspace = import ./workspaces/consul/lab.nix;
        })
      ];
      workspaceRegistry = workspaceFactory.registry workspaces;
      workspace = workspaceRegistry."vault/dev";
      workspaceMatrix = builtins.genList (index: {
        product = "matrix-${toString (index / 2)}";
        environment = "fixture-${toString (index - (index / 2 * 2))}";
        vmName = "matrix-${toString index}";
      }) 10;
      darwinSystem = "aarch64-darwin";
      linuxSystem = "aarch64-linux";
      darwinPkgs = import nixpkgs {
        system = darwinSystem;
        config.allowUnfreePredicate = package: nixpkgs.lib.getName package == "tart";
      };
      linuxPkgs = nixpkgs.legacyPackages.${linuxSystem};
      openawsVpnClient = linuxPkgs.callPackage ./packages/openaws-vpn-client.nix {
        src = openaws-vpn-client;
      };
      tart = darwinPkgs.callPackage ./packages/tart.nix { };
      vm = darwinPkgs.writeShellApplication {
        name = "vm";
        runtimeInputs = [
          darwinPkgs.bash
          darwinPkgs.bats
          darwinPkgs.curl
          darwinPkgs.coreutils
          darwinPkgs.gawk
          darwinPkgs.gnutar
          darwinPkgs.git
          darwinPkgs.jq
          darwinPkgs.nix
          darwinPkgs.nixfmt
          darwinPkgs.ripgrep
          darwinPkgs.shellcheck
          darwinPkgs.shfmt
          tart
        ];
        text = builtins.readFile ./scripts/vm;
      };
      makeSystem =
        resolvedWorkspace:
        nixpkgs.lib.nixosSystem {
          system = linuxSystem;
          specialArgs = {
            inherit openawsVpnClient;
            workspace = resolvedWorkspace;
          };
          modules = [ ./systems/vault-dev.nix ];
        };
      workspaceSystems = builtins.listToAttrs (
        map (resolvedWorkspace: {
          name = resolvedWorkspace.vmName;
          value = makeSystem resolvedWorkspace;
        }) workspaces
      );
      vaultDev = workspaceSystems.vault-dev;
      vaultDevInstaller = nixpkgs.lib.nixosSystem {
        system = linuxSystem;
        specialArgs = { inherit workspace; };
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix"
          ./modules/installer.nix
        ];
      };
      requiredPackages =
        let
          config = vaultDev.config;
          names = map (package: package.pname or package.name) config.environment.systemPackages;
        in
        assert config.networking.hostName == workspace.vmName;
        assert config.programs.hyprland.enable;
        assert config.programs.firefox.enable;
        assert builtins.all (name: builtins.elem name names) [
          "firefox"
          "ghostty"
          "neovim"
          "quickshell"
          "starship"
        ];
        true;
    in
    {
      inherit workspace workspaceMatrix workspaceRegistry;

      nixosConfigurations = workspaceSystems // {
        vault-dev-installer = vaultDevInstaller;
      };

      packages.${darwinSystem} = {
        inherit tart vm;
        default = vm;
      };

      packages.${linuxSystem} = {
        openaws-vpn-client = openawsVpnClient;
        tart-guest-agent =
          nixpkgs.legacyPackages.${linuxSystem}.callPackage ./packages/tart-guest-agent.nix
            { };
        vault-dev-installer = vaultDevInstaller.config.system.build.isoImage;
      };

      apps.${darwinSystem}.default = {
        type = "app";
        program = "${vm}/bin/vm";
      };

      checks.${darwinSystem} = {
        phase1-evaluation =
          assert requiredPackages;
          darwinPkgs.runCommand "phase1-evaluation" { } ''
            touch "$out"
          '';
        identity-evaluation =
          assert workspaceRegistry."vault/dev".vmName == "vault-dev";
          assert vaultDev.config.networking.hostName == workspace.vmName;
          darwinPkgs.runCommand "identity-evaluation" { } ''
            touch "$out"
          '';
      };

      formatter.${darwinSystem} = darwinPkgs.nixfmt;

      devShells.${darwinSystem}.default = darwinPkgs.mkShellNoCC {
        packages = [
          darwinPkgs.bash
          darwinPkgs.bats
          darwinPkgs.curl
          darwinPkgs.coreutils
          darwinPkgs.gawk
          darwinPkgs.gnutar
          darwinPkgs.git
          darwinPkgs.jq
          darwinPkgs.nixfmt
          darwinPkgs.nix
          darwinPkgs.openssh
          darwinPkgs.ripgrep
          darwinPkgs.shellcheck
          darwinPkgs.shfmt
          tart
          vm
        ];

        shellHook = ''
          export VM_VPN_REPO_ROOT="$PWD"
        '';
      };
    };
}
