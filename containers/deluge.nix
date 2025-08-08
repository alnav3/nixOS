{
  containers.deluge = {
      autoStart = true;
      privateNetwork = true;
      hostAddress = "172.69.0.1";   # Make sure this does not conflict with other containers
      localAddress = "172.69.0.21"; # Assign a unique address (e.g., .21 for Deluge)
      config = { ... }: {
          services.deluge = {
              enable = true;
              web.enable = true;          # Enable the web UI (http://172.69.0.21:8112, default password: deluge)
              # You may add additional configuration here, e.g.
              # config = {
              #   download_location = "/var/lib/deluge/downloads";
              # };
          };

          networking.firewall.allowedTCPPorts = [ 8112 58846 6881 ];
          networking.firewall.allowedUDPPorts = [ 6881 ];
          # Make sure you mark your storage location as persistent, for example:
          # environment.persistence."/var/lib/deluge" = {
          #   directory = "/home/alnav/deluge";
          # };

          # Optionally, set user/password for the web UI or other authentication.
          # services.deluge.authFile = "/path/to/auth_file";
      };
  };
}
