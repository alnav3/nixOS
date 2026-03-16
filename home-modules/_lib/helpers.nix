{lib}: rec {
  # Helper to create static file configurations
  mkStaticFiles = staticFilesList: builtins.listToAttrs staticFilesList;

  # Helper to generate JDK files
  mkJdkFiles = pkgs: jdkVersions: let
    jdks = builtins.map (version: pkgs.${version}) jdkVersions;
  in
    builtins.map (jdk: {
      name = ".jdks/${jdk.version}";
      value.source = jdk;
    }) jdks;

  # Helper to create dotfile mappings
  mkDotfile = inputs: relativePath: targetPath: {
    name = targetPath;
    value.source = ../../dotfiles/${relativePath};
  };

  # Helper to create zsh plugin files
  mkZshPlugin = pkgs: pluginName: targetPath: sharePath: {
    name = targetPath;
    value.source = "${pkgs.${pluginName}}/${sharePath}";
  };
}
