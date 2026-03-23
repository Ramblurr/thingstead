{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  system.stateVersion = "26.11";
  networking.hostName = "thingstead";
  environment.etc."machine-id".text = "6ad3e769a91e42ca80064f510b6762e0";
  networking.hostId = "350d17ed";
  imports = [
    ./disk-config.nix
    ./hardware.nix
    ./networking.nix
  ];

  documentation.nixos.enable = true;
  documentation.doc.enable = true;
  sops.age.sshKeyPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
  sops.defaultSopsFile = ./secrets.sops.yaml;
  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/etc/nixos"
      "/var/log"
      "/var/lib/cups"
    ];
    files = [ ];
  };
  environment.interactiveShellInit = ''
    # raise some awareness towards failed services
    systemctl --no-pager --failed || true
  '';
  environment.systemPackages =
    with pkgs;
    [
      bandwhich
      curl
      dig
      fd
      git
      htop
      isd
      jq
      killall
      lshw
      lsof
      ncdu
      python3
      rclone
      ripgrep
      smartmontools
      sops
      tcpdump
      unzip
      vifm
      vim
      wget
      yq-go
    ]
    ++ (map (x: x.terminfo) (
      with pkgs.pkgsBuildBuild;
      [
        ghostty
        kitty
        tmux
        wezterm
      ]
    ));

  sops.secrets.root-password.neededForUsers = true;
  users.users.root = {
    password = "root";
    #hashedPasswordFile = config.sops.secrets.root-password.path;
    shell = pkgs.zsh;
  };
  sops.secrets.ramblurr-password.neededForUsers = true;
  users.groups.ramblurr = { };
  users.users.ramblurr = {
    hashedPasswordFile = config.sops.secrets.ramblurr-password.path;
    group = "ramblurr";
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };
  programs.zsh.enable = true;
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;
  nix = {
    extraOptions = ''
      # Quicker timeout for inaccessible binary caches
      connect-timeout = 5
      # Enable flakes
      experimental-features = nix-command flakes
      # Do not warn on dirty git repo
      warn-dirty = false
    '';
    settings = {
      substituters = [ ];
      trusted-public-keys = [ ];
      trusted-users = [
        "root"
        "@wheel"
      ];
      auto-optimise-store = true;
    };

    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };

    registry.nixpkgs.flake = inputs.nixpkgs;

    nixPath = [ "nixpkgs=/etc/nixpkgs/channels/nixpkgs" ];
  };
  systemd.tmpfiles.rules = [ "L+ /etc/nixpkgs/channels/nixpkgs - - - - ${inputs.nixpkgs}" ];
  system = {
    # Enable printing changes on nix build etc with nvd
    activationScripts.report-changes = ''
      PATH=$PATH:${
        lib.makeBinPath [
          pkgs.nvd
          pkgs.nix
        ]
      }
      nvd diff $(ls -dv /nix/var/nix/profiles/system-*-link | tail -2) || true
    '';
  };

  systemd.services.nix-cleanup-gcroots = {
    description = "Clean up stale Nix GC roots";
    serviceConfig.Type = "oneshot";
    script = ''
      set -eu
      # delete automatic gcroots older than 90 days
      ${pkgs.findutils}/bin/find /nix/var/nix/gcroots/auto /nix/var/nix/gcroots/per-user -type l -mtime +90 -delete || true
      # created by nix-collect-garbage, might be stale
      ${pkgs.findutils}/bin/find /nix/var/nix/temproots -type f -mtime +10 -delete || true
      # delete broken symlinks
      ${pkgs.findutils}/bin/find /nix/var/nix/gcroots -xtype l -delete || true
    '';
  };

  systemd.timers.nix-cleanup-gcroots = {
    description = "Weekly timer for nix-cleanup-gcroots";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun *-*-* 03:30:00";
      Persistent = true;
    };
  };
}
