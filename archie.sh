#!/bin/bash

# Colors
RED='\033[0;31m'
LIGHTBLUE='\033[1;34m'
LIGHTCYAN='\033[1;36m'
LIGHTPURPLE='\033[1;35m'
LIGHTGREEN='\033[1;32m'
NOCOLOR='\033[0m'

# Global Variables
CURRENT_STEP=1
CURRENT_SUBSTEP=1
CURRENT_STEP_TEXT=""
CURRENT_SUBSTEP_TEXT=""

increment_step() {
    CURRENT_STEP=$((CURRENT_STEP+1))
}

increment_substep() {
    CURRENT_SUBSTEP=$((CURRENT_SUBSTEP+1))
}

if [ $SUDO_USER ]; then
    real_user=$SUDO_USER
else
    real_user=$(whoami)
fi

# Helper Functions

echo_error () {
    echo -e "${RED}error:${NOCOLOR} $1" >&2
    exit $2
}

echo_step () {
    CURRENT_STEP_TEXT=$1;
    echo
    echo -e "${LIGHTPURPLE}[Step ${CURRENT_STEP}]${NOCOLOR} - $CURRENT_STEP_TEXT"
    echo 
}

echo_substep() {
    CURRENT_SUBSTEP_TEXT=$1;
    echo
    echo -e "${LIGHTPURPLE}[Step ${CURRENT_STEP}.${CURRENT_SUBSTEP}]${NOCOLOR} - $CURRENT_SUBSTEP_TEXT"
    echo
}

echo_finish_substep() {
    echo
    echo -e "${LIGHTGREEN}Step ${CURRENT_STEP}.${CURRENT_SUBSTEP} - $CURRENT_SUBSTEP_TEXT done!${NOCOLOR}"
    echo 
    CURRENT_SUBSTEP=$((CURRENT_SUBSTEP+1))
}

echo_finish_step() {
    echo
    echo -e "${LIGHTGREEN}Step ${CURRENT_STEP} - ${CURRENT_STEP_TEXT} done!${NOCOLOR}"
    echo 
    CURRENT_STEP=$((CURRENT_STEP+1))
    CURRENT_SUBSTEP=0
}

install_packages () {
    pacman -S --color always --noconfirm $1
    if [ $? -eq 0 ]; then
        echo
        echo -e "${LIGHTGREEN}[install_packages] sucesfully installed $1${NOCOLOR}"
    else
        echo
        echo_error "failed to install '$1' with pacman. Do the packages exist?" $?
    fi
}

remove_packages() {
    local pkgs=("$@")
    local packagesToRemove=""
    
    for (( i=0; i<${#pkgs[@]}; i++ )); do
        local package="${pkgs[i]}"
        pacman -Qi "$package" > /dev/null
    
        if [ $? -eq 0 ]; then
            if [ -n "$packagesToRemove" ]; then
                packagesToRemove+=" $package"
            else
                packagesToRemove+="$package"
            fi
        fi
    done

    local failRemove=0

    if [ "$packagesToRemove" != "" ]; then
        failRemove=$((pacman -Rcns --noconfirm --color always $packagesToRemove) 2>&1)
    else 
        echo
        echo -e "${LIGHTGREEN}[remove_packages] packages declared for removal are not installed, skipping...${NOCOLOR}"
        return 0
    fi
    if [ $failRemove -eq 0 ]; then
        echo
        echo -e "${LIGHTGREEN}[remove_packages] sucesfully removed $packagesToRemove ${NOCOLOR}"
    else
        echo
        echo_error "failed to remove '$packagesToRemove' with pacman", $?
    fi
}

gnome_tweaks() {
    local ruser_uid=$(id -u ${real_user})
    echo "Set display scaling to 100%"
    sudo -u ${real_user} DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${ruser_uid}/bus" gsettings set org.gnome.desktop.interface text-scaling-factor 1.0
    if [ -e "/home/$real_user/.config/monitors.xml" ]; then
        echo "Copy monitors.xml to xdg (for GDM display scaling)"
        cp /home/$real_user/.config/monitors.xml /etc/xdg/monitors.xml
    else
        echo "monitors.xml doesn't exist, skipping setting display scale for GDM"
    fi
    echo "Reduce volume step scale to 2"
    sudo -u ${real_user} DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${ruser_uid}/bus" gsettings set org.gnome.settings-daemon.plugins.media-keys volume-step 2
    echo "Enable minimize button on windows"
    sudo -u ${real_user} DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${ruser_uid}/bus" gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,close'
    echo "Set color scheme to dark"
    sudo -u ${real_user} DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${ruser_uid}/bus" gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    echo "Enable log out option"
    sudo -u ${real_user} DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${ruser_uid}/bus" gsettings set org.gnome.shell always-show-log-out true
}

install_gnome_extension() {
    echo "Installing AppIndicator support"
    runuser -u ${real_user} -- pipx run gnome-extensions-cli install appindicatorsupport@rgcjonas.gmail.com
    echo "Installing Color Picker"
    runuser -u ${real_user} -- pipx run gnome-extensions-cli install color-picker@tuberry
    local pipx=("python-pipx")
    remove_packages ${pipx[@]}
}

# Banner
echo -e "${LIGHTCYAN}                _     _      
  __ _ _ __ ___| |__ (_) ___ 
 / _\` | '__/ __| '_ \| |/ _ \\
${LIGHTPURPLE}| (_| | | | (__| | | | |  __/
 \__,_|_|  \___|_| |_|_|\___|${NOCOLOR}"
echo
echo "Welcome to ReduxFlakes's Archie script :3"
echo

# startChecks
isArch=$([[ `cat /etc/os-release | grep 'ID'` =~ "arch" ]] && echo true || echo false)

if ! [ $(id -u) = 0 ]; then
    echo_error "The script needs to be run as root.", 1
fi

if [[ $isArch == false ]]; then
    echo_error "Archie is only compatible with Arch Linux! Exiting...", 1
fi
# endChecks

echo -e "${LIGHTBLUE}--- About ---${NOCOLOR}"
echo "Archie is a simple shell script that configures vanilla Arch Linux to my linking."
echo
echo -e "${LIGHTBLUE}Features${NOCOLOR}"
echo "  - install required packages"
echo "  - debloat GNOME, tweak it, and install extensions"
# echo "  - set up preferred shell and it's configurations (zsh with powerlevel10k, history, and autocomplete)"
# echo -e "${LIGHTBLUE}Software${NOCOLOR}"
# echo "  - VM (libvirt and qemu)"
# echo "  - Containers (podman, toolbox, and distrobox)"
echo

echo_step "Installing necessary packages"
install_packages "base-devel vim git wget rsync curl python python-pipx"
echo_finish_step

echo_step "Setup GNOME"

echo_substep "Removing bloat"
gnomeBloat=("decibels" "gnome-calendar" "gnome-console" "gnome-contacts" "gnome-maps" "gnome-music" "gnome-software" "gnome-system-monitor" "gnome-tour" "gnome-weather" "orca" "showtime" "simple-scan")
remove_packages ${gnomeBloat[@]}
echo_finish_substep

echo_substep "Tweaking settings"
gnome_tweaks
echo_finish_substep

echo_substep "Installing extension"
install_gnome_extension
echo_finish_substep
