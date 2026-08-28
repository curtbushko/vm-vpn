{
  openawsVpnClient,
  pkgs,
  workspace,
  ...
}:

{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "${pkgs.hyprland}/bin/start-hyprland";
        user = "vpn";
      };
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${pkgs.hyprland}/bin/start-hyprland";
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
    pkgs.fuzzel
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
    bind = SUPER, SPACE, exec, ${pkgs.fuzzel}/bin/fuzzel
    bind = SUPER, B, exec, ${pkgs.bash}/bin/bash -c 'if [[ -f /run/vpn-workspace/start.html ]]; then exec ${pkgs.firefox}/bin/firefox file:///run/vpn-workspace/start.html; else exec ${pkgs.firefox}/bin/firefox; fi'
    bind = SUPER, Q, killactive
    bind = SUPER, L, exec, ${pkgs.swaylock}/bin/swaylock --color ${workspace.colors.background}
    bind = SUPER SHIFT, E, exit

  '';

  environment.etc."xdg/fuzzel/fuzzel.ini".text = ''
    [main]
    font=JetBrainsMono Nerd Font:size=14
    prompt="Applications  "
    placeholder="Type to search installed apps"
    terminal=${pkgs.ghostty}/bin/ghostty -e
    width=48
    lines=10
    horizontal-pad=20
    vertical-pad=16
    inner-pad=8
    layer=overlay

    [colors]
    background=25212fff
    text=ffffffff
    prompt=c4b5fdff
    placeholder=9ca3afff
    input=ffffffff
    match=c4b5fdff
    selection=7c3aedff
    selection-text=ffffffff
    border=7c3aedff

    [border]
    width=2
    radius=12
  '';

  environment.etc."xdg/quickshell/${workspace.vmName}/shell.qml".text = ''
    import QtQuick
    import QtQuick.Layouts
    import Quickshell
    import Quickshell.Io
    import Quickshell.Services.SystemClock

    ShellRoot {
      id: shell
      property bool vpnReady: false

      Process {
        id: vpnCheck
        command: ["${pkgs.coreutils}/bin/test", "-f", "/run/vpn-workspace/vpn/profile.ovpn"]
        onExited: (exitCode, exitStatus) => shell.vpnReady = exitCode === 0
      }

      Process {
        id: appLauncher
        command: ["${pkgs.fuzzel}/bin/fuzzel"]
      }

      Process {
        id: firefoxLauncher
        command: ["${pkgs.bash}/bin/bash", "-lc", "if [[ -f /run/vpn-workspace/start.html ]]; then exec ${pkgs.firefox}/bin/firefox file:///run/vpn-workspace/start.html; else exec ${pkgs.firefox}/bin/firefox; fi"]
      }

      Process {
        id: terminalLauncher
        command: ["${pkgs.ghostty}/bin/ghostty"]
      }

      Process {
        id: vpnLauncher
        command: ["${openawsVpnClient}/bin/openaws-vpn-client"]
      }

      SystemClock {
        id: clock
        precision: SystemClock.Seconds
      }

      Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!vpnCheck.running) vpnCheck.running = true
      }

      PanelWindow {
        id: menuBar

        anchors {
          top: true
          left: true
          right: true
        }

        implicitHeight: 48
        color: "#25212f"

        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: 1
          color: "#3f3f46"
        }

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 16
          anchors.rightMargin: 16
          spacing: 12

          Text {
            text: "${workspace.statusText}"
            color: "#${workspace.colors.foreground}"
            font.family: "JetBrainsMono Nerd Font"
            font.bold: true
            font.pixelSize: 15
          }

          Rectangle {
            Layout.preferredWidth: 150
            Layout.preferredHeight: 32
            radius: 8
            color: appsMouse.containsMouse ? "#3f384a" : "#302a3a"
            border.color: appsMouse.activeFocus ? "#c4b5fd" : "#51475f"

            Text {
              anchors.centerIn: parent
              text: "󰀻  Applications  ⌄"
              color: "#ffffff"
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 13
              font.weight: Font.DemiBold
            }

            MouseArea {
              id: appsMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: if (!appLauncher.running) appLauncher.running = true
            }
          }

          Text {
            text: "Super+Space"
            color: "#a9a3b3"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
          }

          Item { Layout.fillWidth: true }

          Rectangle {
            Layout.preferredWidth: vpnLabel.implicitWidth + 20
            Layout.preferredHeight: 28
            radius: 14
            color: shell.vpnReady ? "#253b35" : "#39333f"

            Text {
              id: vpnLabel
              anchors.centerIn: parent
              text: shell.vpnReady ? "󰌆  VPN ready" : "󰦞  VPN stopped"
              color: shell.vpnReady ? "#86efac" : "#e5e7eb"
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 13
            }
          }

          Text {
            text: Qt.formatDateTime(clock.date, "ddd  MMM d   h:mm AP")
            color: "#ffffff"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            font.weight: Font.DemiBold
          }
        }
      }

      PanelWindow {
        id: dock

        anchors { bottom: true }
        implicitWidth: 432
        implicitHeight: 84
        exclusiveZone: 0
        color: "transparent"

        Rectangle {
          anchors.centerIn: parent
          width: 400
          height: 64
          radius: 18
          color: "#25212f"
          border.width: 1
          border.color: "#51475f"

          RowLayout {
            anchors.centerIn: parent
            spacing: 8

            Rectangle {
              Layout.preferredWidth: 110; Layout.preferredHeight: 46; radius: 12
              color: firefoxMouse.containsMouse ? "#3f384a" : "transparent"
              Text { anchors.centerIn: parent; text: "󰈹  Firefox"; color: "#ffffff"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
              MouseArea { id: firefoxMouse; anchors.fill: parent; hoverEnabled: true; onClicked: if (!firefoxLauncher.running) firefoxLauncher.running = true }
            }

            Rectangle {
              Layout.preferredWidth: 110; Layout.preferredHeight: 46; radius: 12
              color: terminalMouse.containsMouse ? "#3f384a" : "transparent"
              Text { anchors.centerIn: parent; text: "󰆍  Ghostty"; color: "#ffffff"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
              MouseArea { id: terminalMouse; anchors.fill: parent; hoverEnabled: true; onClicked: if (!terminalLauncher.running) terminalLauncher.running = true }
            }

            Rectangle {
              Layout.preferredWidth: 138; Layout.preferredHeight: 46; radius: 12
              color: vpnMouse.containsMouse ? "#3f384a" : "transparent"
              Text { anchors.centerIn: parent; text: "󰖂  Open VPN client"; color: "#ffffff"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
              MouseArea { id: vpnMouse; anchors.fill: parent; hoverEnabled: true; onClicked: if (!vpnLauncher.running) vpnLauncher.running = true }
            }
          }
        }
      }
    }
  '';
}
