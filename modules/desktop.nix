{ pkgs, workspace, ... }:

{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "${pkgs.hyprland}/bin/Hyprland";
        user = "vpn";
      };
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${pkgs.hyprland}/bin/Hyprland";
        user = "greeter";
      };
    };
  };

  hardware.graphics.enable = true;
  services.spice-vdagentd.enable = true;
  security.polkit.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";
  };

  environment.systemPackages = [
    pkgs.hyprland
    pkgs.polkit_gnome
    pkgs.quickshell
    pkgs.swaylock
    pkgs.swaybg
    pkgs.xdg-utils
  ];

  environment.etc."xdg/hypr/hyprland.conf".text = ''
    monitor = ,preferred,auto,1

    exec-once = ${pkgs.swaybg}/bin/swaybg --image /etc/vm-vpn/wallpaper.svg --mode fill
    exec-once = ${pkgs.quickshell}/bin/qs --path /etc/xdg/quickshell/${workspace.vmName}
    exec-once = ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1

    input {
      kb_layout = us
      follow_mouse = 1
    }

    general {
      border_size = 3
      col.active_border = rgb(${workspace.colors.accent})
      col.inactive_border = rgb(${workspace.colors.inactive})
    }

    decoration {
      rounding = 8
    }

    misc {
      disable_hyprland_logo = true
      disable_splash_rendering = true
      background_color = rgb(${workspace.colors.background})
    }

    bind = SUPER, RETURN, exec, ${pkgs.ghostty}/bin/ghostty
    bind = SUPER, B, exec, ${pkgs.firefox}/bin/firefox
    bind = SUPER, Q, killactive
    bind = SUPER, L, exec, ${pkgs.swaylock}/bin/swaylock --color ${workspace.colors.background}
    bind = SUPER SHIFT, E, exit

  '';

  environment.etc."xdg/quickshell/${workspace.vmName}/shell.qml".text = ''
    import QtQuick
    import QtQuick.Layouts
    import Quickshell

    PanelWindow {
      anchors {
        top: true
        left: true
        right: true
      }

      implicitHeight: 40
      color: "#${workspace.colors.background}"

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16

        Text {
          text: "${workspace.statusText}"
          color: "#${workspace.colors.foreground}"
          font.family: "JetBrainsMono Nerd Font"
          font.bold: true
          font.pixelSize: 16
        }

        Item { Layout.fillWidth: true }

        Text {
          text: "${workspace.vmName}"
          color: "#${workspace.colors.accentText}"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 14
        }
      }
    }
  '';
}
