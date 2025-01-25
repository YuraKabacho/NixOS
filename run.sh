#!/bin/bash 

# Run disko to destroy existing partitions, format disks, and mount them based on the provided disko.nix configuration
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount ./NixOS/disko.nix

# List block devices with filesystem information to verify disk partitions
lsblk -f

# Display partition table using fdisk to inspect disk layout
sudo fdisk -l

# Generate NixOS configuration files for the system in /mnt
sudo nixos-generate-config --root /mnt

# Copy hardware configuration file from the generated NixOS configuration to your local host directory
cp /mnt/etc/nixos/hardware-configuration.nix ./NixOS/hosts/kabacho/

# Change the current working directory to /NixOS
cd NixOS/

# Stage changes (e.g., new configuration files) to Git for version tracking
git add .

# Update flake.nix file and generate flake.lock
sudo nix --experimental-features "nix-command flakes" flake update

# Install NixOS using the configuration from the specified flake ('kabacho')
sudo nixos-install --flake ./#kabacho

# Switch to the user-specific Home Manager configuration, applying settings like user environment setup
home-manager switch
