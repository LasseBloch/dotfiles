#!/bin/bash
# CachyOS Setup Script for dotfiles
# Run this script after fresh CachyOS Hyprland installation

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root"
    exit 1
fi

print_info "Starting CachyOS setup..."

# Update system
print_info "Updating system packages..."
sudo pacman -Syu --noconfirm

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
    ttf-jetbrains-mono-nerd \
    hyprland \
    hyprpaper \
    hypridle \
    hyprlock \
    waybar \
    mako \
    nautilus \
    wl-clipboard \
    cliphist \
    playerctl \
    brightnessctl \
    pipewire \
    wireplumber \
    pipewire-audio \
    qt6ct \
    slurp

print_status "Core packages installed"

# Check for AUR helper (CachyOS usually comes with yay or paru)
if command -v yay &> /dev/null; then
    AUR_HELPER="yay"
    print_status "Found yay"
elif command -v paru &> /dev/null; then
    AUR_HELPER="paru"
    print_status "Found paru"
else
    print_info "No AUR helper found. Installing yay..."
    cd /tmp
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si --noconfirm
    cd ~
    AUR_HELPER="yay"
    print_status "yay installed"
fi

# Install AUR packages
print_info "Installing AUR packages..."
$AUR_HELPER -S --needed --noconfirm \
    ghostty-bin \
    starship \
    zoxide \
    ripgrep-all \
    mise-bin \
    walker-bin \
    elephant \
    hyprsunset \
    hyprshot \
    satty-bin \
    wtype \
    obsidian

print_status "AUR packages installed"

# Install oh-my-zsh if not already installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    print_info "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    print_status "oh-my-zsh installed"
else
    print_status "oh-my-zsh already installed"
fi

# Setup dotfiles with stow
print_info "Setting up dotfiles with stow..."
DOTFILES_DIR="$HOME/dotfiles"

if [ -d "$DOTFILES_DIR" ]; then
    cd "$DOTFILES_DIR"

    # Initialize git submodules
    print_info "Initializing git submodules (tmux plugins)..."
    git submodule update --init --recursive
    print_status "Git submodules initialized"

    # Stow configurations
    print_info "Creating symlinks with stow..."
    stow -t ~ zsh
    stow -t ~ tmux
    stow -t ~ git
    stow -t ~ starship
    stow -t ~ fzf
    stow -t ~ ghostty

    print_status "Dotfiles stowed successfully"
else
    print_error "Dotfiles directory not found at $DOTFILES_DIR"
    print_info "Please clone your dotfiles first:"
    print_info "  git clone <your-dotfiles-repo> ~/dotfiles"
    exit 1
fi

# Setup Hyprland config
HYPR_CONFIG_SRC="$HOME/.config/hypr"
if [ -d "$HYPR_CONFIG_SRC" ]; then
    print_info "Copying Hyprland configuration..."

    # Backup CachyOS default config if it exists
    if [ -d "$HOME/.config/hypr-cachyos-backup" ]; then
        rm -rf "$HOME/.config/hypr-cachyos-backup"
    fi

    # Create config directory if it doesn't exist
    mkdir -p "$HOME/.config"

    # Note: Hyprland config is already in ~/.config/hypr
    print_status "Hyprland config ready"
    print_info "Make sure to copy your Hyprland config from your current system to the new one"
else
    print_warning "No Hyprland config found at $HYPR_CONFIG_SRC"
    print_info "You'll need to manually copy your Hyprland config after setup"
fi

# Change default shell to zsh
if [ "$SHELL" != "$(which zsh)" ]; then
    print_info "Changing default shell to zsh..."
    chsh -s $(which zsh)
    print_status "Default shell changed to zsh (will take effect on next login)"
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
echo "  1. Copy your Hyprland config from your current system:"
echo "     scp -r ~/.config/hypr USER@NEW-SYSTEM:~/.config/"
echo "  2. Log out and log back in (or restart) for all changes to take effect"
echo "  3. Open a new terminal to verify everything works"
echo "  4. Configure mise for any development tools you need"
echo "  5. Set up your wallpapers directory for hyprpaper"
echo ""
print_info "Installed Hyprland ecosystem:"
echo "  - Hyprland + hyprpaper, hypridle, hyprlock, hyprsunset"
echo "  - Walker launcher (with elephant backend)"
echo "  - Waybar, mako notifications"
echo "  - Screenshot tools: hyprshot + satty"
echo ""
print_info "Enjoy your new CachyOS Hyprland setup!"
