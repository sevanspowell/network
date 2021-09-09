# NixOS modules

## Structure

- Each folder has:
  - a default.nix which contains the core configuration of that
    module.
  - a persist.nix (if required) which contains the configuration
    required to make that core module work in a erase-your-darlings
    setting.
