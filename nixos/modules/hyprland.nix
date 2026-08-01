{ pkgs, ... }:
{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    # xwayland.enable = false;
  };

  security.pam.services.hyprlock = {};
  security.polkit.enable = true;
  services.dbus.enable = true;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.displayManager.defaultSession = "hyprland";

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
    ];
  };

  environment.systemPackages = with pkgs; [
    polkit_gnome
  ];
}
