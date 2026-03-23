{
  config,
  lib,
  pkgs,
  ...
}:
let
  lan0Mac = "c8:7f:54:6f:77:02";
  lan1Mac = "c8:7f:54:6f:71:3f";
  vlanDefs = {
    moot = {
      id = 12;
      mtu = 1500;
      dhcp4 = true;
    };
  };
  mkVlanNetdev =
    name: vlan:
    lib.nameValuePair "20-vlan-${name}" {
      netdevConfig = {
        Kind = "vlan";
        MTUBytes = vlan.mtu;
        Name = "vlan-${name}";
      };
      vlanConfig.Id = vlan.id;
    };
  mkMacvlanNetdev =
    name: _vlan:
    lib.nameValuePair "20-${name}" {
      netdevConfig = {
        Kind = "macvlan";
        Name = name;
      };
      macvlanConfig.Mode = "bridge";
    };
  mkVlanNetwork =
    name: _vlan:
    lib.nameValuePair "20-vlan-${name}" {
      matchConfig.Name = "vlan-${name}";
      networkConfig.LinkLocalAddressing = false;
      linkConfig.RequiredForOnline = "carrier";
      macvlan = [ name ];
    };
  mkBridgeNetwork =
    name: vlan:
    lib.nameValuePair "30-${name}" {
      matchConfig.Name = name;
      linkConfig.RequiredForOnline = "routable";
      networkConfig = {
        DHCP = if vlan.dhcp4 then "ipv4" else false;
        DHCPServer = false;
        EmitLLDP = true;
        IPv4Forwarding = true;
        IPv6AcceptRA = false;
        IPv6Forwarding = true;
        IPv6SendRA = false;
        LLDP = true;
        LinkLocalAddressing = false;
        MulticastDNS = true;
      };
      dhcpV4Config = lib.mkIf vlan.dhcp4 {
        UseDNS = true;
        UseRoutes = true;
      };
      dhcpV6Config.UseDNS = false;
    };
in
{
  networking.useDHCP = false;
  services.timesyncd.enable = true;
  services.resolved.enable = true;
  systemd.network.enable = true;
  time.timeZone = "Europe/Berlin";

  systemd.network = {
    links = {
      "10-lan0" = {
        matchConfig.MACAddress = lan0Mac;
        linkConfig.Name = "lan0";
      };
      "10-lan1" = {
        matchConfig.MACAddress = lan1Mac;
        linkConfig.Name = "lan1";
      };
    };

    netdevs = builtins.listToAttrs (
      (lib.mapAttrsToList mkVlanNetdev vlanDefs) ++ (lib.mapAttrsToList mkMacvlanNetdev vlanDefs)
    );

    networks = {
      "10-lan0" = {
        matchConfig.Name = "lan0";
        networkConfig = {
          DHCPServer = false;
          EmitLLDP = true;
          LLDP = true;
          LinkLocalAddressing = false;
          VLAN = map (name: "vlan-${name}") (builtins.attrNames vlanDefs);
        };
        linkConfig = {
          MTUBytes = 9000;
          RequiredForOnline = "carrier";
        };
      };

      "10-lan1" = {
        matchConfig.Name = "lan1";
        networkConfig.ConfigureWithoutCarrier = true;
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
    }
    // builtins.listToAttrs (
      (lib.mapAttrsToList mkVlanNetwork vlanDefs) ++ (lib.mapAttrsToList mkBridgeNetwork vlanDefs)
    );
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
