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
    # media control
    playerctl
    ## netflix but good
    #jellyfin-media-player
    ## jellyfin but without a server
    #stremio
    # pdf reader
    zathura
  ];
}
