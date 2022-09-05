# nix-config
NixOs Configuration

### Steps 

1. Generate and build initial config

```
# generates a base 
# - configuration.nix
# - hardware-configuration.nix
# see https://nixos.wiki/wiki/Nixos-generate-config

nixos-generate-config

# build initial config
nixos-rebuild switch
```

2. Clone this Repository
```
# install git
nix-env -i git
# or for a quicker install 
nix-env -iA nix.git

# clone this repository
git clone https://github.com/adjacentresearch/nix-config.git /etc/nixos/nix-config
mv /etc/nixos/nix-config/* /etc/nixos/
rm -rf /etc/nixos/nix-config
```

3. Rebuild your system

```
nixos-rebuild switch
```
