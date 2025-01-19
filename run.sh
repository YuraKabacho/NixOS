#!/bin/bash

# Clone the repository
git clone https://github.com/YuraKabacho/NixOS

# Move disko.nix to the current directory
mv ./NixOS/disko.nix ./

# Run disko with destroy, format, and mount mode
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount ./disko.nix

# List block devices
lsblk -f

# Generate NixOS configuration
sudo nixos-generate-config --root /mnt

# Install NixOS with the specified flake
sudo nixos-install switch --flake ./
