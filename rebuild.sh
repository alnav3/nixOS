#!/usr/bin/env bash
# Normal rebuild using GitHub dotfiles (requires dotfiles to be committed and pushed)

nixos-rebuild switch \
  --flake '/home/alnav/nixOS#framework' \
  --target-host localhost \
  --sudo \
  --build-host mjolnir
