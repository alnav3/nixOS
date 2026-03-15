#!/usr/bin/env bash
# Rebuild using local dotfiles (for testing uncommitted changes)
# NOTE: Builds locally since remote builder can't access local files
# This overrides the GitHub dotfiles input with the local submodule

nixos-rebuild switch \
  --flake '/home/alnav/nixOS#framework' \
  --target-host localhost \
  --sudo \
  --override-input dotfiles "path:./dotfiles" \
  --impure
