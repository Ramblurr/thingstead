{
  description = "dev env";
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1"; # tracks nixpkgs unstable branch
    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
    devenv.url = "https://flakehub.com/f/ramblurr/nix-devenv/*";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    clj-nix.url = "github:jlesquembre/clj-nix";
    clj-nix.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    microvm.url = "github:microvm-nix/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    impermanence.url = "github:nix-community/impermanence";
  };
  outputs =
    inputs@{
      self,
      clj-nix,
      devenv,
      devshell,
      nixpkgs,
      disko,
      impermanence,
      sops-nix,
      ...
    }:
    let
      flake = devenv.lib.mkFlake ./. {
        inherit inputs;
        withOverlays = [
          devshell.overlays.default
          devenv.overlays.default
          clj-nix.overlays.default
        ];
        devShell =
          pkgs:
          pkgs.devshell.mkShell {
            imports = [
              devenv.capsules.base
              devenv.capsules.clojure
            ];
            # https://numtide.github.io/devshell
            commands = [
              # { package = pkgs.bazqux; }
            ];
            packages = [
              pkgs.deps-lock
              # pkgs.foobar
            ];

          };
      };
    in
    flake
    // {
      nixosConfigurations.thingstead = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs self; };
        modules = [
          disko.nixosModules.disko
          impermanence.nixosModules.impermanence
          sops-nix.nixosModules.sops
          ./nix/modules/nixos/ssh-keys.nix
          ./nix/hosts/thingstead
        ];
      };
    };
}
