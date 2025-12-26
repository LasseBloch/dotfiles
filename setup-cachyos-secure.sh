#!/bin/bash
# CachyOS Setup Script for dotfiles (Security-Hardened Version)
# Run this script after fresh CachyOS Hyprland installation

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[i]${NC} $1"
}

print_warning() {
    echo -e "${BLUE}[!]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root"
    exit 1
fi

print_info "Starting CachyOS setup..."

# Confirm before proceeding
read -p "This script will install packages and modify your system. Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Setup cancelled"
    exit 0
fi

# Update system
print_info "Updating system packages..."
sudo pacman -Syu --noconfirm

# Show packages that will be installed
print_info "The following packages will be installed from official repos:"
echo "  zsh tmux stow fzf neovim ripgrep git openssh bc podman base-devel ttf-jetbrains-mono-nerd"
read -p "Continue with installation? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Installation cancelled"
    exit 0
fi

# Install core packages
print_info "Installing core packages..."
sudo pacman -S --needed --noconfirm \
    zsh \
    tmux \
    stow \
    fzf \
    neovim \
    ripgrep \
    git \
    openssh \
    bc \
    podman \
    base-devel \
    ttf-jetbrains-mono-nerd

print_status "Core packages installed"

# Check for AUR helper (CachyOS usually comes with yay or paru)
AUR_HELPER=""
if command -v yay &> /dev/null; then
    AUR_HELPER="yay"
    print_status "Found yay"
elif command -v paru &> /dev/null; then
    AUR_HELPER="paru"
    print_status "Found paru"
else
    print_warning "No AUR helper found. Installing yay-bin..."
    print_info "AUR packages are community-maintained. Review PKGBUILDs before trusting them."
    read -p "Install yay-bin from AUR? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ORIGINAL_DIR="$(pwd)"
        cd /tmp || exit 1

        # Clean up any previous yay-bin directory
        rm -rf yay-bin

        git clone https://aur.archlinux.org/yay-bin.git
        cd yay-bin || exit 1

        print_info "Review the PKGBUILD before continuing:"
        cat PKGBUILD
        echo ""
        read -p "PKGBUILD looks safe? Continue with installation? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            makepkg -si --noconfirm
            AUR_HELPER="yay"
            print_status "yay installed"
        else
            print_info "Skipping yay installation"
            cd "$ORIGINAL_DIR" || exit 1
        fi

        cd "$ORIGINAL_DIR" || exit 1
    else
        print_warning "Skipping AUR helper installation. AUR packages will not be installed."
    fi
fi

# Install AUR packages if we have an AUR helper
if [ -n "$AUR_HELPER" ]; then
    print_info "The following AUR packages will be installed:"
    echo "  ghostty-bin starship zoxide ripgrep-all mise-bin"
    print_warning "AUR packages are community-maintained. Only proceed if you trust these packages."
    read -p "Install AUR packages? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installing AUR packages..."
        "$AUR_HELPER" -S --needed --noconfirm \
            ghostty-bin \
            starship \
            zoxide \
            ripgrep-all \
            mise-bin

        print_status "AUR packages installed"
    else
        print_info "Skipping AUR packages"
    fi
else
    print_warning "No AUR helper available. Skipping AUR packages."
fi

# Install oh-my-zsh if not already installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    print_warning "oh-my-zsh installation requires downloading and running a script from the internet"
    print_info "You can review the install script at: https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
    read -p "Install oh-my-zsh? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Downloading oh-my-zsh installer..."

        # Download first, then let user inspect
        INSTALL_SCRIPT="/tmp/ohmyzsh-install.sh"
        curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$INSTALL_SCRIPT"

        print_info "Install script downloaded to $INSTALL_SCRIPT"
        read -p "Review the script? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            less "$INSTALL_SCRIPT"
        fi

        read -p "Execute the install script? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sh "$INSTALL_SCRIPT" --unattended
            rm "$INSTALL_SCRIPT"
            print_status "oh-my-zsh installed"
        else
            print_info "Skipping oh-my-zsh installation"
            rm "$INSTALL_SCRIPT"
        fi
    else
        print_info "Skipping oh-my-zsh installation"
    fi
else
    print_status "oh-my-zsh already installed"
fi

# Setup dotfiles with stow
print_info "Setting up dotfiles with stow..."
DOTFILES_DIR="$HOME/dotfiles"

if [ -d "$DOTFILES_DIR" ]; then
    ORIGINAL_DIR="$(pwd)"
    cd "$DOTFILES_DIR" || exit 1

    # Initialize git submodules
    print_warning "This will download git submodules from your dotfiles repo"
    read -p "Initialize git submodules? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Initializing git submodules (tmux plugins)..."
        git submodule update --init --recursive
        print_status "Git submodules initialized"
    else
        print_warning "Skipping submodule initialization - tmux plugins may not work"
    fi

    # Backup existing configs before stowing
    print_info "Backing up any existing config files..."
    BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"

    for config in .zshrc .tmux.conf .gitconfig; do
        if [ -f "$HOME/$config" ] && [ ! -L "$HOME/$config" ]; then
            print_info "Backing up $config"
            cp "$HOME/$config" "$BACKUP_DIR/"
        fi
    done

    if [ -d "$HOME/.config" ]; then
        for config in starship ghostty; do
            if [ -d "$HOME/.config/$config" ] && [ ! -L "$HOME/.config/$config" ]; then
                print_info "Backing up .config/$config"
                cp -r "$HOME/.config/$config" "$BACKUP_DIR/"
            fi
        done
    fi

    print_status "Backups saved to $BACKUP_DIR"

    # Stow configurations
    print_warning "This will create symlinks in your home directory"
    print_info "Stow will abort if conflicts are detected"
    read -p "Create symlinks with stow? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Creating symlinks with stow..."

        # Stow with error handling
        for package in zsh tmux git starship fzf ghostty; do
            if [ -d "$package" ]; then
                if stow -t ~ "$package" 2>&1; then
                    print_status "Stowed $package"
                else
                    print_error "Failed to stow $package - conflicts detected or directory doesn't exist"
                    print_info "You can manually resolve conflicts and run: stow -t ~ $package"
                fi
            else
                print_warning "Directory $package not found, skipping"
            fi
        done

        print_status "Dotfiles stowed successfully"
    else
        print_info "Skipping stow setup"
    fi

    cd "$ORIGINAL_DIR" || exit 1
else
    print_error "Dotfiles directory not found at $DOTFILES_DIR"
    print_info "Please clone your dotfiles first:"
    print_info "  git clone <your-dotfiles-repo> ~/dotfiles"
    exit 1
fi

# Change default shell to zsh
if [ "$SHELL" != "$(which zsh)" ]; then
    print_info "Changing default shell to zsh..."
    read -p "Change default shell to zsh? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        chsh -s "$(which zsh)"
        print_status "Default shell changed to zsh (will take effect on next login)"
    else
        print_info "Keeping current shell"
    fi
else
    print_status "Default shell is already zsh"
fi

# Setup SSH if needed
if [ ! -f "$HOME/.ssh/id_ed25519" ] && [ ! -f "$HOME/.ssh/id_rsa" ]; then
    print_info "No SSH key found. Generate one with:"
    print_info "  ssh-keygen -t ed25519 -C 'your_email@example.com'"
fi

# Final message
echo ""
print_status "Setup complete!"
echo ""
print_info "Next steps:"
echo "  1. Log out and log back in (or restart) for shell changes to take effect"
echo "  2. Open a new terminal to verify everything works"
echo "  3. Configure mise for any development tools you need"
echo "  4. Set up your Hyprland keybindings"
if [ -d "$BACKUP_DIR" ]; then
    echo "  5. Review backups at: $BACKUP_DIR"
fi
echo ""
print_info "Enjoy your new CachyOS setup!"
