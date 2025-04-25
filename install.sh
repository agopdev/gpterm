#!/bin/bash

get_actual_user(){
    local user=${SUDO_USER:-$USER}
    echo "$user"
}

install_script() {
    echo "Installing gpterm in /usr/local/bin/..."
    
    local user=$(get_actual_user)
    local user_home=$(eval echo ~$user)
    
    sudo cp ./src/gpterm.sh /usr/local/bin/gpterm

    sudo chmod +x /usr/local/bin/gpterm

    mkdir -p "$user_home/.config/gpterm"
    mkdir -p "$user_home/.local/share/gpterm/chats_history"

    cp ./src/config.json "$user_home/.config/gpterm/config.json"

    sudo chown -R "$user" "$user_home/.config/gpterm"
    sudo chown -R "$user" "$user_home/.local/share/gpterm/chats_history"

    echo "Installation completed! Try executing gpterm --help"
}


uninstall_script() {    
    echo "Uninstalling gpterm..."

    local user=$(get_actual_user)
    local user_home=$(eval echo ~$user)

    sudo rm /usr/local/bin/gpterm
    sudo rm -rf "$user_home/.config/gpterm"
    sudo rm -rf "$user_home/.local/share/gpterm"

    echo "gpterm completely removed!"
}

# Check if install.sh was executed as sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please execute install.sh as sudo."
    exit 1
fi

# Check if is installing or uninstalling gpterm
case "$1" in
    --install)
        install_script
        ;;
    --uninstall)
        uninstall_script
        ;;
    *)
        echo "Usage: $0 [ --install | --uninstall ]"
        exit 1
        ;;
esac