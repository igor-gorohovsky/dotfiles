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

echog "Updating system packages..."
sudo apt update -y && sudo apt upgrade -y

echog "Installing basic dependencies..."
sudo apt install -y \
    curl \
    vim \
    git \
    gcc \
    libssl-dev \
    libncurses-dev \
    automake \
    autoconf \
    g++ \
    cmake \
    pkg-config \
    libfreetype6-dev \
    libfontconfig1-dev \
    libxcb-xfixes0-dev \
    libxkbcommon-dev \
    ninja-build

cd $HOME
mkdir projects
export PATH="$HOME/.local/bin:$PATH"
# ------------------------------------------------------------------------------
# 2. ZSH setup
# ------------------------------------------------------------------------------

echog "Installing zsh..."
sudo apt install -y zsh fzf
curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
sudo chsh -s $(which zsh)

# ------------------------------------------------------------------------------
# 3. Install languages and lsps
# ------------------------------------------------------------------------------

echog "Installing mise and languages..."
curl https://mise.run | sh
mise use --verbose -g python@3.11 java rust node
mise use --verbose -g erlang
mise use --verbose -g elixir
echo 'eval "$(mise activate bash)"' >> ~/.bashrc
echo 'eval "$(mise activate zsh)"' >> "${ZDOTDIR-$HOME}/.zshrc"
eval "$(mise activate bash)"

# Lua installation
cd $HOME && mkdir -p Downloads && cd Downloads
curl -L -R -O https://www.lua.org/ftp/lua-5.4.7.tar.gz
tar zxf lua-5.4.7.tar.gz
cd lua-5.4.7
make all test

. "$HOME/.cargo/env"  

echog "Installing basedpyright..."
pip3 install basedpyright


echog "Installing lexical..."
cd $HOME/projects
git clone https://github.com/lexical-lsp/lexical.git
cd lexical
curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
mix deps.get
mix package

echog "Installing typescript lsp..."
npm install -g typescript-language-server typescript

echog "Installing lua lsp"
cd $HOME/projects
git clone https://github.com/LuaLS/lua-language-server
cd lua-language-server
./make.sh

# ------------------------------------------------------------------------------
# 4. Alacritty setup
# ------------------------------------------------------------------------------

echog "Cloning alacritty repo..."
git clone https://github.com/alacritty/alacritty.git $HOME/alacritty
cd $HOME/alacritty

echog "Starting alacritty compilation"
cargo build --release
tic -xe alacritty,alacritty-direct extra/alacritty.info
infocmp alacritty
sudo cp target/release/alacritty /usr/local/bin
echog "Alacritty compilation completed!"

echog "Setting alacritty as default terminal emulator"
sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/local/bin/alacritty 100
sudo update-alternatives --set x-terminal-emulator /usr/local/bin/alacritty

echog "Create desktop entry for alacritty"
sudo cp extra/logo/alacritty-term.svg /usr/share/pixmaps/Alacritty.svg
sudo cp extra/linux/Alacritty.desktop /usr/local/share/applications


# ------------------------------------------------------------------------------ 
# 5. Install Tmux Plugin Manager (TPM) 
# ------------------------------------------------------------------------------

echog "Installing tmux..."
cd $HOME
sudo apt install -y tmux
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# ------------------------------------------------------------------------------ 
# 6. Install neovim
# ------------------------------------------------------------------------------

if ! command -v nvim 2>&1 >/dev/null
then
    echog "Installing neovim..."
    cd $HOME/Downloads
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
    sudo rm -rf /opt/nvim
    sudo tar -C /opt -xzf nvim-linux64.tar.gz
    export PATH="$PATH:/opt/nvim-linux64/bin"
    echo 'export PATH="$PATH:/opt/nvim-linux64/bin"'
fi

# ------------------------------------------------------------------------------
# 7. Install lazygit
# ------------------------------------------------------------------------------

if ! command -v nvim 2>&1 >/dev/null
then
    echog "Installing lazygit..."
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | \grep -Po '"tag_name": *"v\K[^"]*')
    cd $HOME/Downloads
    curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf lazygit.tar.gz lazygit
    sudo install lazygit -D -t /usr/local/bin/
fi

# ------------------------------------------------------------------------------
# 8. Install lazydocker
# ------------------------------------------------------------------------------

if ! command -v nvim 2>&1 >/dev/null
then
    echog "Installing lazygit..."
    curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
fi

# ------------------------------------------------------------------------------
# 9. Clone custom configs
# ------------------------------------------------------------------------------

echog "Clonening custom configs..."
git clone https://github.com/igor-gorohovsky/nvim.git ~/.config/nvim
git clone https://github.com/igor-gorohovsky/dotfiles ~/projects/dotfiles
cp ~/projects/dotfiles/alacritty.toml ~/.config/alacritty
cp ~/projects/dotfiles/tmux.conf ~/.config/tmux

# ------------------------------------------------------------------------------
# 10. Setting useful aliases
# ------------------------------------------------------------------------------

echo 'alias v="nvim"' >> ~/.zshrc
echo 'alias c="clear"' >> ~/.zshrc
echo 'alias venv="source .venv/bin/activate"' >> ~/.zshrc
echo 'alias gg="lazygit"' >> ~/.zshrc
echo 'alias dd="lazydocker"' >> ~/.zshrc
echo 'alias e="elixir"' >> ~/.zshrc

# ------------------------------------------------------------------------------
# 11. Final Message
# ------------------------------------------------------------------------------
echog "Development environment setup completed!"
echog "Please log out and log back in (or restart your session) if necessary."
# --------------------------------------------------------------------------------
