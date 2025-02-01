#!/bin/bash

# Define color codes for better visibility
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"

# Function to display warnings
function warning_message() {
    echo -e "${RED}WARNING: $1${RESET}"
}

# Function to display informational messages
function info_message() {
    echo -e "${CYAN}$1${RESET}"
}

# Disk management and other steps
echo -e "${YELLOW}Do you want to run disko?${RESET}"
echo -e "${GREEN}1) Yes${RESET}"
echo -e "${RED}2) No${RESET}"
read -p "Enter your choice (1 or 2): " disko_choice

if [[ $disko_choice -eq 1 ]]; then
    echo -e "${YELLOW}Choose disko mode:${RESET}"
    echo -e "${GREEN}1) destroy${RESET}"
    echo -e "${GREEN}2) format${RESET}"
    echo -e "${GREEN}3) mount${RESET}"
    echo -e "${CYAN}Enter your choices separated by commas:${RESET}"
    read -p "Choices: " disko_modes

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

    disko_mode_string=${disko_mode_string%,} # Remove trailing comma
    info_message "Running disko with mode: ${disko_mode_string}"
    sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode "$disko_mode_string" ./NixOS/disko.nix
elif [[ $disko_choice -eq 2 ]]; then
    echo -e "${RED}Skipping disko...${RESET}"
else
    warning_message "Invalid choice. Exiting script."
    exit 1
fi

# Prompt the user to check block devices and partitions
echo -e "${YELLOW}Do you want to inspect block devices and partition table?${RESET}"
echo -e "${GREEN}1) Yes${RESET}"
echo -e "${RED}2) No${RESET}"
read -p "Enter your choice (1 or 2): " inspect_choice

if [[ $inspect_choice -eq 1 ]]; then
    info_message "Inspecting block devices..."
# List block devices with filesystem information
    lsblk -f
    info_message "Inspecting partition table..."
# Display partition table using fdisk
    sudo fdisk -l
elif [[ $inspect_choice -eq 2 ]]; then
    echo -e "${RED}Skipping disk inspection...${RESET}"
else
    warning_message "Invalid choice. Exiting script."
    exit 1
fi

# Extract the username from flake.nix
FLAKE_FILE="./NixOS/flake.nix"
USER_LINE=$(grep -E "^[[:space:]]*user[[:space:]]*=" "$FLAKE_FILE")

if [[ -n "$USER_LINE" ]]; then
    CURRENT_USER=$(echo "$USER_LINE" | awk -F '"' '{print $2}')
    echo -e "${YELLOW}Current username in flake.nix: ${GREEN}$CURRENT_USER${RESET}"
    read -p "Do you want to change the username? (y/n): " change_user
    if [[ "$change_user" == "y" ]]; then
        read -p "Enter new username: " NEW_USER
        sed -i "s/user = \"$CURRENT_USER\"/user = \"$NEW_USER\"/" "$FLAKE_FILE"
        info_message "Username changed to ${GREEN}$NEW_USER ${CYAN}in flake.nix.${RESET}"
    else
        NEW_USER="$CURRENT_USER"
    fi
else
    read -p "No username found in flake.nix. Enter a new username: " NEW_USER
    sed -i "/let/a \    user = \"$NEW_USER\";" "$FLAKE_FILE"
    info_message "Username changed to ${GREEN}$NEW_USER ${CYAN}in flake.nix.${RESET}"
fi

# Set password for the user
PASSWD="./NixOS/nixos/modules/user.nix"
PASSWD_LINE=$(grep -E "^[[:space:]]*initialPassword[[:space:]]*=" "$PASSWD")

if [[ -n "$PASSWD_LINE" ]]; then
    CURRENT_PASSWD=$(echo "$PASSWD_LINE" | awk -F '"' '{print $2}')
    echo -e "${YELLOW}Current passwd: ${GREEN}$CURRENT_PASSWD${RESET}"
    read -p "Do you want to set new password? (y/n): " change_passwd
    if [[ "$change_passwd" == "y" ]]; then
        stty -echo
        read -p "Enter new password: " NEW_PASSWD
        stty echo
        sed -i "s/initialPassword = \"$CURRENT_PASSWD\"/initialPassword = \"$NEW_PASSWD\"/" "$PASSWD"
        info_message "Password changed."
    else
        NEW_PASSWD="$CURRENT_PASSWD"
    fi
else
    stty -echo
    read -p "No password found for user $NEW_USER. Enter a new password: " NEW_PASSWD
    stty echo
    sed -i "/let/a \    initialPassword = \"$NEW_PASSWD\";" "$PASSWD"
    info_message "Password changed."
fi

# Section: Hostname Selection or Creation
info_message "Checking available hosts in ./NixOS/hosts directory..."
AVAILABLE_HOSTS=$(ls ./NixOS/hosts 2>/dev/null) # List all existing hosts in the ./NixOS/hosts directory
if [[ -z "$AVAILABLE_HOSTS" ]]; then
    warning_message "No hosts available in ./NixOS/hosts. You will need to create a new one."
else
    echo -e "${YELLOW}Available hosts:${RESET}"
    echo "$AVAILABLE_HOSTS" | nl # Print the hosts as a numbered list
fi

while true; do
    # Prompt user to select or manage hostnames
    echo -e "${YELLOW}Do you want to:${RESET}"
    echo -e "${GREEN}1) Select an existing hostname${RESET}"
    echo -e "${BLUE}2) Create a new hostname by copying and renaming an existing one${RESET}"
    echo -e "${CYAN}3) Rename an existing hostname${RESET}"
    echo -e "${RED}4) Delete an existing hostname${RESET}"  # New option to delete
    read -p "Enter your choice (1, 2, 3, or 4): " hostname_choice

    case $hostname_choice in
        1) # Select an existing hostname
            echo -e "${YELLOW}Select a hostname from the list:${RESET}"
            echo "$AVAILABLE_HOSTS" | nl
            read -p "Enter the number corresponding to your choice: " selected_host_number
            HOSTNAME=$(echo "$AVAILABLE_HOSTS" | sed -n "${selected_host_number}p")
            if [[ -z "$HOSTNAME" ]]; then
                warning_message "Invalid selection. Please try again."
            else
                info_message "Selected hostname: $HOSTNAME"
                sed -i "s/hostname = \" \"/hostname = \"$HOSTNAME\"/" .NixOS/flake.nix
                break # Proceed to the next step
            fi
            ;;
        2) # Create a new hostname by copying an existing one
            echo -e "${YELLOW}Choose an existing host to copy:${RESET}"
            echo "$AVAILABLE_HOSTS" | nl
            read -p "Enter the number corresponding to the host to copy: " copy_host_number
            COPY_HOST=$(echo "$AVAILABLE_HOSTS" | sed -n "${copy_host_number}p")
            if [[ -z "$COPY_HOST" ]]; then
                warning_message "Invalid selection. Please try again."
            else
                read -p "Enter the new hostname: " HOSTNAME
                cp -r "./NixOS/hosts/$COPY_HOST" "./NixOS/hosts/$HOSTNAME"
                info_message "Copied $COPY_HOST to create new host $HOSTNAME"
            fi
            ;;
        3) # Rename an existing hostname
            echo -e "${YELLOW}Choose an existing host to rename:${RESET}"
            echo "$AVAILABLE_HOSTS" | nl
            read -p "Enter the number corresponding to the host to rename: " rename_host_number
            RENAME_HOST=$(echo "$AVAILABLE_HOSTS" | sed -n "${rename_host_number}p")
            if [[ -z "$RENAME_HOST" ]]; then
                warning_message "Invalid selection. Please try again."
            else
                read -p "Enter the new hostname: " HOSTNAME
                mv "./NixOS/hosts/$RENAME_HOST" "./NixOS/hosts/$HOSTNAME"
                info_message "Renamed $RENAME_HOST to $HOSTNAME"
            fi
            ;;
        4) # Delete an existing hostname
            echo -e "${YELLOW}Choose a host to delete:${RESET}"
            echo "$AVAILABLE_HOSTS" | nl
            read -p "Enter the number corresponding to the host to delete: " delete_host_number
            DELETE_HOST=$(echo "$AVAILABLE_HOSTS" | sed -n "${delete_host_number}p")
            if [[ -z "$DELETE_HOST" ]]; then
                warning_message "Invalid selection. Please try again."
            else
                read -p "Are you sure you want to delete $DELETE_HOST? (y/n): " confirmation
                if [[ "$confirmation" == "y" || "$confirmation" == "Y" ]]; then
                    rm -rf "./NixOS/hosts/$DELETE_HOST"
                    info_message "$DELETE_HOST has been deleted."
                else
                    info_message "Deletion cancelled."
                fi
            fi
            ;;
        *) # Invalid input
            warning_message "Invalid choice. Please try again."
            ;;
    esac
done

# Prompt to clean garbage
echo -e "${YELLOW}Do you want to clean garbage to free up space?${RESET}"
echo -e "${GREEN}1) Yes${RESET}"
echo -e "${RED}2) No${RESET}"
read -p "Enter your choice (1 or 2): " clean_choice

if [[ $clean_choice -eq 1 ]]; then
    info_message "Cleaning up garbage..."
# Removes packages to free up space
    sudo nix-collect-garbage
elif [[ $clean_choice -eq 2 ]]; then
    echo -e "${RED}Skipping garbage cleaning...${RESET}"
else
    warning_message "Invalid choice. Skipping garbage cleaning."
fi

# Change the current working directory to /NixOS
cd NixOS/
info_message "Redirected to NixOS/"

# Prompt to update flake
while true; do
    echo -e "${YELLOW}Do you want to update flake?${RESET}"
    echo -e "${GREEN}1) Yes${RESET}"
    echo -e "${RED}2) No${RESET}"
    read -p "Enter your choice (1 or 2): " flake_update_choice

    if [[ $flake_update_choice -eq 1 ]]; then
        info_message "Updating flake..."
        # Update flake.nix file and generate flake.lock
        sudo nix --experimental-features "nix-command flakes" flake update
        break
    elif [[ $flake_update_choice -eq 2 ]]; then
        if [[ -f "./flake.lock" ]]; then
            echo -e "${RED}Skipping flake update...${RESET}"
        else
            warning_message "flake.lock does not exist. Please update flake."
            continue
        fi
    else
        warning_message "Invalid choice. Please try again."
    fi
done

# Prompt the user to choose between installation or rebuild
echo -e "${YELLOW}Choose an option:${RESET}"
echo -e "${GREEN}1) Install NixOS (nixos-install)${RESET}"
echo -e "${BLUE}2) Rebuild existing NixOS configuration (nixos-rebuild)${RESET}"
read -p "Enter your choice (1 or 2): " choice

if [[ $choice -eq 1 ]]; then
    info_message "Running installation flow..."
# Generate NixOS configuration files for installation
    sudo nixos-generate-config --root /mnt
# Copy hardware configuration file from /mnt for installation
    cp /mnt/etc/nixos/hardware-configuration.nix ./hosts/$HOSTNAME/
# 
    git add .
    info_message "Added new files to git"
# 
    info_message "Executing nixos-install..."
    sudo nixos-install --flake ./#$HOSTNAME
#
    info_message "Do not forget to clone once more repository and run \n 
    home-manager switch --flake ./#${GREEN}$NEW_USER${RESET}"
elif [[ $choice -eq 2 ]]; then
    echo -e "${YELLOW}Choose rebuild option:${RESET}"
    echo -e "${GREEN}1) switch${RESET}"
    echo -e "${GREEN}2) boot${RESET}"
    echo -e "${GREEN}3) build${RESET}"
    read -p "Enter your choice (1, 2, or 3): " rebuild_option

    case $rebuild_option in
        1)
            rebuild_mode="switch"
            ;;
        2)
            rebuild_mode="boot"
            ;;
        3)
            rebuild_mode="build"
            ;;
        *)
            warning_message "Invalid rebuild choice. Exiting script."
            exit 1
            ;;
    esac

    info_message "Running rebuild flow with mode: ${rebuild_mode}"
# Copy hardware configuration file for installation
    cp /etc/nixos/hardware-configuration.nix ./hosts/$HOSTNAME/
# 
    git add .
    info_message "Added new files to git"
#
    info_message "Executing nixos-rebuild ${rebuild_mode}..."
    sudo nixos-rebuild "$rebuild_mode" --flake ./#$HOSTNAME
# Apply Home Manager configuration
    info_message "Applying Home Manager configuration fot ${GREEN}$NEW_USER${RESET}..."
    home-manager switch --flake ./#${GREEN}$NEW_USER${RESET}
else
    warning_message "Invalid choice. Exiting script."
    exit 1
fi