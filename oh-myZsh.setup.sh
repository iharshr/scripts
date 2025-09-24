#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

print_header() {
    echo -e "${CYAN}[HEADER]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root. Please run as a regular user."
        exit 1
    fi
}

# Detect the distribution with better precision
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "manjaro" ]] || [[ "$ID_LIKE" == *"arch"* ]]; then
            echo "arch"
        elif [[ "$ID" == "ubuntu" ]]; then
            echo "ubuntu"
        elif [[ "$ID" == "debian" ]] || [[ "$ID_LIKE" == *"debian"* ]]; then
            echo "debian"
        else
            echo "unknown"
        fi
    else
        echo "unknown"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check if package is installed (Arch/Manjaro)
is_package_installed_arch() {
    pacman -Qi "$1" &> /dev/null
}

# Check if package is installed (Debian/Ubuntu) - improved
is_package_installed_debian() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii" || command_exists "$1"
}

# Install packages based on distribution
install_packages() {
    local distro=$1
    
    print_header "Installing ZSH and dependencies..."
    
    if [[ "$distro" == "arch" ]]; then
        print_status "Installing packages for Manjaro/Arch..."
        
        # Update package database
        sudo pacman -Sy
        
        local packages=("zsh" "git" "curl" "wget")
        local packages_needed=()
        
        for pkg in "${packages[@]}"; do
            if ! is_package_installed_arch "$pkg"; then
                packages_needed+=("$pkg")
            else
                print_warning "$pkg is already installed"
            fi
        done
        
        if [ ${#packages_needed[@]} -gt 0 ]; then
            print_status "Installing: ${packages_needed[*]}"
            sudo pacman -S "${packages_needed[@]}" --noconfirm --needed
            print_success "Packages installed successfully"
        else
            print_status "All required packages are already installed"
        fi
        
    elif [[ "$distro" == "ubuntu" ]] || [[ "$distro" == "debian" ]]; then
        print_status "Installing packages for $distro..."
        
        # Update package list
        sudo apt update
        
        local packages=("zsh" "git" "curl" "wget")
        local packages_needed=()
        
        for pkg in "${packages[@]}"; do
            if ! is_package_installed_debian "$pkg"; then
                packages_needed+=("$pkg")
            else
                print_warning "$pkg is already installed"
            fi
        done
        
        # Install packages if needed
        if [ ${#packages_needed[@]} -gt 0 ]; then
            print_status "Installing: ${packages_needed[*]}"
            sudo apt install "${packages_needed[@]}" -y
            print_success "Packages installed successfully"
        else
            print_status "All required packages are already installed"
        fi
    fi
}

# Check if Oh My ZSH is already installed
is_ohmyzsh_installed() {
    [ -d "$HOME/.oh-my-zsh" ]
}

# Install Oh My ZSH with better error handling
install_ohmyzsh() {
    if is_ohmyzsh_installed; then
        print_warning "Oh My ZSH is already installed"
        return 0
    fi
    
    print_status "Installing Oh My ZSH..."
    
    # Create backup of existing .zshrc if it exists
    if [ -f "$HOME/.zshrc" ]; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
        print_status "Backup of existing .zshrc created"
    fi
    
    # Install Oh My ZSH with timeout and error handling
    if command_exists curl; then
        if timeout 60 sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
            print_success "Oh My ZSH installed successfully"
        else
            print_error "Failed to install Oh My ZSH via curl"
            return 1
        fi
    elif command_exists wget; then
        if timeout 60 sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
            print_success "Oh My ZSH installed successfully"
        else
            print_error "Failed to install Oh My ZSH via wget"
            return 1
        fi
    else
        print_error "Neither curl nor wget is available"
        return 1
    fi
}

# Check if plugin is already installed
is_plugin_installed() {
    local plugin_name=$1
    [ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$plugin_name" ]
}

# Install ZSH plugins with FIXED URL parsing
install_plugins() {
    print_header "Installing ZSH plugins..."
    
    # FIXED: Use proper array format with complete URLs
    local plugins=(
        "zsh-autosuggestions"
        "zsh-syntax-highlighting" 
        "fast-syntax-highlighting"
        "zsh-autocomplete"
    )
    
    local plugin_urls=(
        "https://github.com/zsh-users/zsh-autosuggestions.git"
        "https://github.com/zsh-users/zsh-syntax-highlighting.git"
        "https://github.com/zdharma-continuum/fast-syntax-highlighting.git"
        "https://github.com/marlonrichert/zsh-autocomplete.git"
    )
    
    local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    
    # Ensure plugins directory exists
    mkdir -p "$plugin_dir"
    
    # Install plugins using index-based approach
    for i in "${!plugins[@]}"; do
        local plugin_name="${plugins[$i]}"
        local plugin_url="${plugin_urls[$i]}"
        
        if is_plugin_installed "$plugin_name"; then
            print_warning "$plugin_name is already installed"
        else
            print_status "Installing $plugin_name..."
            print_status "Cloning from: $plugin_url"
            
            # Use timeout and better error handling with proper URL
            if timeout 60 git clone --depth 1 "$plugin_url" "$plugin_dir/$plugin_name"; then
                print_success "$plugin_name installed successfully"
            else
                print_error "Failed to install $plugin_name"
                # Continue with other plugins instead of failing completely
                continue
            fi
        fi
    done
}

# Configure .zshrc with backup and validation
configure_zshrc() {
    print_header "Configuring .zshrc..."
    
    if [ ! -f "$HOME/.zshrc" ]; then
        print_error ".zshrc file not found. Oh My ZSH installation might have failed."
        return 1
    fi
    
    # Check if plugins are already configured
    if grep -q "plugins=(.*zsh-autosuggestions.*)" "$HOME/.zshrc"; then
        print_warning "Custom plugins are already configured in .zshrc"
        return 0
    fi
    
    # Create backup
    cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
    print_status "Backup of .zshrc created"
    
    # Update plugins line with improved sed command
    if grep -q "^plugins=" "$HOME/.zshrc"; then
        sed -i 's/^plugins=(.*)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete)/' "$HOME/.zshrc"
    else
        # Add plugins line if it doesn't exist
        echo "plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete)" >> "$HOME/.zshrc"
    fi
    
    # Add useful configurations
    cat >> "$HOME/.zshrc" << 'EOF'

# Custom ZSH configurations
# Enable case-insensitive completion
CASE_SENSITIVE="false"

# Enable command auto-correction
ENABLE_CORRECTION="true"

# Display red dots whilst waiting for completion
COMPLETION_WAITING_DOTS="true"

# Disable marking untracked files as dirty (faster git status)
DISABLE_UNTRACKED_FILES_DIRTY="true"

# History settings
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
EOF
    
    print_success ".zshrc configured successfully"
}

# FIXED: Change default shell with proper PAM handling
change_shell() {
    local current_shell
    current_shell=$(basename "$SHELL")
    
    if [[ "$current_shell" == "zsh" ]]; then
        print_warning "ZSH is already the default shell"
        return 0
    fi
    
    print_status "Changing default shell to ZSH..."
    
    # Get the path to zsh
    local zsh_path
    zsh_path=$(which zsh)
    
    if [[ -z "$zsh_path" ]]; then
        print_error "ZSH not found in PATH"
        return 1
    fi
    
    # Check if zsh is in /etc/shells
    if ! grep -q "^$zsh_path$" /etc/shells; then
        print_status "Adding zsh to /etc/shells..."
        echo "$zsh_path" | sudo tee -a /etc/shells > /dev/null
    fi
    
    # FIXED: Try different approaches for chsh
    print_status "Attempting to change shell using multiple methods..."
    
    # Method 1: Standard chsh
    if chsh -s "$zsh_path" 2>/dev/null; then
        print_success "Default shell changed to ZSH successfully (method 1)"
        return 0
    fi
    
    # Method 2: Try with sudo (sometimes needed)
    if sudo chsh -s "$zsh_path" "$USER" 2>/dev/null; then
        print_success "Default shell changed to ZSH successfully (method 2)"
        return 0
    fi
    
    # Method 3: Direct usermod (fallback)
    if sudo usermod -s "$zsh_path" "$USER" 2>/dev/null; then
        print_success "Default shell changed to ZSH successfully (method 3)"
        return 0
    fi
    
    # Method 4: Manual /etc/passwd editing (last resort)
    print_warning "Automatic shell change failed. Attempting manual method..."
    
    # Create a temporary script to edit /etc/passwd
    local temp_script="/tmp/change_shell_$$"
    cat > "$temp_script" << EOF
#!/bin/bash
sed -i 's|^$USER:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*$|$USER:\2:\3:\4:\5:\6:$zsh_path|' /etc/passwd
EOF
    
    chmod +x "$temp_script"
    
    if sudo "$temp_script" 2>/dev/null; then
        rm -f "$temp_script"
        print_success "Default shell changed to ZSH successfully (manual method)"
        return 0
    fi
    
    rm -f "$temp_script"
    
    # If all methods fail, provide manual instructions
    print_error "All automatic methods failed. Please change your shell manually:"
    echo -e "${YELLOW}Run one of these commands:${NC}"
    echo -e "  ${BLUE}sudo chsh -s $zsh_path $USER${NC}"
    echo -e "  ${BLUE}sudo usermod -s $zsh_path $USER${NC}"
    echo -e "Or edit ${BLUE}/etc/passwd${NC} and change your shell entry to: ${BLUE}$zsh_path${NC}"
    
    return 1
}

# Verify installation
verify_installation() {
    print_header "Verifying installation..."
    
    # Check ZSH installation
    if command_exists zsh; then
        local zsh_version
        zsh_version=$(zsh --version | head -n1)
        print_success "ZSH installed: $zsh_version"
    else
        print_error "ZSH installation failed"
        return 1
    fi
    
    # Check Oh My ZSH
    if [ -d "$HOME/.oh-my-zsh" ]; then
        print_success "Oh My ZSH installed successfully"
    else
        print_error "Oh My ZSH installation failed"
        return 1
    fi
    
    # Check plugins
    local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    local installed_plugins=0
    local total_plugins=4
    
    for plugin in zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete; do
        if [ -d "$plugin_dir/$plugin" ]; then
            ((installed_plugins++))
            print_status "✓ $plugin installed"
        else
            print_warning "✗ $plugin not installed"
        fi
    done
    
    print_status "Plugins installed: $installed_plugins/$total_plugins"
    
    print_success "Installation verification completed"
}

# Main execution
main() {
    print_header "Starting ZSH installation and configuration..."
    
    # Check if running as root
    check_root
    
    # Detect distribution
    local distro
    distro=$(detect_distro)
    
    if [[ "$distro" == "unknown" ]]; then
        print_error "Unsupported distribution. This script supports Manjaro/Arch, Ubuntu, and Debian systems."
        exit 1
    fi
    
    print_status "Detected distribution: $distro"
    
    # Install packages
    if ! install_packages "$distro"; then
        print_error "Package installation failed"
        exit 1
    fi
    
    # Install Oh My ZSH
    if ! install_ohmyzsh; then
        print_error "Oh My ZSH installation failed"
        exit 1
    fi
    
    # Install plugins
    install_plugins
    
    # Configure .zshrc
    if ! configure_zshrc; then
        print_error "ZSH configuration failed"
        exit 1
    fi
    
    # Change default shell (with improved error handling)
    change_shell
    
    # Verify installation
    verify_installation
    
    print_success "ZSH installation and configuration completed!"
    echo
    print_header "Next steps:"
    echo -e "${BLUE}1.${NC} Restart your terminal or run: ${YELLOW}source ~/.zshrc${NC}"
    echo -e "${BLUE}2.${NC} Log out and log back in for shell changes to take effect"
    echo -e "${BLUE}3.${NC} If shell change failed, run manually: ${YELLOW}sudo chsh -s \$(which zsh) \$USER${NC}"
    echo -e "${BLUE}4.${NC} Enjoy your enhanced ZSH experience!"
}

# Run main function with error handling
if ! main "$@"; then
    print_error "Script execution failed"
    exit 1
fi
