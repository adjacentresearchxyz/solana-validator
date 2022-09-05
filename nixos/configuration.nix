{ config, pkgs, lib, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./services/services.nix
      (fetchTarball {
	       url = "https://github.com/msteen/nixos-vscode-server/tarball/master";
         sha256 = "00ki5z2svrih9j9ipl8dm3dl6hi9wgibydsfa7rz2mdw9p0370yl";
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

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

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
