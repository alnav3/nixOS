{ lib }:

{
  defaults = import ./defaults.nix { inherit lib; };
  helpers = import ./helpers.nix { inherit lib; };
  nginx = import ./nginx-proxy.nix { inherit lib; };
}
