{
  fetchpatch,
  fetchurl,
  glib,
  gtk3,
  lib,
  makeWrapper,
  openvpn,
  pkg-config,
  rustPlatform,
  src,
  wrapGAppsHook3,
  xdg-utils,
}:

let
  openvpnPatched = openvpn.overrideAttrs (_: {
    version = "2.5.1-aws";
    src = fetchurl {
      url = "https://swupdate.openvpn.org/community/releases/openvpn-2.5.1.tar.gz";
      hash = "sha256-6VgrjpRXmUvY1QASvoLCOy9GXaUUYMmyNgqB2g9OBuY=";
    };
    patches = [
      (fetchpatch {
        url = "https://raw.githubusercontent.com/samm-git/aws-vpn-client/master/openvpn-v2.5.1-aws.patch";
        hash = "sha256-9ijhANqqWXVPa00RBCRACtMIsjiBqYVa91V62L4mNas=";
      })
    ];
  });
in
rustPlatform.buildRustPackage {
  pname = "openaws-vpn-client";
  version = "0.1.8-unstable-2025-03-19";
  inherit src;

  cargoHash = "sha256-RAUMf4c8zKZvRv+1j00fw7xxU+ZVoN8/IAxTzpGJRqc=";

  nativeBuildInputs = [
    makeWrapper
    pkg-config
    wrapGAppsHook3
  ];

  buildInputs = [
    glib
    gtk3
  ];

  postPatch = ''
    substituteInPlace src/config.rs \
      --replace-fail '        println!("Saved at {:?}", &file_dir);' "" \
      --replace-fail '        println!("Remote {:?}", &remote);' ""
    substituteInPlace src/main.rs \
      --replace-fail '.application_id("com.github.JonathanxD.OpenAwsVpnClient")' '.application_id("com.github.JonathanxD.OpenAwsVpnClient").flags(gtk::gio::ApplicationFlags::NON_UNIQUE)' \
      --replace-fail '        app.connect_activate(move |app| {' '        app.connect_activate(move |app| { if win_container.win.lock().unwrap().is_some() { return; }' \
      --replace-fail '.default_width(320)' '.default_width(720)' \
      --replace-fail '.default_height(260)' '.default_height(520)' \
      --replace-fail '        app.run();' '        app.register(None::<&gtk::gio::Cancellable>).unwrap(); app.activate(); app.run();'
  '';

  postInstall = ''
    cp -r share "$out/share"
    wrapProgram "$out/bin/openaws-vpn-client" \
      --set-default OPENVPN_FILE "${openvpnPatched}/bin/openvpn" \
      --set-default SHARED_DIR "$out/share" \
      --set-default XDG_CONFIG_HOME "/run/vpn-workspace/config" \
      --set-default XDG_DATA_HOME "/run/vpn-workspace/data" \
      --set-default GTK_CSD "1"
  '';

  propagatedUserEnvPkgs = [ xdg-utils ];

  meta = {
    description = "Unofficial open-source AWS Client VPN client";
    homepage = "https://github.com/jhrldev/openaws-vpn-client";
    license = lib.licenses.mit;
    mainProgram = "openaws-vpn-client";
    platforms = lib.platforms.linux;
  };
}
