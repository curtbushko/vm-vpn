{
  bash,
  buildGoModule,
  coreutils,
  fetchurl,
  gawk,
  gnused,
  lib,
  makeWrapper,
  openvpn,
  src,
  sudo,
  update-systemd-resolved,
}:

let
  openvpnPatched = openvpn.overrideAttrs (old: {
    version = "2.6.3-aws";
    src = fetchurl {
      url = "https://swupdate.openvpn.org/community/releases/openvpn-2.6.3.tar.gz";
      hash = "sha256-E7IHo3bYiAUHx0/3iqvDd4qdpHyJ8eJH3O48cjcTj/Y=";
    };
    patches = [ "${src}/patches/openvpn-v2.6.3-aws.patch" ];
    configureFlags = (old.configureFlags or [ ]) ++ [ "--disable-dco" ];
  });
in
buildGoModule {
  pname = "aws-vpn-client";
  version = "0-unstable-2023-05-03";
  inherit src;

  vendorHash = "sha256-OyvB6t/S3P5WRIH3oTYO5e/t3vsigtqO18F6ot0meMQ=";
  patchedOpenvpnVersion = "2.6.3-aws";
  patchesText = builtins.readFile "${src}/patches/openvpn-v2.6.3-aws.patch";
  connectScript = builtins.readFile ../scripts/aws-vpn-connect;

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    install -Dm755 ${../scripts/aws-vpn-connect} "$out/bin/aws-vpn-connect"
    substituteInPlace "$out/bin/aws-vpn-connect" \
      --replace-fail '@awsVpnClient@' "$out" \
      --replace-fail '@openvpnPatched@' "${openvpnPatched}" \
      --replace-fail '@sudo@' "${sudo}" \
      --replace-fail '@updateSystemdResolved@' "${update-systemd-resolved}"
    wrapProgram "$out/bin/aws-vpn-connect" \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          coreutils
          gawk
          gnused
        ]
      }
  '';

  passthru = { inherit openvpnPatched; };

  meta = {
    description = "AWS Client VPN SAML authentication helper with patched OpenVPN";
    homepage = "https://github.com/ethan605/aws-vpn-client";
    license = lib.licenses.mit;
    mainProgram = "aws-vpn-connect";
    platforms = lib.platforms.linux;
  };
}
