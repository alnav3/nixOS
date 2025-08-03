{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    grayjay
    finamp
    streamrip
    #vlc but good
    mpv
    # music and podcast
    cmus
    # youtube but without google
    yt-dlp
    ytfzf
    # netflix but good
    jellyfin-media-player
    # jellyfin but without a server
    stremio
    # pdf reader
    zathura
  ];
}
