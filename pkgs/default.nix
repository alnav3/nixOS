pkgs: {
  fortivpn-webview = pkgs.callPackage ./openfortivpn-webview{};
  rebuild-remote = pkgs.callPackage ./rebuild-remote.nix {};
  deploy-all = pkgs.callPackage ./deploy-all.nix {};
  deploy-config-setup = pkgs.callPackage ./deploy-config-setup.nix {};
}
