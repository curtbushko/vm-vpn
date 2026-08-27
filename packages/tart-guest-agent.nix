{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation {
  pname = "tart-guest-agent";
  version = "0.14.0";

  src = fetchurl {
    url = "https://github.com/openai/tart-guest-agent/releases/download/v0.14.0/tart-guest-agent-linux-arm64.tar.gz";
    hash = "sha256-ZCSPGNss1eWqOkpeqnppWcEaEhw7f5kR0u4Vn1N//gM=";
  };

  sourceRoot = ".";
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 tart-guest-agent "$out/bin/tart-guest-agent"
    runHook postInstall
  '';

  meta = {
    description = "Guest agent for Tart virtual machines";
    homepage = "https://github.com/openai/tart-guest-agent";
    license = lib.licenses.mit;
    mainProgram = "tart-guest-agent";
    platforms = [ "aarch64-linux" ];
  };
}
