#!/usr/bin/env bash

# ------------------------------------------------------------
# Check for dialog – install it if missing (NixOS live ISO)
# ------------------------------------------------------------
if ! command -v dialog &> /dev/null; then
    echo "dialog not found. Installing temporarily via nix-shell..."
    nix-shell -p dialog --run "$0"
    exit
fi

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------
FLAKE_FILE="./NixOS/flake.nix"
PASSWD="./NixOS/nixos/modules/user.nix"
HOSTS_DIR="./NixOS/hosts"

# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------
function msg_info() {
    dialog --backtitle "NixOS Installer" --infobox "$1" 5 50
    sleep 1
}

function msg_error() {
    dialog --backtitle "NixOS Installer" --msgbox "ERROR: $1" 6 50
}

function msg_ok() {
    dialog --backtitle "NixOS Installer" --msgbox "$1" 6 50
}

# -------------------------------------------------------------------
# _dialog - wrapper that captures stdout, sends UI (stderr) to terminal
# -------------------------------------------------------------------
_dialog() {
    dialog --stdout --backtitle "NixOS Installer" "$@" 2>/dev/tty
}

# ------------------------------------------------------------
# 1. Disk partitioning (disko)
# ------------------------------------------------------------
_dialog --yesno "Do you want to run disko for disk partitioning?" 7 50
disko_choice=$?
if [ $disko_choice -eq 0 ]; then
    # Choose modes using a checklist
    modes=$(_dialog --checklist "Select disko modes (use SPACE to select):" 15 50 3 \
        1 "destroy" off \
        2 "format" off \
        3 "mount" off)

    # If user pressed Cancel, skip
    if [ $? -ne 0 ]; then
        msg_info "Disko skipped."
    else
        # Build comma-separated mode string
        disko_mode=""
        for m in $modes; do
            case $m in
                1) disko_mode+="destroy," ;;
                2) disko_mode+="format,"  ;;
                3) disko_mode+="mount,"   ;;
            esac
        done
        disko_mode=${disko_mode%,}
        if [ -z "$disko_mode" ]; then
            msg_info "No modes selected, skipping disko."
        else
            msg_info "Running disko with mode: $disko_mode"
            sudo nix --experimental-features "nix-command flakes" \
                run github:nix-community/disko/latest -- \
                --mode "$disko_mode" ./NixOS/disko.nix
        fi
    fi
else
    msg_info "Skipping disko."
fi

# ------------------------------------------------------------
# 2. Inspect block devices
# ------------------------------------------------------------
_dialog --yesno "Do you want to inspect block devices and partition table?" 7 50
if [ $? -eq 0 ]; then
    tmpfile=$(mktemp)
    echo "Block devices:" > "$tmpfile"
    lsblk -f >> "$tmpfile" 2>&1
    echo -e "\nPartition table:" >> "$tmpfile"
    sudo fdisk -l >> "$tmpfile" 2>&1
    dialog --backtitle "NixOS Installer" --title "Disk Layout" --textbox "$tmpfile" 20 70
    rm "$tmpfile"
else
    msg_info "Skipping disk inspection."
fi

# ------------------------------------------------------------
# 3. Username
# ------------------------------------------------------------
USER_LINE=$(grep -E "^[[:space:]]*user[[:space:]]*=" "$FLAKE_FILE")
if [ -n "$USER_LINE" ]; then
    CURRENT_USER=$(echo "$USER_LINE" | awk -F '"' '{print $2}')
    _dialog --yesno "Current username: $CURRENT_USER\n\nDo you want to change it?" 8 50
    if [ $? -eq 0 ]; then
        NEW_USER=$(_dialog --inputbox "Enter new username:" 8 40 "$CURRENT_USER")
        if [ -n "$NEW_USER" ]; then
            sed -i "s/user = \"$CURRENT_USER\"/user = \"$NEW_USER\"/" "$FLAKE_FILE"
            msg_info "Username changed to $NEW_USER"
        else
            NEW_USER="$CURRENT_USER"
            msg_info "Keeping current username."
        fi
    else
        NEW_USER="$CURRENT_USER"
    fi
else
    NEW_USER=$(_dialog --inputbox "No username found in flake.nix.\nEnter a new username:" 9 40)
    if [ -n "$NEW_USER" ]; then
        sed -i "/let/a \    user = \"$NEW_USER\";" "$FLAKE_FILE"
        msg_info "Username set to $NEW_USER"
    else
        msg_error "Username cannot be empty. Exiting."
        exit 1
    fi
fi

# ------------------------------------------------------------
# 4. Password
# ------------------------------------------------------------
PASSWD_LINE=$(grep -E "^[[:space:]]*initialPassword[[:space:]]*=" "$PASSWD")
if [ -n "$PASSWD_LINE" ]; then
    CURRENT_PASSWD=$(echo "$PASSWD_LINE" | awk -F '"' '{print $2}')
    _dialog --yesno "A password is already set.\nDo you want to change it?" 8 50
    if [ $? -eq 0 ]; then
        NEW_PASSWD=$(_dialog --insecure --passwordbox "Enter new password:" 8 40)
        if [ -n "$NEW_PASSWD" ]; then
            sed -i "s/initialPassword = \"$CURRENT_PASSWD\"/initialPassword = \"$NEW_PASSWD\"/" "$PASSWD"
            msg_info "Password updated."
        else
            NEW_PASSWD="$CURRENT_PASSWD"
            msg_info "Password unchanged."
        fi
    else
        NEW_PASSWD="$CURRENT_PASSWD"
    fi
else
    NEW_PASSWD=$(_dialog --insecure --passwordbox "No password found.\nEnter a new password for user $NEW_USER:" 9 40)
    if [ -n "$NEW_PASSWD" ]; then
        sed -i "/let/a \    initialPassword = \"$NEW_PASSWD\";" "$PASSWD"
        msg_info "Password has been set."
    else
        msg_error "Password cannot be empty. Exiting."
        exit 1
    fi
fi

# ------------------------------------------------------------
# 5. Hostname selection / management
# ------------------------------------------------------------
while true; do
    # Refresh available hosts
    AVAILABLE_HOSTS=($(ls "$HOSTS_DIR" 2>/dev/null))
    if [ ${#AVAILABLE_HOSTS[@]} -eq 0 ]; then
        dialog --backtitle "NixOS Installer" --msgbox "No hosts found in $HOSTS_DIR.\nYou need to create one first." 7 60
        break
    fi

    # Build menu list
    host_menu_args=()
    for host in "${AVAILABLE_HOSTS[@]}"; do
        host_menu_args+=("$host" "$host")
    done

    # Main action menu
    action=$(_dialog --menu "Choose an action for hostnames" 15 60 4 \
        1 "Select an existing hostname" \
        2 "Create a new hostname (copy existing)" \
        3 "Rename an existing hostname" \
        4 "Delete an existing hostname")

    if [ $? -ne 0 ]; then
        if [ -z "$HOSTNAME" ]; then
            msg_error "No hostname selected. Exiting."
            exit 1
        else
            break
        fi
    fi

    case $action in
        1)
            selected=$(_dialog --menu "Select a hostname" 15 60 ${#AVAILABLE_HOSTS[@]} "${host_menu_args[@]}")
            if [ $? -eq 0 ] && [ -n "$selected" ]; then
                HOSTNAME="$selected"
                sed -i "s/\(hostname = \"\)[^\"]*\(\"\)/\1$HOSTNAME\2/" "$FLAKE_FILE"
                msg_ok "Hostname set to $HOSTNAME"
                break
            fi
            ;;
        2)
            src=$(_dialog --menu "Choose a host to copy" 15 60 ${#AVAILABLE_HOSTS[@]} "${host_menu_args[@]}")
            if [ $? -eq 0 ] && [ -n "$src" ]; then
                newhost=$(_dialog --inputbox "Enter new hostname:" 8 40)
                if [ -n "$newhost" ]; then
                    if [ -e "$HOSTS_DIR/$newhost" ]; then
                        msg_error "Host $newhost already exists."
                    else
                        cp -r "$HOSTS_DIR/$src" "$HOSTS_DIR/$newhost"
                        msg_ok "Copied $src to $newhost"
                    fi
                fi
            fi
            ;;
        3)
            src=$(_dialog --menu "Choose a host to rename" 15 60 ${#AVAILABLE_HOSTS[@]} "${host_menu_args[@]}")
            if [ $? -eq 0 ] && [ -n "$src" ]; then
                newhost=$(_dialog --inputbox "Enter new hostname:" 8 40)
                if [ -n "$newhost" ]; then
                    if [ -e "$HOSTS_DIR/$newhost" ]; then
                        msg_error "Host $newhost already exists."
                    else
                        mv "$HOSTS_DIR/$src" "$HOSTS_DIR/$newhost"
                        msg_ok "Renamed $src to $newhost"
                    fi
                fi
            fi
            ;;
        4)
            src=$(_dialog --menu "Choose a host to delete" 15 60 ${#AVAILABLE_HOSTS[@]} "${host_menu_args[@]}")
            if [ $? -eq 0 ] && [ -n "$src" ]; then
                _dialog --yesno "Are you sure you want to delete $src?" 7 60
                if [ $? -eq 0 ]; then
                    rm -rf "$HOSTS_DIR/$src"
                    msg_ok "$src has been deleted."
                fi
            fi
            ;;
        *)
            ;;
    esac
done

# ------------------------------------------------------------
# 6. NixOS version selection
# ------------------------------------------------------------
CURRENT_VERSION=$(grep -Po 'nixosVersion\s*=\s*"\K[^"]+' "$FLAKE_FILE" 2>/dev/null)
CURRENT_VERSION=${CURRENT_VERSION:-25.11}

NEW_VERSION=$(_dialog --inputbox "Current NixOS version: $CURRENT_VERSION\n\nEnter new version (YY.MM) or press Enter to keep:" 10 60 "$CURRENT_VERSION")

if [ -z "$NEW_VERSION" ]; then
    NEW_VERSION="$CURRENT_VERSION"
fi

if [[ ! "$NEW_VERSION" =~ ^[0-9]{2}\.[0-9]{2}$ ]]; then
    msg_error "Invalid version format. Keeping $CURRENT_VERSION."
    NEW_VERSION="$CURRENT_VERSION"
fi

if [[ "$NEW_VERSION" != "$CURRENT_VERSION" ]]; then
    sed -i "s/\(nixosVersion = \"\)[^\"]*\(\"\)/\1${NEW_VERSION}\2/" "$FLAKE_FILE"
    sed -i \
        -e "s|\(github:nixos/nixpkgs/nixos-\)[0-9]\{2\}\.[0-9]\{2\}|\1${NEW_VERSION}|" \
        -e "s|\(github:nix-community/home-manager/release-\)[0-9]\{2\}\.[0-9]\{2\}|\1${NEW_VERSION}|" \
        "$FLAKE_FILE"
    msg_ok "Version updated to $NEW_VERSION"
else
    msg_info "Version remains $CURRENT_VERSION."
fi

# ------------------------------------------------------------
# 7. Garbage collection
# ------------------------------------------------------------
_dialog --yesno "Do you want to run garbage collection to free up space?" 7 60
if [ $? -eq 0 ]; then
    msg_info "Cleaning up garbage..."
    sudo nix-collect-garbage
else
    msg_info "Skipping garbage collection."
fi

# ------------------------------------------------------------
# 8. Move to NixOS directory
# ------------------------------------------------------------
cd NixOS/ || { msg_error "Failed to cd into NixOS/"; exit 1; }
msg_info "Working directory: $(pwd)"

# ------------------------------------------------------------
# 9. Flake update
# ------------------------------------------------------------
while true; do
    update_choice=$(_dialog --menu "Do you want to update the flake lockfile?" 12 60 2 \
        1 "Yes" \
        2 "No")

    if [ $? -ne 0 ]; then
        msg_error "Cancelled. Exiting."
        exit 1
    fi

    if [ "$update_choice" == "1" ]; then
        msg_info "Updating flake..."
        sudo nix --experimental-features "nix-command flakes" flake update
        break
    elif [ "$update_choice" == "2" ]; then
        if [ -f "./flake.lock" ]; then
            msg_info "Flake lock exists, skipping update."
            break
        else
            msg_error "flake.lock does not exist. You must update the flake."
        fi
    fi
done

# ------------------------------------------------------------
# 10. Install or rebuild
# ------------------------------------------------------------
choice=$(_dialog --menu "Choose what to do" 12 60 2 \
    1 "Install NixOS (nixos-install)" \
    2 "Rebuild existing NixOS configuration (nixos-rebuild)")

if [ $? -ne 0 ]; then
    msg_error "No choice made. Exiting."
    exit 1
fi

if [ "$choice" == "1" ]; then
    clear
    echo "Running installation..."
    sudo nixos-generate-config --root /mnt
    cp /mnt/etc/nixos/hardware-configuration.nix ./hosts/$HOSTNAME/
    git add .
    echo "Starting nixos-install --flake ./#$HOSTNAME"
    sudo nixos-install --flake ./#$HOSTNAME
    echo -e "\n\033[1;36mInstallation complete!\033[0m"
    echo "After reboot, run: home-manager switch --flake ./#${NEW_USER}"
elif [ "$choice" == "2" ]; then
    rebuild_mode=$(_dialog --menu "Select rebuild mode" 12 60 3 \
        1 "switch" \
        2 "boot" \
        3 "build")

    case $rebuild_mode in
        1) mode="switch" ;;
        2) mode="boot"   ;;
        3) mode="build"  ;;
        *) msg_error "Invalid option. Exiting."; exit 1 ;;
    esac

    clear
    echo "Running rebuild..."
    cp /etc/nixos/hardware-configuration.nix ./hosts/$HOSTNAME/
    git add .
    echo "Executing: sudo nixos-rebuild $mode --flake ./#$HOSTNAME"
    sudo nixos-rebuild "$mode" --flake ./#$HOSTNAME
    echo "Applying Home Manager configuration for $NEW_USER..."
    home-manager switch --flake ./#$NEW_USER
fi

clear
echo "All done. Have a great NixOS experience!"