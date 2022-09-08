{
    description = "NixOS configuration";

    inputs = {
      nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";

      home-manager = {
        url = "github:nix-community/home-manager/release-22.05";
        inputs.nixpkgs.follows = "nixpkgs";
      };
    };

    outputs = inputs @ { nixpkgs, home-manager, ... }: {
      nixosConfigurations = {
        "nixos" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.adjacentresearch = import ./home.nix;
            }
          ];
        };
      };
    };
}