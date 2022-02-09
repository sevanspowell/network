# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.copyKernels = true;
  boot.loader.grub.fsIdentifier = "label";
  boot.loader.grub.extraConfig = "serial; terminal_input serial; terminal_output serial";
  boot.kernelParams = [ "console=ttyS0" ];

  networking.useDHCP = false;

  networking.interfaces.eth0.useDHCP = true;
  networking.usePredictableInterfaceNames = false;

  # networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;


  

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users.jane = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  # };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    git
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    passwordAuthentication = false;
  };

  users.users."root".openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJzHCI1ZW7gnF7l7d/qIiow4kViRwp0pvybZVjlBZBrW cardno:000610630425"
  ];

  networking.nat = {
    enable = true;
    externalInterface = "eth0";
    internalInterfaces = [ "wg0" ];
  };

  networking.firewall = {
    enable = true;
    interfaces.eth0.allowedTCPPorts = [ 22 80 443 53 ];
    interfaces.eth0.allowedUDPPorts = [ 51820 32768 60999 53 ];

    interfaces.wg0.allowedTCPPorts = [ 80 53 2200 8384 ];
    interfaces.wg0.allowedUDPPorts = [ 80 53 21027 8384 ];
  };

  networking.wireguard.interfaces = {
    wg0 = {
      ips = [ "10.100.0.1/24" ];
   
      listenPort = 51820;

      generatePrivateKeyFile = true;
      privateKeyFile = "/etc/wireguard/wg0"; 

      peers = [
        {
          publicKey = "jCC29+Wpanv5kfx7sJqVnzOP5ToWc7FBgO1bJYcJqDY=";
          allowedIPs = [ "10.100.0.2/32" ];
        }
      ];
    };
  };

  services.coredns.enable = true;
  services.coredns.config =
    ''
      . {
        # Cloudflare and Google
        forward . 1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4
        cache
      }

      server.home {
        template IN A {
          answer "{{ .Name }} 0 IN A 10.100.0.1"
        }
      }

      orchid.home {
        template IN A {
          answer "{{ .Name }} 0 IN A 10.100.0.2"
        }
      }
    '';

  users.users.nginx.extraGroups = [ "acme" ];
  services.nginx.enable = true;
  services.nginx.virtualHosts."_" = {
    default = true;
    forceSSL = true;
    useACMEHost = "samandgeorgia.com";
    locations."/custom_404.html" = {
      root = "/var/www/wedding-website";
      extraConfig = ''
        internal;
      '';
    };
    extraConfig = ''
      error_page 404 /custom_404.html;
    '';
  };
  services.nginx.virtualHosts."wedding.samandgeorgia.com" = {
    forceSSL = true;
    enableACME = true;
    root = "/var/www/wedding-website/maintenance";
    extraConfig = ''
      error_page 404 /custom_404.html;
    '';
  };
  services.nginx.virtualHosts."party.samandgeorgia.com" = {
    forceSSL = true;
    enableACME = true;
    root = "/var/www/wedding-website/maintenance";
    extraConfig = ''
      error_page 404 /custom_404.html;
    '';
  };

  security.acme.acceptTerms = true;
  security.acme.certs = {
   "samandgeorgia.com" = {
     domain = "*.samandgeorgia.com";
     dnsProvider = "cloudflare";
     credentialsFile = "/var/lib/acme/cloudflare.api";
     dnsPropagationCheck = true;
     email = "mail@sevanspowell.net";
     group = "nginx";
     #webroot = "/var/lib/acme/acme-challenge";
   };
   "wedding.samandgeorgia.com" = {
     email = "mail@sevanspowell.net";
     group = "nginx";
   };
   "party.samandgeorgia.com" = {
     email = "mail@sevanspowell.net";
     group = "nginx";
   };
  };
  security.acme.email = "mail@sevanspowell.net";

  services.syncthing.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?

}

