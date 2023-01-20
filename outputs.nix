{ self
, flake-utils
, nixpkgs
, sops-nix
, deploy
, haskellNix
, emacs-overlay
, ...
} @ inputs:

(flake-utils.lib.eachDefaultSystem (system:
  let
    overlays = [
      haskellNix.overlay
      emacs-overlay.overlay
    ];

    legacyPackages = import nixpkgs {
      inherit system overlays;
      inherit (haskellNix) config;
    };

    pkgs = legacyPackages;
  in
  {
    inherit legacyPackages;

    packages = {
      linode-cli = pkgs.python3Packages.callPackage ./pkgs/linode-cli.nix {};
      nix-ll = pkgs.callPackage ./pkgs/nix-ll.nix {};
      install-eyd = pkgs.callPackage ./pkgs/install-eyd.nix {};
      install-eyd-iso = (nixpkgs.lib.nixosSystem (import ./images/install-eyd system inputs)).config.system.build.isoImage;
    };

    devShell = pkgs.mkShell {
      NIX_CONFIG = ''
         # Needed for deploy-rs or my config
         allow-import-from-derivation = true
      '';

      EDITOR = "emacsclient -c -a emacs";

      nativeBuildInputs = [
        deploy.packages."${pkgs.system}".deploy-rs
        pkgs.ssh-to-age
        pkgs.sops
        pkgs.vim
      ];
    };
  })
) // {

  nixosConfigurations =
    let
      nixosSystem = nixpkgs.lib.makeOverridable nixpkgs.lib.nixosSystem;
    in {
      orchid = nixosSystem (import ./nodes/orchid inputs);
      server = nixosSystem (import ./nodes/server inputs);
      mooncake = nixosSystem (import ./nodes/mooncake inputs);
      client = nixosSystem (import ./nodes/client inputs);
      kimchi = nixosSystem (impot ./nodes/kimchi inputs);
      # install-eyd = nixosSystem (import ./images/install-eyd inputs);
    };

  deploy = {
    user = "root";
    sshUser = "root";

    nodes = {
      orchid = {
        hostname = "10.100.0.2:22";
        fastConnection = true;
        profiles.system.path =
          deploy.lib.x86_64-linux.activate.nixos
            self.nixosConfigurations."orchid";
      };

      server = {
        hostname = "10.100.0.1:22";
        fastConnection = true;
        profiles.system.path =
          deploy.lib.x86_64-linux.activate.nixos
            self.nixosConfigurations."server";
      };

      mooncake = {
        hostname = "10.100.0.3:22";
        fastConnection = true;
        profiles.system.path =
          deploy.lib.x86_64-linux.activate.nixos
            self.nixosConfigurations."mooncake";
      };

      client = {
        hostname = "10.100.0.4:22";
        fastConnection = true;
        profiles.system.path =
          deploy.lib.aarch64-linux.activate.nixos
            self.nixosConfigurations."client";
      };
    };
  };

  hydraJobs = nixpkgs.lib.mapAttrs' (name: config: nixpkgs.lib.nameValuePair "nixos-${name}" config.config.system.build.toplevel) self.nixosConfigurations;

  checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy.lib;
}
