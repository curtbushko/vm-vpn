{
  description = "Declarative NixOS VPN workspace VMs on Tart";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.aws-vpn-client = {
    url = "github:ethan605/aws-vpn-client";
    flake = false;
  };

  outputs =
    {
      self,
      nixpkgs,
      aws-vpn-client,
    }:
    let
      workspaceFactory = import ./lib/mkWorkspace.nix;
      workspaces = [
        (workspaceFactory.make {
          productName = "demo";
          environmentName = "dev";
          workspace = import ./workspaces/demo/dev.nix;
        })
        (workspaceFactory.make {
          productName = "consul";
          environmentName = "lab";
          workspace = import ./workspaces/consul/lab.nix;
        })
      ];
      workspaceRegistry = workspaceFactory.registry workspaces;
      workspace = workspaceRegistry."demo/dev";
      workspaceMatrix = builtins.genList (index: {
        product = "matrix-${toString (index / 2)}";
        environment = "fixture-${toString (index - (index / 2 * 2))}";
        vmName = "matrix-${toString index}";
      }) 10;
      darwinSystem = "aarch64-darwin";
      linuxSystem = "aarch64-linux";
      darwinPkgs = import nixpkgs {
        system = darwinSystem;
        config.allowUnfreePredicate =
          package:
          builtins.elem (nixpkgs.lib.getName package) [
            "packer"
            "tart"
          ];
      };
      linuxPkgs = nixpkgs.legacyPackages.${linuxSystem};
      awsVpnClient = linuxPkgs.callPackage ./packages/aws-vpn-client.nix {
        src = aws-vpn-client;
      };
      tart = darwinPkgs.callPackage ./packages/tart.nix { };
      vm = darwinPkgs.writeShellApplication {
        name = "vm";
        runtimeInputs = [
          darwinPkgs.bash
          darwinPkgs.bats
          darwinPkgs.curl
          darwinPkgs.coreutils
          darwinPkgs.daemonize
          darwinPkgs.gawk
          darwinPkgs.gnutar
          darwinPkgs.git
          darwinPkgs.jq
          darwinPkgs.nixfmt
          darwinPkgs.openssl
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
            inherit awsVpnClient;
            workspace = resolvedWorkspace;
          };
          modules = [ ./systems/demo-dev.nix ];
        };
      workspaceSystems = builtins.listToAttrs (
        map (resolvedWorkspace: {
          name = resolvedWorkspace.vmName;
          value = makeSystem resolvedWorkspace;
        }) workspaces
      );
      demoDev = workspaceSystems.demo-dev;
      demoDevInstaller = nixpkgs.lib.nixosSystem {
        system = linuxSystem;
        specialArgs = { inherit workspace; };
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix"
          ./modules/installer.nix
        ];
      };
      requiredPackages =
        let
          config = demoDev.config;
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
        demo-dev-installer = demoDevInstaller;
      };

      packages.${darwinSystem} = {
        inherit tart vm;
        default = vm;
      };

      packages.${linuxSystem} = {
        aws-vpn-client = awsVpnClient;
        tart-guest-agent =
          nixpkgs.legacyPackages.${linuxSystem}.callPackage ./packages/tart-guest-agent.nix
            { };
        demo-dev-installer = demoDevInstaller.config.system.build.isoImage;
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
          assert workspaceRegistry."demo/dev".vmName == "demo-dev";
          assert demoDev.config.networking.hostName == workspace.vmName;
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
          darwinPkgs.daemonize
          darwinPkgs.direnv
          darwinPkgs.gawk
          darwinPkgs.gnutar
          darwinPkgs.git
          darwinPkgs.go
          darwinPkgs.jq
          darwinPkgs.nixfmt
          darwinPkgs.openssh
          darwinPkgs.openssl
          darwinPkgs.packer
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
