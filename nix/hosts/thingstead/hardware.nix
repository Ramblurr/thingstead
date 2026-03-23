{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  boot = {
    zfs.devNodes = lib.mkForce "/dev/disk/by-partuuid";
    loader = {
      grub.efiSupport = lib.mkDefault true;
      grub.efiInstallAsRemovable = lib.mkDefault true;
      efi = {
        canTouchEfiVariables = true;
      };
      systemd-boot = {
        enable = true;
        configurationLimit = 20;
      };
    };
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usbhid"
        "usb_storage"
        "sd_mod"
        "sr_mod"
        "sdhci_pci"
      ];
      kernelModules = [ ];
      postDeviceCommands = lib.mkAfter ''
        zfs rollback -r rpool/encrypted/local/root@blank && \
        zfs rollback -r rpool/encrypted/vms@blank && \
        echo "rollback complete"
      '';
    };
  };
  services.zfs = {
    trim.enable = true;
    autoScrub = {
      enable = true;
      pools = [
        "zpool"
        "rpool"
      ];
    };
    autoSnapshot = {
      enable = true;
      frequent = 8; # keep the latest eight 15-minute snapshots (instead of four)
      monthly = 1; # keep only one monthly snapshot (instead of twelve)
    };
  };
  services.udev.extraRules = ''
    # Authorize Sonnet 10GbE Thunderbolt devices
    ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{vendor}=="0x8", ATTR{device}=="0x36", ATTR{authorized}="1"
  '';

  services.fwupd.enable = true;
  services.udisks2.enable = true;
  hardware.enableRedistributableFirmware = true;

  # TODO add ip address to greeting line here
  services.getty = {
    greetingLine = "\\l  -  (kernel: \\r) (label: ${config.system.nixos.label}) (arch: \\m)";
    helpLine = "";
  };
}
