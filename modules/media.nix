{
  pkgs,
  pkgs-stable,
  ...
}: {
  #users.users.mpd.extraGroups = [ "audio" ];
  #services.mpd = {
  #  enable = true;
  #  musicDirectory = "/home/alnav/Music";
  #  extraConfig = ''
  #      audio_output {
  #          type "pipewire"
  #              name "My PipeWire Output"
  #      }
  #  '';

  #};
  environment.systemPackages = with pkgs;
    [
      mpv
      cmus
      castero
      yt-dlp
      ytfzf
    ]
    ++
    [
      pkgs-stable.ledger-live-desktop
      pkgs-stable.ytermusic
    ];
}
