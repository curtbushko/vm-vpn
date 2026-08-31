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
        postConfigure = (previousAttrs.postConfigure or "") + ''
          substituteInPlace vendor/github.com/shoenig/go-m1cpu/cpu.go \
            --replace-fail \
            '// UInt64 getFrequency(CFTypeRef typeRef) {' \
            $'// UInt64 getFrequency(CFTypeRef typeRef) {\n// if (typeRef == NULL) {\n// return 0;\n// }'
        '';
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
