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
      packer = darwinPkgs.packer.overrideAttrs (previousAttrs: {
        postPatch = (previousAttrs.postPatch or "") + ''
          go mod edit -require=github.com/shoenig/go-m1cpu@v0.2.2
          export GOPATH="$TMPDIR/go"
          go mod download github.com/shoenig/go-m1cpu@v0.2.2
        '';
        vendorHash = "sha256-D12C9EIQninvNZfqLeJ3+ScijZkAftqO8sFf3JG/qks=";
      });
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
          darwinPkgs.go-task
          darwinPkgs.jq
          darwinPkgs.nixfmt
          packer
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
