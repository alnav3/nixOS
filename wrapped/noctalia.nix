{ pkgs, inputs }:
inputs.wrapper-modules.wrappers.noctalia-shell.wrap {
  inherit pkgs;
  settings =
    (builtins.fromJSON
      (builtins.readFile ../dotfiles/noctalia/noctalia.json)).settings;
}
