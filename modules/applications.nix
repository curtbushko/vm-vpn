{
  openawsVpnClient,
  pkgs,
  workspace,
  ...
}:

{
  programs.firefox = {
    enable = true;
    policies = {
      DisableTelemetry = true;
      Homepage = {
        StartPage = "homepage";
        URL = "file:///etc/vm-vpn/start.html";
      };
      NewTabPage = false;
    };
  };

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
