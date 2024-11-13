{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    #vlc but good
    mpv
    # music and podcast
    cmus
    castero
    # youtube but without google
    yt-dlp
    ytfzf
    # netflix but good
    jellyfin-media-player
    # pdf reader
    zathura
  ];
}
