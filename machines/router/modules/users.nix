{ config, lib, ... }:

let
  # ---------------------------------------------------------------------------
  # Shared SSH public key
  # ---------------------------------------------------------------------------
  # All router accounts use the same key for now.
  # Replace per-user once dedicated keys are generated.
  sharedSshKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCiP2WKxf0TUiFAlb/rg/dpimYTpzMntD7UmUYQxxiVUt6OCg34iKgDHHiC+nK2nRMuy1viT84dR0qUiG9J+vLTVJ1nuBgg1HI5w/RJ3f7oKSmV2rSnK0jetGU8yeJ8H/9MmwYGQ6Oc2896q0IukojFc7ULRKr1/fMOFTNL9v++IwpuTL05D1OkVbpcB1rKM5vSjYEWen+1SBuQWW91BepyLwiX4CrLttaJyZIHUVYgtcUbAIcduduA4lkCrFHud4N93R1QqIXqf4WYew5OoxNjhXhLq6yJ9w+MvbmeCzqEgSkwSj9jFb97Se4FCHeeiV20Y6mM7/yeTC73i77w3DpnDPO0iYtNtcbZ1EmKOF2N7LXwW5jqZT8e/w4TbRFYJ+zfe0zWRO/27H3DSNPcb8LcEpYFNFQ+plgRRO9fBwLRhgHSVolU6JudOoe6g+TCUaR4CMV+xF/Ir6A6P5vwPR6Y1cTjufXrx/SdsfPNk5q1YK6qRxPxPt3tCNVGdO68psfDwpXxYxwUiPtytEvgenr1aXbauA4QqM1qMTOLa14Q/je5D5regg497RFXVjgLeQf3bDrhsSlaaHuARme9OkcKr8vyzIyPGIvmxvl6zlQBrBGHHKey1gMtB4QH/xeA8dLofD83p/Yl174omx+2L5XiP0QqfHu4T/cC0j1baGL2BQ== alnav@nixos";
in
{
  # ===========================================================================
  # Router User & Security Configuration
  # ===========================================================================
  #
  # Account model:
  #
  #   alnav       — legacy owner account (transition period).
  #                 Password locked; SSH + sudo kept until fully migrated.
  #
  #   router      — day-to-day maintenance (future alnav replacement).
  #                 No root. Limited sudo for VPN bypass, containers, dnsmasq.
  #                 Access to DHCP lease files via router-mgmt group.
  #
  #   new-alnav   — remote nixos-rebuild only.
  #                 Minimal sudo: nix-env (profile) + switch-to-configuration.
  #                 Trusted nix user for store copy over SSH.
  #
  # Secret access:
  #   All SOPS secrets are 0400 root:root. No interactive user can read them
  #   without full root, and no account here has unrestricted sudo.
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # alnav — lock console password, retain SSH + sudo (transition)
  # ---------------------------------------------------------------------------
  # base.nix still configures the SSH key, extraGroups, and sudo for alnav.
  # We only override the password here to prevent local console login.
  users.users.alnav.hashedPassword = lib.mkForce "!";

  # ---------------------------------------------------------------------------
  # router — maintenance user
  # ---------------------------------------------------------------------------
  users.users.router = {
    isNormalUser = true;
    uid          = 1001;
    description  = "Router day-to-day maintenance";
    extraGroups  = [
      "systemd-journal"  # Read logs (journalctl) without sudo
      "router-mgmt"      # Read/write DHCP lease files
    ];
    hashedPassword             = "!";    # No local login ever
    openssh.authorizedKeys.keys = [ sharedSshKey ];
  };

  # ---------------------------------------------------------------------------
  # new-alnav — remote nixos-rebuild deployment account
  # ---------------------------------------------------------------------------
  users.users.new-alnav = {
    isNormalUser = true;
    uid          = 1002;
    description  = "NixOS remote rebuild deployment";
    extraGroups  = [];                   # No extra groups needed
    hashedPassword             = "!";    # SSH-key only, no console login
    openssh.authorizedKeys.keys = [ sharedSshKey ];
  };

  # ---------------------------------------------------------------------------
  # router-mgmt group — DHCP file access
  # ---------------------------------------------------------------------------
  users.groups.router-mgmt = { };

  # ---------------------------------------------------------------------------
  # Nix daemon — trust new-alnav for remote store operations
  # ---------------------------------------------------------------------------
  # nixos-rebuild uses `nix copy --to ssh-ng://new-alnav@router` to upload
  # the built store paths. The nix daemon must trust this user to accept them.
  nix.settings.trusted-users = [ "new-alnav" ];

  # ---------------------------------------------------------------------------
  # Sudo rules
  # ---------------------------------------------------------------------------
  security.sudo.extraRules = [

    # -------------------------------------------------------------------------
    # new-alnav: ONLY the activation commands needed for rootless rebuilds.
    #
    # Since we use --rootless mode (build + manual activate), we don't need
    # nixos-rebuild or nix-env sudo rules. Both `activate` and
    # `switch-to-configuration switch` are sufficient.
    #
    # Usage (from build machine):
    #   rebuild-remote --rootless --user new-alnav router
    #
    # Or manually:
    #   nixos-rebuild build --target-host new-alnav@router ...
    #   ssh new-alnav@router "sudo /nix/store/.../activate"
    # -------------------------------------------------------------------------
    {
      users    = [ "new-alnav" ];
      commands = [
        {
          # activate — the activation script generated at build time.
          # Allows manual activation after a `nixos-rebuild build`.
          command = "/nix/store/*/activate";
          options = [ "NOPASSWD" ];
        }
        {
          # switch-to-configuration — alternative to activate.
          # Both do the same thing, kept for compatibility.
          command = "/nix/store/*/bin/switch-to-configuration";
          options = [ "NOPASSWD" ];
        }
      ];
    }

    # -------------------------------------------------------------------------
    # router: scoped maintenance operations, no general root access
    # -------------------------------------------------------------------------
    {
      users    = [ "router" ];
      commands = [

        # VPN bypass — needs nft + ip-rule (root capabilities)
        # Script lives in /run/current-system/sw/bin/; sudo resolves the
        # symlink to the nix store path at runtime for the match check.
        {
          command = "/run/current-system/sw/bin/vpn-bypass";
          options = [ "NOPASSWD" ];
        }

        # NixOS container lifecycle
        # Using the stable /run/current-system/sw/bin symlink so the rules
        # survive systemd version upgrades without path-hash mismatches.
        {
          command = "/run/current-system/sw/bin/systemctl start container@*";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl stop container@*";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl restart container@*";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl status container@*";
          options = [ "NOPASSWD" ];
        }

        # WireGuard VPN toggle
        {
          command = "/run/current-system/sw/bin/systemctl start wg-quick-wg0.service";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl stop wg-quick-wg0.service";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl restart wg-quick-wg0.service";
          options = [ "NOPASSWD" ];
        }

        # dnsmasq reload/restart — needed after editing static-leases.conf
        {
          command = "/run/current-system/sw/bin/systemctl reload dnsmasq.service";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl restart dnsmasq.service";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # ---------------------------------------------------------------------------
  # DHCP file permissions — router user (via router-mgmt group) can manage
  # ---------------------------------------------------------------------------
  # dns-dhcp.nix creates these files with `f` rules (root:root 0644).
  # We use `z` to adjust ownership/mode without recreating the files.
  # dnsmasq reads static-leases.conf (world-readable OK), writes dnsmasq.leases.
  systemd.tmpfiles.rules = [
    # The directory itself: root owns it, router-mgmt can traverse
    "z /var/lib/dnsmasq 0755 root root -"
    # Static leases config: router user can read/write; dnsmasq reads (world r)
    "z /var/lib/dnsmasq/static-leases.conf 0664 root router-mgmt -"
    # Active leases: dnsmasq owns and writes; router user reads (world r)
    "z /var/lib/dnsmasq/dnsmasq.leases 0644 dnsmasq dnsmasq -"
  ];

  # ---------------------------------------------------------------------------
  # SOPS secrets — explicit root-only access (no user can read)
  # ---------------------------------------------------------------------------
  # sops-nix defaults are already owner=root mode=0400, but we make it
  # explicit here so any future change to a secret definition cannot
  # accidentally widen permissions.
  #
  # Note: pap-secrets already sets mode=0600 in wan.nix — that is fine.
  # Services consuming these (duckdns, cloudflare-ddns, wg-quick, pppd) all
  # run as root, so 0400 root:root is sufficient for them.
  sops.secrets."duckdns.env".mode    = lib.mkForce "0400";
  sops.secrets."cloudflare.env".mode = lib.mkForce "0400";
  sops.secrets."vpn.conf".mode       = lib.mkForce "0400";
}
