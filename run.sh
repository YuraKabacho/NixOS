#!/bin/bash

# Define color codes for better visibility
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"

# Prompt the user to run disko or not
echo -e "${YELLOW}Do you want to run disko?${RESET}"
echo -e "${GREEN}1) Yes${RESET}"
echo -e "${RED}2) No${RESET}"
read -p "Enter your choice (1 or 2): " disko_choice

if [[ $disko_choice -eq 1 ]]; then
    echo -e "${YELLOW}Choose disko mode (you can select multiple modes):${RESET}"
    echo -e "${GREEN}1) destroy${RESET}"
    echo -e "${GREEN}2) format${RESET}"
    echo -e "${GREEN}3) mount${RESET}"
    echo -e "${CYAN}Enter your choices separated by commas (e.g., 1,3):${RESET}"
    read -p "Choices: " disko_modes

    # Convert user input into a valid disko mode string
    disko_mode_string=""
    if [[ $disko_modes == *"1"* ]]; then
        disko_mode_string+="destroy,"
    fi
    if [[ $disko_modes == *"2"* ]]; then
        disko_mode_string+="format,"
    fi
    if [[ $disko_modes == *"3"* ]]; then
        disko_mode_string+="mount,"
    fi

    # Remove trailing comma
    disko_mode_string=${disko_mode_string%,}

    echo -e "${BLUE}Running disko with mode: ${disko_mode_string}${RESET}"
    # Run disko
    sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode "$disko_mode_string" ./NixOS/disko.nix
elif [[ $disko_choice -eq 2 ]]; then
    echo -e "${RED}Skipping disko...${RESET}"
else
    echo -e "${RED}Invalid choice. Exiting script.${RESET}"
    exit 1
fi

# Prompt the user to check block devices and partitions
echo -e "${YELLOW}Do you want to inspect block devices and partition table?${RESET}"
echo -e "${GREEN}1) Yes${RESET}"
echo -e "${RED}2) No${RESET}"
read -p "Enter your choice (1 or 2): " inspect_choice

if [[ $inspect_choice -eq 1 ]]; then
    # List block devices with filesystem information
    echo -e "${CYAN}Inspecting block devices...${RESET}"
    lsblk -f
    # Display partition table using fdisk
    echo -e "${CYAN}Inspecting partition table...${RESET}"
    sudo fdisk -l
elif [[ $inspect_choice -eq 2 ]]; then
    echo -e "${RED}Skipping disk inspection...${RESET}"
else
    echo -e "${RED}Invalid choice. Exiting script.${RESET}"
    exit 1
fi

# Prompt the user to choose between installation or rebuild
echo -e "${YELLOW}Choose an option:${RESET}"
echo -e "${GREEN}1) Install NixOS (nixos-install)${RESET}"
echo -e "${BLUE}2) Rebuild NixOS configuration (nixos-rebuild switch)${RESET}"
read -p "Enter your choice (1 or 2): " choice

if [[ $choice -eq 1 ]]; then
    echo -e "${CYAN}Running installation flow...${RESET}"
    # Generate NixOS configuration files for installation
    sudo nixos-generate-config --root /mnt
    # Copy hardware configuration file from /mnt for installation
    cp /mnt/etc/nixos/hardware-configuration.nix ./NixOS/hosts/kabacho/
elif [[ $choice -eq 2 ]]; then
    echo -e "${CYAN}Running rebuild flow...${RESET}"
    # Copy hardware configuration file from the live system for rebuild
    cp /etc/nixos/hardware-configuration.nix ./NixOS/hosts/kabacho/
else
    echo -e "${RED}Invalid choice. Exiting script.${RESET}"
    exit 1
fi

# Change the current working directory to /NixOS
cd NixOS/

# Stage changes (e.g., new configuration files) to Git for version tracking
git add .

# Removes packages to free up space
sudo nix-collect-garbage

# Update flake.nix file and generate flake.lock
sudo nix --experimental-features "nix-command flakes" flake update

# Execute the chosen action
if [[ $choice -eq 1 ]]; then
    echo -e "${CYAN}Executing nixos-install...${RESET}"
    sudo nixos-install --flake ./#kabacho
elif [[ $choice -eq 2 ]]; then
    echo -e "${CYAN}Executing nixos-rebuild switch...${RESET}"
    sudo nixos-rebuild switch --flake ./#kabacho
fi

# Switch to the user-specific Home Manager configuration, applying settings like user environment setup
echo -e "${GREEN}Applying Home Manager configuration...${RESET}"
home-manager switch