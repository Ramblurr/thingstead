{
  config,
  lib,
  pkgs,
  ...
}:
{
  networking.useDHCP = false;
  services.timesyncd.enable = true;
  services.resolved.enable = true;
  systemd.network.enable = true;
  time.timeZone = "Europe/Berlin";
  systemd.network = {
    links = {
      "10-eno1" = {
        matchConfig.MACAddress = "1c:69:7a:af:31:31";
        linkConfig.Name = "eno1";
      };
      "10-enp6s0" = {
        matchConfig.MACAddress = "00:30:93:12:14:79";
        linkConfig.Name = "enp6s0";
      };
    };
    networks = {
      "10-eno1" = {
        matchConfig.Name = "eno1";
        networkConfig.DHCP = "ipv4";
      };
      "10-enp6s0" = {
        matchConfig.Name = "enp6s0";
        #networkConfig.DHCP = "ipv4";
        linkConfig = {
          ActivationPolicy = "always-down";
          Unmanaged = true;
        };
      };

      "10-wlp0s20f3" = {
        matchConfig.Name = "wlp0s20f3";
        networkConfig.ConfigureWithoutCarrier = true;
        linkConfig = {
          ActivationPolicy = "always-down";
          Unmanaged = true;
        };
      };

      "20-tailscale-ignore" = {
        matchConfig.Name = "tailscale*";
        linkConfig = {
          RequiredForOnline = false;
          Unmanaged = true;
        };
      };
    };
  };

  services.openssh = {
    enable = true;
    authorizedKeysFiles = lib.mkForce [ "/etc/ssh/authorized_keys.d/%u" ];
    openFirewall = true;
    settings = {
      AcceptEnv = [ "SYSTEMD_PAGER" ];
      LoginGraceTime = 30;
      PermitRootLogin = lib.mkOverride 900 "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      StreamLocalBindUnlink = true;
    };
    hostKeys = [
      {
        path = "/persist/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };
}
