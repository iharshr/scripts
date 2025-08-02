#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect the distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "manjaro" ]] || [[ "$ID_LIKE" == *"arch"* ]]; then
            echo "arch"
        elif [[ "$ID" == "ubuntu" ]] || [[ "$ID" == "debian" ]] || [[ "$ID_LIKE" == *"debian"* ]]; then
            echo "debian"
        else
            echo "unknown"
        fi
    else
        echo "unknown"
    fi
}

# Check if package is installed (Arch/Manjaro)
is_package_installed_arch() {
    pacman -Qi "$1" &> /dev/null
}

# Check if package is installed (Debian/Ubuntu)
is_package_installed_debian() {
    dpkg -l | grep -q "^ii  $1 "
}

# Install packages based on distribution
install_packages() {
    local distro=$1
    
    if [[ "$distro" == "arch" ]]; then
        print_status "Installing ZSH and related packages for Manjaro/Arch..."
        
        # Check and install zsh
        if ! is_package_installed_arch "zsh"; then
            print_status "Installing zsh..."
            sudo pacman -S zsh --noconfirm
        else
            print_warning "zsh is already installed"
        fi
        
        # Check and install git (needed for plugins)
        if ! is_package_installed_arch "git"; then
            print_status "Installing git..."
            sudo pacman -S git --noconfirm
        else
            print_warning "git is already installed"
        fi
        
        # Check and install curl (needed for Oh My ZSH)
        if ! is_package_installed_arch "curl"; then
            print_status "Installing curl..."
            sudo pacman -S curl --noconfirm
        else
            print_warning "curl is already installed"
        fi
        
    elif [[ "$distro" == "debian" ]]; then
        print_status "Installing ZSH and related packages for Debian/Ubuntu..."
        
        # Update package list
        sudo apt update
        
        packages_to_install=()
        
        # Check zsh
        if ! is_package_installed_debian "zsh"; then
            packages_to_install+=("zsh")
        else
            print_warning "zsh is already installed"
        fi
        
        # Check zsh-autosuggestions
        if ! is_package_installed_debian "zsh-autosuggestions"; then
            packages_to_install+=("zsh-autosuggestions")
        else
            print_warning "zsh-autosuggestions is already installed"
        fi
        
        # Check zsh-syntax-highlighting
        if ! is_package_installed_debian "zsh-syntax-highlighting"; then
            packages_to_install+=("zsh-syntax-highlighting")
        else
            print_warning "zsh-syntax-highlighting is already installed"
        fi
        
        # Check git
        if ! is_package_installed_debian "git"; then
            packages_to_install+=("git")
        else
            print_warning "git is already installed"
        fi
        
        # Check curl
        if ! is_package_installed_debian "curl"; then
            packages_to_install+=("curl")
        else
            print_warning "curl is already installed"
        fi
        
        # Install packages if needed
        if [ ${#packages_to_install[@]} -gt 0 ]; then
            print_status "Installing: ${packages_to_install[*]}"
            sudo apt install "${packages_to_install[@]}" -y
        else
            print_status "All required packages are already installed"
        fi
    fi
}

# Check if Oh My ZSH is already installed
is_ohmyzsh_installed() {
    [ -d "$HOME/.oh-my-zsh" ]
}

# Install Oh My ZSH
install_ohmyzsh() {
    if is_ohmyzsh_installed; then
        print_warning "Oh My ZSH is already installed"
        return 0
    fi
    
    print_status "Installing Oh My ZSH..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    
    if [ $? -eq 0 ]; then
        print_status "Oh My ZSH installed successfully"
    else
        print_error "Failed to install Oh My ZSH"
        exit 1
    fi
}

# Check if plugin is already installed
is_plugin_installed() {
    local plugin_name=$1
    [ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$plugin_name" ]
}

# Install ZSH plugins
install_plugins() {
    print_status "Installing ZSH plugins..."
    
    local plugins=(
        "zsh-autosuggestions:https://github.com/zsh-users/zsh-autosuggestions.git"
        "zsh-syntax-highlighting:https://github.com/zsh-users/zsh-syntax-highlighting.git"
        "fast-syntax-highlighting:https://github.com/zdharma-continuum/fast-syntax-highlighting.git"
        "zsh-autocomplete:https://github.com/marlonrichert/zsh-autocomplete.git"
    )
    
    for plugin_info in "${plugins[@]}"; do
        local plugin_name="${plugin_info%%:*}"
        local plugin_url="${plugin_info##*:}"
        
        if is_plugin_installed "$plugin_name"; then
            print_warning "$plugin_name is already installed"
        else
            print_status "Installing $plugin_name..."
            if [[ "$plugin_name" == "zsh-autocomplete" ]]; then
                git clone --depth 1 "$plugin_url" "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$plugin_name"
            else
                git clone "$plugin_url" "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$plugin_name"
            fi
            
            if [ $? -eq 0 ]; then
                print_status "$plugin_name installed successfully"
            else
                print_error "Failed to install $plugin_name"
            fi
        fi
    done
}

# Configure .zshrc
configure_zshrc() {
    print_status "Configuring .zshrc..."
    
    if [ ! -f "$HOME/.zshrc" ]; then
        print_error ".zshrc file not found. Oh My ZSH installation might have failed."
        exit 1
    fi
    
    # Check if plugins are already configured
    if grep -q "plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete)" "$HOME/.zshrc"; then
        print_warning "Plugins are already configured in .zshrc"
    else
        # Backup original .zshrc
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
        print_status "Backup of .zshrc created"
        
        # Update plugins line
        sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete)/' "$HOME/.zshrc"
        print_status ".zshrc configured successfully"
    fi
}

# Change default shell
change_shell() {
    current_shell=$(basename "$SHELL")
    
    if [[ "$current_shell" == "zsh" ]]; then
        print_warning "ZSH is already the default shell"
    else
        print_status "Changing default shell to ZSH..."
        chsh -s "$(which zsh)"
        
        if [ $? -eq 0 ]; then
            print_status "Default shell changed to ZSH successfully"
        else
            print_error "Failed to change default shell. You may need to run 'chsh -s \$(which zsh)' manually"
        fi
    fi
}

# Main execution
main() {
    print_status "Starting ZSH installation and configuration..."
    
    # Detect distribution
    distro=$(detect_distro)
    
    if [[ "$distro" == "unknown" ]]; then
        print_error "Unsupported distribution. This script supports Manjaro/Arch and Debian/Ubuntu systems."
        exit 1
    fi
    
    print_status "Detected distribution: $distro"
    
    # Install packages
    install_packages "$distro"
    
    # Install Oh My ZSH
    install_ohmyzsh
    
    # Install plugins
    install_plugins
    
    # Configure .zshrc
    configure_zshrc
    
    # Change default shell
    change_shell
    
    print_status "Installation completed successfully!"
    echo -e "${GREEN}Please restart your terminal or run 'source ~/.zshrc' to apply changes.${NC}"
    echo -e "${YELLOW}Note: You may need to log out and log back in for the shell change to take effect.${NC}"
}

# Run main function
main "$@"
