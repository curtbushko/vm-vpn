{
  description = "Minimal macOS VPN workspace image for Tart";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      darwinSystem = "aarch64-darwin";
      darwinPkgs = import nixpkgs {
        system = darwinSystem;
        config.allowUnfreePredicate =
          package:
          builtins.elem (nixpkgs.lib.getName package) [
            "packer"
            "tart"
          ];
      };
      tart = darwinPkgs.callPackage ./packages/tart.nix { };
    in
    {
      packages.${darwinSystem} = {
        inherit tart;
        default = tart;
      };

      formatter.${darwinSystem} = darwinPkgs.nixfmt;

      devShells.${darwinSystem}.default = darwinPkgs.mkShellNoCC {
        packages = [
          darwinPkgs.bash
          darwinPkgs.bats
          darwinPkgs.coreutils
          darwinPkgs.curl
          darwinPkgs.direnv
          darwinPkgs.git
          darwinPkgs.jq
          darwinPkgs.nixfmt
          darwinPkgs.openssh
          darwinPkgs.packer
          darwinPkgs.ripgrep
          darwinPkgs.shellcheck
          darwinPkgs.shfmt
          darwinPkgs.sshpass
          tart
        ];

        shellHook = ''
          export VM_VPN_REPO_ROOT="$PWD"
        '';
      };
    };
}
