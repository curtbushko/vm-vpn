{
  openawsVpnClient,
  lib,
  pkgs,
  workspace,
  ...
}:

let
  firefoxThemeManifest = builtins.toJSON {
    manifest_version = 2;
    name = "${workspace.statusText} theme";
    version = "1.0";
    browser_specific_settings.gecko.id = "vm-vpn-theme@vm-vpn";
    theme.colors = {
      frame = "#${workspace.colors.background}";
      frame_inactive = "#${workspace.colors.inactive}";
      tab_background_text = "#${workspace.colors.foreground}";
      toolbar = "#${workspace.colors.background}";
      toolbar_text = "#${workspace.colors.foreground}";
      toolbar_field = "#${workspace.colors.inactive}";
      toolbar_field_text = "#${workspace.colors.foreground}";
      toolbar_field_border = "#${workspace.colors.accent}";
      bookmark_text = "#${workspace.colors.foreground}";
      button_background_hover = "#${workspace.colors.accent}";
      popup = "#${workspace.colors.background}";
      popup_text = "#${workspace.colors.foreground}";
      popup_border = "#${workspace.colors.accent}";
    };
  };
  firefoxTheme = pkgs.runCommand "vm-vpn-firefox-theme.xpi" { nativeBuildInputs = [ pkgs.zip ]; } ''
    mkdir theme
    cat > theme/manifest.json <<'EOF'
    ${firefoxThemeManifest}
    EOF
    zip -j "$out" theme/manifest.json
  '';
  firefoxPolicies = {
    policies = {
      DisableTelemetry = true;
      DisplayBookmarksToolbar = "always";
      Homepage = {
        StartPage = "homepage";
        URL = "file:///run/vpn-workspace/start.html";
      };
      NewTabPage = false;
      NoDefaultBookmarks = true;
      ExtensionSettings."vm-vpn-theme@vm-vpn" = {
        installation_mode = "force_installed";
        install_url = "file://${firefoxTheme}";
      };
    };
  };
in
{
  programs.firefox.enable = true;

  environment.etc."firefox/policies/policies.json".source =
    lib.mkForce "/run/vpn-workspace/firefox-policies.json";
  environment.etc."vm-vpn/firefox-policies-base.json".text = builtins.toJSON firefoxPolicies;
  environment.etc."vm-vpn/firefox-theme-manifest.json".text = firefoxThemeManifest;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  environment.systemPackages = [
    openawsVpnClient
    pkgs.firefox
    pkgs.ghostty
    pkgs.neovim
  ];

  environment.etc."xdg/ghostty/config".text = ''
    font-family = JetBrainsMono Nerd Font
    background = 181520
    foreground = FFFFFF
    palette = 5=#7C3AED
    title = ${workspace.statusText}
  '';
}
