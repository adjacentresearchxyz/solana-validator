{ config, pkgs, lib, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./services/services.nix
      (fetchTarball {
	       url = "https://github.com/msteen/nixos-vscode-server/tarball/master";
         sha256 = "1qga1cmpavyw90xap5kfz8i6yz85b0blkkwvl00sbaxqcgib2rvv";
      })
    ];

  # enable vscode-server for remote development
  services.vscode-server.enable = true;

  boot.loader = {
    grub = {
      enable = true;
      device = "nodev";  # or "nodev" for efi only
      # efiSupport = true;
      configurationLimit = 20;
    };
    efi = {
      canTouchEfiVariables = true;
      # efiSysMountPoint = "/boot/efi";
    };
  };

  # systcl tuning from https://docs.solana.com/running-validator/validator-start#optimize-sysctl-knobs
  boot.kernel.sysctl = {
     "net.core.rmem_default" = "134217728";
     "net.core.rmem_max" = "134217728";
     "net.core.wmem_default" = "134217728";
     "net.core.wmem_max" = "134217728";
     "vm.max_map_count" = "1000000";
     "fs.nr_open" = "1000000";
  };

  networking.hostName = "solana-validator";
  networking.networkmanager.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 8899 8900 8000 ];
    allowedUDPPortRanges = [
      { from = 8000; to = 10000; }
    ];
  };

  time.timeZone = "America/New_York";

  # Select internationalization properties.
  i18n.defaultLocale = "en_US.utf8";
  i18n.extraLocaleSettings.LC_TIME = "en_DK.UTF-8"; # ISO-8601 time

  users.users.adjacentresearch = {
    isNormalUser = true;
    shell = pkgs.bash;
    extraGroups = [ "networkmanager" "wheel" ];
  };

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
    '';
    settings.auto-optimise-store = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    # autoUpgrade = {
    #   enable = true;
    #   flake = "~/nixos";
    #   flags = [ "--update-input" "nixpkgs" "--commit-lock-file" ];
    # };
  };

  fonts = {
    enableDefaultFonts = true;
    fonts = with pkgs; [
      nerdfonts # (nerdfonts.override { fonts = [ "Iosevka" "Meslo" ]; })
    ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # programming
    docker
    docker-compose

    # tools
    wget
    btop
    htop
    ripgrep
    exa
    bat
    fd
    git
    vim
    ncdu

    # system tools and monitoring   
    fail2ban
    promtail
    prometheus-alertmanager
  ];

  environment.sessionVariables = {
    XDG_CONFIG_HOME = "$HOME/.config";
    NIXOS_OZONE_WL = "1";
  };

  security.sudo = {
    package = pkgs.sudo.override {
      withInsults = true;
    };
    extraConfig = "Defaults insults";
  };

  system.stateVersion = "22.05";
}   
