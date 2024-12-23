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
    grayjay
    # netflix but good
    jellyfin-media-player
    # jellyfin but without a server
    stremio
    # pdf reader
    zathura
  ];
}
