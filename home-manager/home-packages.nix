{ pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    # Packages in each category are sorted alphabetically

    # Desktop apps
    imv
    mpv
    teams-for-linux
    telegram-desktop
    vesktop

    # CLI utils
    bc
    bottom
    brightnessctl
    cliphist
    ffmpeg
    ffmpegthumbnailer
    fzf
    git-graph
    grimblast
    htop
    ntfs3g
    mediainfo
    microfetch
    playerctl
    ripgrep
    showmethekey
    silicon
    udisks
    ueberzugpp
    unzip
    w3m
    wget
    wl-clipboard
    wtype
    yt-dlp
    zip

    # WM stuff
    libsForQt5.xwaylandvideobridge
    libnotify
    xdg-desktop-portal-gtk
    xdg-desktop-portal-hyprland

    # Other
    bemoji
    nix-prefetch-scripts
  ];
}
