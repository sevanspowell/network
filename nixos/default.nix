{ configuration
, system ? builtins.currentSystem
, pkgs
}:
let
  nixpkgs = pkgs.lib.cleanSource pkgs.path;

  eval = import "${nixpkgs}/nixos/lib/eval-config.nix" {
    inherit system;
    modules = [ configuration ];
  };

  # This is for `nixos-rebuild build-vm'.
  vmConfig = (import "${nixpkgs}/nixos/lib/eval-config.nix" {
    inherit system;
    modules = [ configuration "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix" ];
  }).config;

  # This is for `nixos-rebuild build-vm-with-bootloader'.
  vmWithBootLoaderConfig =
    # Bit of a hack, vmWithBootLoaderConfig by default doesn't load any store
    # paths into the DB. So they're available but Nix doesn't see them. So, we
    # eval the config once to get the full closure of the config, then use the
    # closure registration info to ensure that all the store paths are
    # registered in the VM.
    let
      mkCfg = extraConfig: (import "${nixpkgs}/nixos/lib/eval-config.nix" {
        inherit system;
        modules =
          [ configuration
            "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
            { virtualisation.useBootLoader = true; }
            ({ config, ... }: {
              virtualisation.useEFIBoot =
                config.boot.loader.systemd-boot.enable ||
                config.boot.loader.efi.canTouchEfiVariables;
            })
            extraConfig
          ];
      }).config;

      regInfo = pkgs.closureInfo { rootPaths = (mkCfg { }).system.build.toplevel; };
    in
      mkCfg {
        # Ensure that the store paths of the configuration are available in the
        # VM The VM adds postBootCommands that load the regInfo variable. This
        # means we can nix-env and nixos-rebuild in the VM without having to
        # perform any extra setup.
        system.extraSystemBuilderCmds =
          ''
          echo " regInfo=${regInfo}/registration" >> $out/kernel-params
          '';
      };

in

{
  inherit (eval) pkgs config options;

  system = eval.config.system.build.toplevel;

  vm = vmConfig.system.build.vm;

  vmWithBootLoader = vmWithBootLoaderConfig.system.build.vm;
}
