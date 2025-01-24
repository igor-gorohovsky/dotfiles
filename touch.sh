#!/usr/bin/env bash
set -euo pipefail

# dev-setup.sh
# A script to bootstrap a development environment on a clean Linux system.
#
GREEN="\e[1;32m"
RED="\e[3;31m"
ENDCOLOR="\e[0m"

echog () {
    echo -e "$GREEN$1$ENDCOLOR"
}

echor () {
    echo -e "$RED$1$ENDCOLOR"
}


# ------------------------------------------------------------------------------
# 1. Preliminaries & System Update
# ------------------------------------------------------------------------------

# # Ensure the script is running with sudo or user has sudo privileges
# if [[ $EUID -ne 0 ]]; then
#   echor "This script must be run as root or via sudo."
#   exit 1
# fi

echog "Updating system packages..."
sudo apt update -y && sudo apt upgrade -y

echog "Installing basic dependencies..."
sudo apt install -y curl vim git

# ------------------------------------------------------------------------------
# 2. ZSH setup
# ------------------------------------------------------------------------------

# echog "Installing zsh..."
# sudo apt install -y zsh fzf
# curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh
# curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
# echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
# sudo chsh -s $(which zsh)
#
#
# # ------------------------------------------------------------------------------
# # 3. Alacritty setup
# # ------------------------------------------------------------------------------
# #
# echog "Installing alacritty dependencies..."
# sudo apt install -y cmake g++ pkg-config libfreetype6-dev libfontconfig1-dev libxcb-xfixes0-dev libxkbcommon-dev python3
#
# echog "Cloning alacritty repo to host..."
# git clone https://github.com/alacritty/alacritty.git $HOME/alacritty
# cd $HOME/alacritty
#
# echog "Installing rust compiler..."
# curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# . "$HOME/.cargo/env"  
#
# echog "Checking that compiler installed correctly..."
# rustup override set stable
# rustup update stable
# echog "Rust compiler installed correctly!"
#
# echog "Starting alacritty compilation"
# cargo build --release
# tic -xe alacritty,alacritty-direct extra/alacritty.info
# infocmp alacritty
# sudo cp target/release/alacritty /usr/local/bin
# echog "Alacritty compilation completed!"
#
# echog "Setting alacritty as default terminal emulator"
# sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/local/bin/alacritty 100
# sudo update-alternatives --set x-terminal-emulator /usr/local/bin/alacritty
#
# echog "Create desktop entry for alacritty"
# sudo cp extra/logo/alacritty-term.svg /usr/share/pixmaps/Alacritty.svg
# sudo cp extra/linux/Alacritty.desktop /usr/local/share/applications
#

# ------------------------------------------------------------------------------ 
# 3. Install Tmux Plugin Manager (TPM) 
# ------------------------------------------------------------------------------

echog "Installing tmux..."
cd $HOME
sudo apt install -y tmux
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# ------------------------------------------------------------------------------
# 5. Install version manager 'mice'
# ------------------------------------------------------------------------------

echog "Installing mise"
curl https://mise.run | sh


# ------------------------------------------------------------------------------
# 6. Final Message
# ------------------------------------------------------------------------------
echog "Development environment setup completed!"
echog "Please log out and log back in (or restart your session) if necessary."
--------------------------------------------------------------------------------
