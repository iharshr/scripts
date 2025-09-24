#!/bin/bash
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
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

print_progress() {
    echo -e "${PURPLE}[PROGRESS]${NC} $1"
}

# Detect the distribution with more precision
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

# Get Ubuntu version for version-specific handling
get_ubuntu_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$VERSION_ID"
    else
        echo "unknown"
    fi
}

# Check if package is installed (Arch/Manjaro)
is_package_installed_arch() {
    pacman -Qi "$1" &> /dev/null
}

# Check if package is installed (Debian/Ubuntu) - improved
is_package_installed_debian() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii" || command -v "$1" &> /dev/null
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Update package lists with proper error handling
update_package_lists() {
    local distro=$1
    print_progress "Updating package lists..."
    
    if [[ "$distro" == "arch" ]]; then
        if ! sudo pacman -Sy; then
            print_error "Failed to update Arch package lists"
            return 1
        fi
    elif [[ "$distro" == "debian" ]] || [[ "$distro" == "ubuntu" ]]; then
        if ! sudo apt-get update; then
            print_error "Failed to update APT package lists"
            return 1
        fi
    fi
    return 0
}

# Display application menu with enhanced options
show_menu() {
    clear
    echo
    print_header "=== Enhanced Universal Application Installer ==="
    echo -e "${BLUE}Select applications to install:${NC}"
    echo "1. Docker CE (with Docker Compose)"
    echo "2. Nginx (with basic configuration)"
    echo "3. NVM (with LTS Node.js and npm)"
    echo "4. GVM (with latest stable Go version)"
    echo "5. Python3 (with pip3, venv, and dev tools)"
    echo "6. Vim (with enhanced configuration)"
    echo "7. Git (with common configuration)"
    echo "8. Curl & Wget (essential download tools)"
    echo "9. Development essentials (build-essential, etc.)"
    echo "10. All applications"
    echo
    echo -e "${CYAN}Instructions:${NC}"
    echo "• Enter a single number (e.g., 1)"
    echo "• Enter multiple numbers separated by spaces (e.g., 1 2 3)"
    echo "• Enter 10 to install all applications"
    echo "• Enter 'q' to quit"
    echo
}

# Get user selection with improved validation
get_user_selection() {
    while true; do
        echo -e -n "${YELLOW}Enter your selection: ${NC}"
        read -r selection
        
        # Handle empty input
        if [[ -z "$selection" ]]; then
            print_error "Please enter a selection."
            continue
        fi
        
        # Handle quit
        if [[ "$selection" == "q" || "$selection" == "Q" ]]; then
            print_status "Exiting..."
            exit 0
        fi
        
        # Validate input - allow numbers 1-10 and spaces
        if [[ "$selection" =~ ^[1-9]([[:space:]]+[1-9])*$|^10([[:space:]]+[1-9])*$|^[1-9]([[:space:]]+10)*$ ]]; then
            echo "$selection"
            return 0
        else
            print_error "Invalid selection. Please enter numbers 1-10 separated by spaces, or 'q' to quit."
        fi
    done
}

# Install Docker CE with enhanced Ubuntu support
install_docker() {
    local distro=$1
    print_status "Installing Docker CE with Docker Compose..."
    
    if [[ "$distro" == "arch" ]]; then
        if is_package_installed_arch "docker"; then
            print_warning "Docker is already installed"
        else
            sudo pacman -S docker docker-compose --noconfirm --needed
            sudo systemctl enable docker
            sudo systemctl start docker
            sudo usermod -aG docker "$USER"
            print_success "Docker CE installed successfully"
        fi
    elif [[ "$distro" == "debian" ]] || [[ "$distro" == "ubuntu" ]]; then
        if command_exists docker; then
            print_warning "Docker is already installed"
        else
            # Remove old versions
            sudo apt-get remove docker docker-engine docker.io containerd runc -y 2>/dev/null || true
            
            # Install prerequisites
            sudo apt-get install -y \
                ca-certificates \
                curl \
                gnupg \
                lsb-release \
                apt-transport-https \
                software-properties-common
            
            # Add Docker's official GPG key
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            
            # Add Docker repository
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Update and install Docker
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            
            # Start and enable Docker
            sudo systemctl enable docker
            sudo systemctl start docker
            sudo usermod -aG docker "$USER"
            
            # Install docker-compose standalone for compatibility
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
            
            print_success "Docker CE with Docker Compose installed successfully"
        fi
    fi
}

# Install Nginx with enhanced configuration
install_nginx() {
    local distro=$1
    print_status "Installing Nginx..."
    
    if [[ "$distro" == "arch" ]]; then
        if is_package_installed_arch "nginx"; then
            print_warning "Nginx is already installed"
        else
            sudo pacman -S nginx --noconfirm --needed
            sudo systemctl enable nginx
            print_success "Nginx installed successfully"
        fi
    elif [[ "$distro" == "debian" ]] || [[ "$distro" == "ubuntu" ]]; then
        if is_package_installed_debian "nginx"; then
            print_warning "Nginx is already installed"
        else
            sudo apt-get install -y nginx
            sudo systemctl enable nginx
            
            # Configure firewall if ufw is available
            if command_exists ufw; then
                sudo ufw allow 'Nginx Full' 2>/dev/null || true
            fi
            
            print_success "Nginx installed successfully"
        fi
    fi
}

# Install NVM with enhanced Node.js setup
install_nvm() {
    print_status "Installing NVM with LTS Node.js..."
    
    if [ -d "$HOME/.nvm" ] || command_exists nvm; then
        print_warning "NVM is already installed"
    else
        # Install NVM (latest version)
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        
        # Source NVM for current session
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        
        # Install and configure Node.js
        if command_exists nvm; then
            nvm install --lts
            nvm use --lts
            nvm alias default lts/*
            
            # Install commonly used global packages
            npm install -g npm@latest
            npm install -g yarn pm2 nodemon
            
            print_success "NVM with LTS Node.js and essential packages installed successfully"
        else
            print_error "NVM installation failed"
        fi
    fi
}

# Install GVM with enhanced Go setup
install_gvm() {
    print_status "Installing GVM with latest Go version..."
    
    if [ -d "$HOME/.gvm" ] || command_exists gvm; then
        print_warning "GVM is already installed"
    else
        # Install dependencies
        local distro=$(detect_distro)
        if [[ "$distro" == "arch" ]]; then
            sudo pacman -S git mercurial make binutils bison gcc --noconfirm --needed
        elif [[ "$distro" == "debian" ]] || [[ "$distro" == "ubuntu" ]]; then
            sudo apt-get install -y curl git mercurial make binutils bison gcc build-essential
        fi
        
        # Install GVM
        bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
        
        # Source GVM for current session
        [[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"
        
        # Install and configure Go
        if command_exists gvm; then
            # Get the latest stable Go version
            local latest_go="go1.21.5"  # This should be updated regularly
            gvm install "$latest_go" -B
            gvm use "$latest_go" --default
            
            # Set up Go workspace
            mkdir -p "$HOME/go/{bin,src,pkg}"
            
            print_success "GVM with Go $latest_go installed successfully"
        else
            print_error "GVM installation failed"
        fi
    fi
}

# Install Python3 with enhanced development setup
install_python() {
    local distro=$1
    print_status "Installing Python3 development environment..."
    
    if [[ "$distro" == "arch" ]]; then
        local packages=("python" "python-pip" "python-virtualenv")
        local packages_needed=()
        
        for pkg in "${packages[@]}"; do
            if ! is_package_installed_arch "$pkg"; then
                packages_needed+=("$pkg")
            fi
        done
        
        if [ ${#packages_needed[@]} -gt 0 ]; then
            sudo pacman -S "${packages_needed[@]}" --noconfirm --needed
            print_success "Python3 development environment installed successfully"
        else
            print_warning "Python3 development environment is already installed"
        fi
        
    elif [[ "$distro" == "debian" ]] || [[ "$distro" == "ubuntu" ]]; then
        local packages=("python3" "python3-pip" "python3-venv" "python3-dev" "python3-setuptools")
        local packages_needed=()
        
        for pkg in "${packages[@]}"; do
            if ! is_package_installed_debian "$pkg"; then
                packages_needed+=("$pkg")
            fi
        done
        
        if [ ${#packages_needed[@]} -gt 0 ]; then
            sudo apt-get install -y "${packages_needed[@]}"
            
            # Create symlink for python if it doesn't exist
            if ! command_exists python && command_exists python3; then
                sudo ln -sf /usr/bin/python3 /usr/local/bin/python 2>/dev/null || true
            fi
            
            # Upgrade pip
            python3 -m pip install --user --upgrade pip
            
            print_success "Python3 development environment installed successfully"
        else
            print_warning "Python3 development environment is already installed"
        fi
    fi
}

# Install Vim with enhanced configuration
install_vim() {
    local distro=$1
    print_status "Installing Vim..."
    
    if [[ "$distro" == "arch" ]]; then
        if is_package_installed_arch "vim"; then
            print_warning "Vim is already installed"
        else
            sudo pacman -S vim --noconfirm --needed
            print_success "Vim installed successfully"
        fi
    elif [[ "$distro" == "debian" ]] || [[ "$distro" == "ubuntu" ]]; then
        if is_package_installed_debian "vim"; then
            print_warning "Vim is already installed"
        else
            sudo apt-get install -y vim vim-common vim-runtime
            print_success "Vim installed successfully"
        fi
    fi
}

# Install Git with configuration
install_git() {
    local distro=$1
    print_status "Installing Git..."
    
    if [[ "$distro" == "arch" ]]; then
        if is_package_installed_arch "git"; then
            print_warning "Git is already installed"
        else
            sudo pacman -S git --noconfirm --needed
            print_success "Git installed successfully"
        fi
    elif [[ "$distro" == "debian" ]] || [[ "$distro" == "ubuntu" ]]; then
        if is_package_installed_debian "git"; then
            print_warning "Git is already installed"
        else
            sudo apt-get install -y git
            print_success "Git installed successfully"
        fi
    fi
}

# Install essential download tools
install_download_tools() {
    local distro=$1
    print_status "Installing Curl & Wget..."
    
    if [[ "$distro" == "arch" ]]; then
        local packages=("curl" "wget")
        local packages_needed=()
        
        for pkg in "${packages[@]}"; do
            if ! is_package_installed_arch "$pkg"; then
                packages_needed+=("$pkg")
            fi
        done
        
        if [ ${#packages_needed[@]} -gt 0 ]; then
            sudo pacman -S "${packages_needed[@]}" --noconfirm --needed
            print_success "Download tools installed successfully"
        else
            print_warning "Download tools are already installed"
        fi
        
    elif [[ "$distro" == "debian" ]] || [[ "$distro" == "ubuntu" ]]; then
        local packages=("curl" "wget")
        local packages_needed=()
        
        for pkg in "${packages[@]}"; do
            if ! is_package_installed_debian "$pkg"; then
                packages_needed+=("$pkg")
            fi
        done
        
        if [ ${#packages_needed[@]} -gt 0 ]; then
            sudo apt-get install -y "${packages_needed[@]}"
            print_success "Download tools installed successfully"
        else
            print_warning "Download tools are already installed"
        fi
    fi
}

# Install development essentials
install_dev_essentials() {
    local distro=$1
    print_status "Installing development essentials..."
    
    if [[ "$distro" == "arch" ]]; then
        local packages=("base-devel" "cmake" "pkg-config")
        local packages_needed=()
        
        for pkg in "${packages[@]}"; do
            if ! is_package_installed_arch "$pkg"; then
                packages_needed+=("$pkg")
            fi
        done
        
        if [ ${#packages_needed[@]} -gt 0 ]; then
            sudo pacman -S "${packages_needed[@]}" --noconfirm --needed
            print_success "Development essentials installed successfully"
        else
            print_warning "Development essentials are already installed"
        fi
        
    elif [[ "$distro" == "debian" ]] || [[ "$distro" == "ubuntu" ]]; then
        local packages=("build-essential" "cmake" "pkg-config" "libtool" "autoconf" "automake")
        local packages_needed=()
        
        for pkg in "${packages[@]}"; do
            if ! is_package_installed_debian "$pkg"; then
                packages_needed+=("$pkg")
            fi
        done
        
        if [ ${#packages_needed[@]} -gt 0 ]; then
            sudo apt-get install -y "${packages_needed[@]}"
            print_success "Development essentials installed successfully"
        else
            print_warning "Development essentials are already installed"
        fi
    fi
}

# Process user selection with enhanced validation
process_selection() {
    local selection="$1"
    local distro="$2"
    
    # Convert selection to array
    read -ra selected_apps <<< "$selection"
    
    # Check if "all" is selected
    for app in "${selected_apps[@]}"; do
        if [[ "$app" == "10" ]]; then
            selected_apps=(1 2 3 4 5 6 7 8 9)
            break
        fi
    done
    
    # Remove duplicates and sort
    IFS=" " read -r -a selected_apps <<< "$(echo "${selected_apps[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')"
    
    print_header "Installing selected applications..."
    
    # Update package lists first
    if ! update_package_lists "$distro"; then
        print_error "Failed to update package lists. Some installations may fail."
    fi
    
    for app in "${selected_apps[@]}"; do
        case $app in
            1) install_docker "$distro" ;;
            2) install_nginx "$distro" ;;
            3) install_nvm ;;
            4) install_gvm ;;
            5) install_python "$distro" ;;
            6) install_vim "$distro" ;;
            7) install_git "$distro" ;;
            8) install_download_tools "$distro" ;;
            9) install_dev_essentials "$distro" ;;
        esac
        echo
    done
}

# Main function with enhanced error handling
main() {
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root. Please run as a regular user."
        exit 1
    fi
    
    print_header "Enhanced Universal Application Installer for Ubuntu/Debian and Manjaro/Arch"
    
    # Detect distribution
    distro=$(detect_distro)
    
    if [[ "$distro" == "unknown" ]]; then
        print_error "Unsupported distribution. This script supports Manjaro/Arch, Ubuntu, and Debian systems."
        exit 1
    fi
    
    print_status "Detected distribution: $distro"
    
    if [[ "$distro" == "ubuntu" ]]; then
        ubuntu_version=$(get_ubuntu_version)
        print_status "Ubuntu version: $ubuntu_version"
    fi
    
    # Check for sudo access
    if ! sudo -n true 2>/dev/null; then
        print_status "This script requires sudo access. You may be prompted for your password."
        if ! sudo -v; then
            print_error "Failed to obtain sudo access. Exiting."
            exit 1
        fi
    fi
    
    # Show menu and get selection
    show_menu
    selection=$(get_user_selection)
    
    # Process the selection
    process_selection "$selection" "$distro"
    
    print_success "Installation process completed!"
    echo
    print_header "Post-installation notes:"
    echo "• If Docker was installed, you need to log out and log back in for group changes to take effect"
    echo "• For NVM, restart your terminal or run: source ~/.bashrc"
    echo "• For GVM, restart your terminal or run: source ~/.gvm/scripts/gvm"
    echo "• Some services may need to be started manually: sudo systemctl start <service-name>"
    echo "• Check service status with: sudo systemctl status <service-name>"
    echo "• View installed packages with: apt list --installed (Ubuntu/Debian) or pacman -Q (Arch)"
}

# Run the main function
main "$@"
