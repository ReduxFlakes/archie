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

if [ "$SUDO_USER" ]; then
    real_user=$SUDO_USER
    user_home=/home/"$real_user"
else
    real_user=$(whoami)
fi

# Helper Functions

echo_error () {
    echo -e "${RED}error:${NOCOLOR} $1" >&2
    exit "$2"
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
    pacman -S --color always --noconfirm "$1"
    if [ $? -eq 0 ]; then
        echo -e "${LIGHTGREEN}[install_packages] sucesfully installed $1${NOCOLOR}"
    else
        echo_error "[install_packages] failed to install '$1' with pacman. Do the packages exist?" $?
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
        failRemove=$( (pacman -Rcns --noconfirm --color always "$packagesToRemove") 2>&1)
    else 
        echo -e "${LIGHTGREEN}[remove_packages] packages declared for removal are not installed, skipping...${NOCOLOR}"
        return 0
    fi
    if [ "$failRemove" -eq 0 ]; then
        echo -e "${LIGHTGREEN}[remove_packages] sucesfully removed $packagesToRemove ${NOCOLOR}"
    else
        echo_error "[remove_packages] failed to remove '$packagesToRemove' with pacman" $?
    fi
}

gnome_tweaks() {
    local ruser_uid
    ruser_uid=$(id -u "${real_user}")
    echo "Set display scaling to 100%"
    sudo -u "${real_user}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${ruser_uid}/bus" gsettings set org.gnome.desktop.interface text-scaling-factor 1.0
    if [ -e "$user_home/.config/monitors.xml" ]; then
        echo "Copy monitors.xml to xdg (for GDM display scaling)"
        cp "$user_home"/.config/monitors.xml /etc/xdg/monitors.xml
    else
        echo "monitors.xml doesn't exist, skipping setting display scale for GDM"
    fi
    echo "Reduce volume step scale to 2"
    sudo -u "${real_user}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${ruser_uid}/bus" gsettings set org.gnome.settings-daemon.plugins.media-keys volume-step 2
    echo "Enable minimize button on windows"
    sudo -u "${real_user}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${ruser_uid}/bus" gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,close'
    echo "Set color scheme to dark"
    sudo -u "${real_user}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${ruser_uid}/bus" gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    echo "Enable log out option"
    sudo -u "${real_user}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${ruser_uid}/bus" gsettings set org.gnome.shell always-show-log-out true
}

install_gnome_extension() {
    echo "Installing AppIndicator support"
    runuser -u "${real_user}" -- pipx run gnome-extensions-cli install appindicatorsupport@rgcjonas.gmail.com
    echo "Installing Color Picker"
    runuser -u "${real_user}" -- pipx run gnome-extensions-cli install color-picker@tuberry
    local pipx=("python-pipx")
    remove_packages "${pipx[@]}"
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
isArch=$([[ $(cat /etc/os-release | grep 'ID') =~ "arch" ]] && echo true || echo false)

if ! [ "$(id -u)" = 0 ]; then
    echo_error "Archie needs to be run as root." 1
fi

if [[ $isArch == false ]]; then
    echo_error "Archie is only compatible with Arch Linux! Exiting..." 1
fi
# endChecks

echo -e "${LIGHTBLUE}--- About ---${NOCOLOR}"
echo "Archie is a simple shell script that configures vanilla Arch Linux to my linking."
echo
echo -e "${LIGHTBLUE}Features${NOCOLOR}"
echo "  - install required packages"
echo "  - debloat GNOME, tweak it, and install extensions"
echo "  - set up preferred shell and configure it"
echo -e "${LIGHTBLUE}Software${NOCOLOR}"
echo "  - Flatpak support and applications"
# echo "  - VM and container software"
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

echo_step "Setup ZSH"

echo_substep "Install ZSH and set it as the default shell"
install_packages "zsh"
chsh -s "$(which zsh)" "$real_user"
echo_substep "Install powerlevel10k and plugins"
if ! [ -e "$user_home/.zsh/powerlevel10k" ]; then
    runuser -u "$real_user" -- bash -c "git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $user_home/.zsh/powerlevel10k"
fi
powerlevelSource="source $user_home/.zsh/powerlevel10k/powerlevel10k.zsh-theme"
if !  grep -q -F "$powerlevelSource" "$user_home/.zshrc"; then
    runuser -u "$real_user" -- bash -c "echo $powerlevelSource >>~/.zshrc"
fi
if ! [ -e "$user_home/.zsh/zsh-autosuggestions" ]; then
     runuser -u "$real_user" -- bash -c "git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions $user_home/.zsh/zsh-autosuggestions"
fi
suggestionsSource="source $user_home/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
if ! grep -q -F "$suggestionsSource" "$user_home/.zshrc"; then
    runuser -u "$real_user" -- bash -c "echo $suggestionsSource >>~/.zshrc"
fi
echo_substep "Setup history and fix ZLE keybinds"
runuser -u "$real_user" -- bash -c "echo -e 'HISTFILE=~/.zsh_history\nHISTSIZE=10000\nSAVEHIST=10000' >>~/.zshrc"
if ! grep -q -F 'zle-keybindings' "$user_home/.zshrc"; then
    runuser -u "$real_user" -- bash -c 'cat >> ~/.zshrc' <<'EOF'
# zle-keybindings
typeset -g -A key

key[Home]="${terminfo[khome]}"
key[End]="${terminfo[kend]}"
key[Insert]="${terminfo[kich1]}"
key[Backspace]="${terminfo[kbs]}"
key[Delete]="${terminfo[kdch1]}"
key[Up]="${terminfo[kcuu1]}"
key[Down]="${terminfo[kcud1]}"
key[Left]="${terminfo[kcub1]}"
key[Right]="${terminfo[kcuf1]}"
key[PageUp]="${terminfo[kpp]}"
key[PageDown]="${terminfo[knp]}"
key[Shift-Tab]="${terminfo[kcbt]}"

[[ -n "${key[Home]}"      ]] && bindkey -- "${key[Home]}"       beginning-of-line
[[ -n "${key[End]}"       ]] && bindkey -- "${key[End]}"        end-of-line
[[ -n "${key[Insert]}"    ]] && bindkey -- "${key[Insert]}"     overwrite-mode
[[ -n "${key[Backspace]}" ]] && bindkey -- "${key[Backspace]}"  backward-delete-char
[[ -n "${key[Delete]}"    ]] && bindkey -- "${key[Delete]}"     delete-char
[[ -n "${key[Up]}"        ]] && bindkey -- "${key[Up]}"         up-line-or-history
[[ -n "${key[Down]}"      ]] && bindkey -- "${key[Down]}"       down-line-or-history
[[ -n "${key[Left]}"      ]] && bindkey -- "${key[Left]}"       backward-char
[[ -n "${key[Right]}"     ]] && bindkey -- "${key[Right]}"      forward-char
[[ -n "${key[PageUp]}"    ]] && bindkey -- "${key[PageUp]}"     beginning-of-buffer-or-history
[[ -n "${key[PageDown]}"  ]] && bindkey -- "${key[PageDown]}"   end-of-buffer-or-history
[[ -n "${key[Shift-Tab]}" ]] && bindkey -- "${key[Shift-Tab]}"  reverse-menu-complete

if (( ${+terminfo[smkx]} && ${+terminfo[rmkx]} )); then
    autoload -Uz add-zle-hook-widget
    function zle_application_mode_start { echoti smkx }
    function zle_application_mode_stop { echoti rmkx }
    add-zle-hook-widget -Uz zle-line-init zle_application_mode_start
    add-zle-hook-widget -Uz zle-line-finish zle_application_mode_stop
fi'
EOF
fi

echo_step "Flatpak"
echo_substep "Flatpak Support"
install_packages "flatpak"
echo_substep "Install Flatpak applications"
runuser -u "$real_user" -- flatpak install -y flathub \
    io.github.kolunmi.Bazaar \
    com.usebottles.bottles \
    me.timschneeberger.jdsp4linux \
    md.obsidian.Obsidian \
    org.gnome.Builder \
    org.qbittorrent.qBittorrent

#echo_step "Install VM and container software"
#install_packages "qemu-desktop virt-manager dnsmasq swtpm"