{ pkgs, ... }:

pkgs.writeShellScriptBin "rebuild-remote" ''
  # Custom nixos-rebuild command for remote hosts
  # Usage: rebuild-remote <hostname>
  # Example: rebuild-remote deck

  if [ -z "$1" ]; then
      echo "Usage: rebuild-remote <hostname>"
      echo "Example: rebuild-remote deck"
      exit 1
  fi

  HOST="$1"

  ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch \
      --flake "git+file:/home/alnav/nixOS?submodules=1#''${HOST}" \
      --target-host "''${HOST}" \
      --sudo \
      --build-host mjolnir \
      --impure
''
