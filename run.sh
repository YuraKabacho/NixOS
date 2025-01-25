#!/bin/bash 

# Run disko to destroy existing partitions, format disks, and mount them based on the provided disko.nix configuration
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount ./NixOS/disko.nix

# Prompt the user to check block devices and partitions
echo "Do you want to inspect block devices and partition table?"
echo "1) Yes"
echo "2) No"
read -p "Enter your choice (1 or 2): " inspect_choice

if [[ $inspect_choice -eq 1 ]]; then
    # List block devices with filesystem information
    lsblk -f
    # Display partition table using fdisk
    sudo fdisk -l
elif [[ $inspect_choice -eq 2 ]]; then
    echo "Skipping disk inspection..."
else
    echo "Invalid choice. Exiting script."
    exit 1
fi

# Prompt the user to choose between installation or rebuild
echo "Choose an option:"
echo "1) Install NixOS (nixos-install)"
echo "2) Rebuild NixOS configuration (nixos-rebuild switch)"
read -p "Enter your choice (1 or 2): " choice

if [[ $choice -eq 1 ]]; then
    echo "Running installation flow..."
    # Generate NixOS configuration files for installation
    sudo nixos-generate-config --root /mnt
    # Copy hardware configuration file from /mnt for installation
    cp /mnt/etc/nixos/hardware-configuration.nix ./NixOS/hosts/kabacho/
elif [[ $choice -eq 2 ]]; then
    echo "Running rebuild flow..."
    # Copy hardware configuration file from the live system for rebuild
    cp /etc/nixos/hardware-configuration.nix ./NixOS/hosts/kabacho/
else
    echo "Invalid choice. Exiting script."
    exit 1
fi

# Copy hardware configuration file from the generated NixOS configuration to your local host directory
cp /mnt/etc/nixos/hardware-configuration.nix ./NixOS/hosts/kabacho/

# Change the current working directory to /NixOS
cd NixOS/

# Stage changes (e.g., new configuration files) to Git for version tracking
git add .

# Removes packages to free up space
sudo nix-collect-garbage

# Update flake.nix file and generate flake.lock
sudo nix --experimental-features "nix-command flakes" flake update

# Prompt the user to choose between nixos-install and nixos-rebuild switch
echo "Choose an option:"
echo "1) Install NixOS (nixos-install)"
echo "2) Rebuild NixOS configuration (nixos-rebuild switch)"
read -p "Enter your choice (1 or 2): " choice

if [[ $choice -eq 1 ]]; then
    echo "Running nixos-install..."
# Install NixOS using the configuration from the specified flake ('kabacho')
    sudo nixos-install --flake ./#kabacho
elif [[ $choice -eq 2 ]]; then
    echo "Running nixos-rebuild switch..."
# Rebuilding existing NixOS using the configuration from the specified flake ('kabacho')
    sudo nixos-rebuild switch --flake ./#kabacho
else
    echo "Invalid choice. Exiting script."
    exit 1
fi

# Switch to the user-specific Home Manager configuration, applying settings like user environment setup
home-manager switch
