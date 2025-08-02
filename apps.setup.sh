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
    dpkg -l | grep -q "^ii  $1 " || command -v "$1" &> /dev/null
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Display application menu
show_menu() {
    clear
    echo
    print_header "=== Application Installer ==="
    echo -e "${BLUE}Select applications to install:${NC}"
    echo "1. Docker CE"
    echo "2. Nginx"
    echo "3. NVM (with LTS Node.js)"
    echo "4. GVM (with latest Go version)"
    echo "5. Python3 with pip3"
    echo "6. Vim"
    echo "7. All applications"
    echo
    echo -e "${CYAN}Instructions:${NC}"
    echo "• Enter a single number (e.g., 1)"
    echo "• Enter multiple numbers separated by spaces (e.g., 1 2 3)"
    echo "• Enter 7 to install all applications"
    echo "• Enter 'q' to quit"
    echo
}

# Get user selection with proper input handling
get_user_selection() {
    while true; do
        echo -e -n "${YELLOW}Enter your selection: ${NC}"
        read selection
        
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
        
        # Validate input - allow numbers 1-7 and spaces
        if [[ "$selection" =~ ^[1-7]([[:space:]]+[1-7])*$ ]]; then
            echo "$selection"
            return 0
        else
            print_error "Invalid selection. Please enter numbers 1-7 separated by spaces, or 'q' to quit."
        fi
    done
}

# Install Docker CE
install_docker() {
    local distro=$1
    print_status "Installing Docker CE..."
    
    if [[ "$distro" == "arch" ]]; then
        if is_package_installed_arch "docker"; then
            print_warning "Docker is already installed"
        else
            sudo pacman -Sy
            sudo pacman -S docker docker-compose --noconfirm --needed
            sudo systemctl enable docker
            sudo systemctl start docker
            sudo usermod -aG docker "$USER"
            print_success "Docker CE installed successfully"
        fi
    elif [[ "$distro" == "debian" ]]; then
        if command_exists docker; then
            print_warning "Docker is already installed"
        else
            # Remove old versions
            sudo apt-get remove docker docker-engine docker.io containerd runc -y 2>/dev/null || true
            
            # Update apt package index
            sudo apt-get update
            
            # Install packages to allow apt to use a repository over HTTPS
            sudo apt-get install ca-certificates curl gnupg lsb-release -y
            
            # Add Docker's official GPG key
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            
            # Set up the repository
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker Engine
            sudo apt-get update
            sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
            
            # Start and enable Docker
            sudo systemctl enable docker
            sudo systemctl start docker
            sudo usermod -aG docker "$USER"
            print_success "Docker CE installed successfully"
        fi
    fi
}

# Install Nginx
install_nginx() {
    local distro=$1
    print_status "Installing Nginx..."
    
    if [[ "$distro" == "arch" ]]; then
        if is_package_installed_arch "nginx"; then
            print_warning "Nginx is already installed"
        else
            sudo pacman -Sy
            sudo pacman -S nginx --noconfirm --needed
            sudo systemctl enable nginx
            print_success "Nginx installed successfully"
        fi
    elif [[ "$distro" == "debian" ]]; then
        if is_package_installed_debian "nginx"; then
            print_warning "Nginx is already installed"
        else
            sudo apt-get update
            sudo apt-get install nginx -y
            sudo systemctl enable nginx
            print_success "Nginx installed successfully"
        fi
    fi
}

# Install NVM with LTS Node.js
install_nvm() {
    print_status "Installing NVM with LTS Node.js..."
    
    if [ -d "$HOME/.nvm" ] || command_exists nvm; then
        print_warning "NVM is already installed"
    else
        # Install NVM
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        
        # Source NVM
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        
        # Install and use LTS Node.js
        nvm install --lts
        nvm use --lts
        nvm alias default lts/*
        
        print_success "NVM with LTS Node.js installed successfully"
    fi
}

# Install GVM with latest Go version
install_gvm() {
    print_status "Installing GVM with latest Go version..."
    
    if [ -d "$HOME/.gvm" ] || command_exists gvm; then
        print_warning "GVM is already installed"
    else
        # Install dependencies
        local distro=$(detect_distro)
        if [[ "$distro" == "arch" ]]; then
            sudo pacman -S git mercurial make binutils bison gcc --noconfirm --needed
        elif [[ "$distro" == "debian" ]]; then
            sudo apt-get install curl git mercurial make binutils bison gcc build-essential -y
        fi
        
        # Install GVM
        bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
        
        # Source GVM
        [[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"
        
        # Install and use latest Go version
        if command_exists gvm; then
            local latest_go="go1.21.5"  # Update this to the actual latest version
            gvm install "$latest_go" -B
            gvm use "$latest_go" --default
            print_success "GVM with Go $latest_go installed successfully"
        else
            print_error "GVM installation failed"
        fi
    fi
}

# Install Python3 with pip3
install_python() {
    local distro=$1
    print_status "Installing Python3 with pip3..."
    
    if [[ "$distro" == "arch" ]]; then
        local packages_needed=()
        if ! is_package_installed_arch "python"; then
            packages_needed+=("python")
        fi
        if ! is_package_installed_arch "python-pip"; then
            packages_needed+=("python-pip")
        fi
        
        if [ ${#packages_needed[@]} -gt 0 ]; then
            sudo pacman -Sy
            sudo pacman -S "${packages_needed[@]}" --noconfirm --needed
            print_success "Python3 with pip3 installed successfully"
        else
            print_warning "Python3 and pip3 are already installed"
        fi
        
    elif [[ "$distro" == "debian" ]]; then
        local packages_needed=()
        if ! is_package_installed_debian "python3"; then
            packages_needed+=("python3")
        fi
        if ! is_package_installed_debian "python3-pip"; then
            packages_needed+=("python3-pip")
        fi
        if ! is_package_installed_debian "python3-venv"; then
            packages_needed+=("python3-venv")
        fi
        
        if [ ${#packages_needed[@]} -gt 0 ]; then
            sudo apt-get update
            sudo apt-get install "${packages_needed[@]}" -y
            print_success "Python3 with pip3 installed successfully"
        else
            print_warning "Python3 and pip3 are already installed"
        fi
    fi
}

# Install Vim
install_vim() {
    local distro=$1
    print_status "Installing Vim..."
    
    if [[ "$distro" == "arch" ]]; then
        if is_package_installed_arch "vim"; then
            print_warning "Vim is already installed"
        else
            sudo pacman -Sy
            sudo pacman -S vim --noconfirm --needed
            print_success "Vim installed successfully"
        fi
    elif [[ "$distro" == "debian" ]]; then
        if is_package_installed_debian "vim"; then
            print_warning "Vim is already installed"
        else
            sudo apt-get update
            sudo apt-get install vim -y
            print_success "Vim installed successfully"
        fi
    fi
}

# Process user selection
process_selection() {
    local selection="$1"
    local distro="$2"
    
    # Convert selection to array
    read -ra selected_apps <<< "$selection"
    
    # Check if "all" is selected
    for app in "${selected_apps[@]}"; do
        if [[ "$app" == "7" ]]; then
            selected_apps=(1 2 3 4 5 6)
            break
        fi
    done
    
    # Remove duplicates and sort
    IFS=" " read -r -a selected_apps <<< "$(echo "${selected_apps[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')"
    
    print_header "Installing selected applications..."
    
    for app in "${selected_apps[@]}"; do
        case $app in
            1) install_docker "$distro" ;;
            2) install_nginx "$distro" ;;
            3) install_nvm ;;
            4) install_gvm ;;
            5) install_python "$distro" ;;
            6) install_vim "$distro" ;;
        esac
        echo
    done
}

# Main function
main() {
    print_header "Universal Application Installer for Ubuntu/Debian and Manjaro/Arch"
    
    # Detect distribution
    distro=$(detect_distro)
    
    if [[ "$distro" == "unknown" ]]; then
        print_error "Unsupported distribution. This script supports Manjaro/Arch and Debian/Ubuntu systems."
        exit 1
    fi
    
    print_status "Detected distribution: $distro"
    
    # Show menu and get selection
    show_menu
    selection=$(get_user_selection)
    
    # Process the selection
    process_selection "$selection" "$distro"
    
    print_success "Installation process completed!"
    echo
    print_warning "Important notes:"
    echo "• If Docker was installed, you need to log out and log back in for group changes to take effect"
    echo "• For NVM, restart your terminal or run: source ~/.bashrc"
    echo "• For GVM, restart your terminal or run: source ~/.gvm/scripts/gvm"
    echo "• Some services may need to be started manually: sudo systemctl start <service-name>"
}

# Run the main function
main "$@"
