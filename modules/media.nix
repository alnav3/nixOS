{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    grayjay
    finamp
    streamrip
    #vlc but good
    mpv
    # music and podcast
    cmus
    # comic conversion to kobo format
    kcc
    # ipod rockbox installation
    rockbox-utility
    idevicerestore
    slskd
    # youtube but without google
    yt-dlp
    ytfzf
    youtube-tui
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
