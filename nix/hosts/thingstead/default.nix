{
  config,
  lib,
  pkgs,
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
      fd
      htop
      isd
      jq
      lshw
      ncdu
      python3
      rclone
      ripgrep
      smartmontools
      tcpdump
      vifm
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
  };
  programs.zsh.enable = true;
}
