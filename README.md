# README

## Build configurations

nix build .#nixosConfigurations.orchid.config.system.build.toplevel
nix build .#nixosConfigurations.server.config.system.build.vm

## Deploy

nix develop
deploy .#orchid

## Sops

- Get PGP key fingerprint `gpg --list-secret-keys`
- Add key to root `.sops.yaml`:
  ```
  keys:
    - &admin_sam 2504791468B153B8A3963CC97BA53D1919C5DFD4
  creation_rules:
    - path_regex: secrets/[^/]+\.yaml$
      key_groups:
      - pgp:
        - *admin_sam
  ```
