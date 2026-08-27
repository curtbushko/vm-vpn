{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation {
  pname = "tart";
  version = "2.36.0";

  src = fetchurl {
    url = "https://github.com/openai/tart/releases/download/2.36.0/tart.tar.gz";
    hash = "sha256-xyqKuNeKZJih5CaIsaHsbFEs5GyjWjo74TDD3hRAx+g=";
  };

  sourceRoot = ".";
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications" "$out/bin"
    cp -R tart.app "$out/Applications/Tart.app"
    ln -s "$out/Applications/Tart.app/Contents/MacOS/tart" "$out/bin/tart"
    runHook postInstall
  '';

  meta = {
    description = "Virtualization toolset for macOS on Apple Silicon";
    homepage = "https://tart.run/";
    license = lib.licenses.fairsource09;
    mainProgram = "tart";
    platforms = [ "aarch64-darwin" ];
  };
}
