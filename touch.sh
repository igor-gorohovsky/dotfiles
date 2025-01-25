#!/usr/bin/env bash
set -euo pipefail

# dev-setup.sh
# A script to bootstrap a development environment on a clean Linux system.
#
GREEN="\e[1;32m"
RED="\e[3;31m"
ENDCOLOR="\e[0m"

trap 'echor "Script failed unexpectedly at line $LINENO. Exiting..."; exit 1' ERR

# ------------------------------------------------------------------------------
# 1. Utility functions
# ------------------------------------------------------------------------------

echog () {
    echo -e "$GREEN$1$ENDCOLOR"
}

echor () {
    echo -e "$RED$1$ENDCOLOR"
}

command_exists() {
    command -v "$1" 2>&1>/dev/null
}

append_if_missing() {
    local line="$1"
    local file="$2"
    grep -qxF "$line" "$file" || echo "$line" >> "$file"
}

# ------------------------------------------------------------------------------
# 2. Install functions
# ------------------------------------------------------------------------------

initial_setup() {
    echog "Updating system packages..."
    sudo apt update -y && sudo apt upgrade -y

    echog "Installing basic dependencies..."
    sudo apt install -y \
        curl \
        wget \
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

}

install_zsh() {
    if command_exists zsh; then
        echog "ZSH already installed, skipping it..."
        return
    fi
    echog "Installing zsh..."
    sudo apt install -y zsh fzf
    curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
    sudo chsh -s $(which zsh)
}
install_mise() {
    if command_exists mise; then
        echog "Mise already installed, skipping it..."
        return
    fi
    echog "Installing mise..."
    curl https://mise.run | sh
    append_if_missing 'eval "$(mise activate zsh)"' "${ZDOTDIR-$HOME}/.zshrc"
    eval "$(mise activate bash)"
}

install_python() {
    mise use --verbose -g python@3.11
}

install_java() {
    mise use --verbose -g java
}

install_rust() {
    mise use --verbose -g rust
    . "$HOME/.cargo/env"  
}

install_node() {
    mise use --verbose -g node
}

install_erlang() {
    mise use --verbose -g erlang
}

install_elixir() {
    mise use --verbose -g elixir
}


install_lua() {
    if command_exists lua; then
        echog "Lua already installed, skipping..."
        return
    fi
    cd ~ && mkdir -p Downloads && cd Downloads
    curl -L -R -O https://www.lua.org/ftp/lua-5.4.7.tar.gz
    tar zxf lua-5.4.7.tar.gz
    cd lua-5.4.7
    make all test
}

install_pyright() {
    if command_exists basedpyright; then
        echog "Basedpyright already installed, skipping..."
        return
    fi
    pip3 install basedpyright
}

install_lexical() {
    echog "Compiling lexical..."
    cd ~/projects
    git clone https://github.com/lexical-lsp/lexical.git
    cd lexical
    curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
    mix deps.get
    mix package
}

install_ts_lsp() {
    if command_exists typescript-language-server; then
        echog "TS lsp already installed, skipping..."
        return
    fi
    echog "Installing typescript lsp..."
    npm i -g typescript-language-server typescript
}

install_lua_lsp() {
    if command_exists lua-language-server; then
        echog "Lua lsp already installed, skipping..."
        return
    fi
    echog "Installing lua lsp..."
    cd ~/projects
    git clone https://github.com/LuaLS/lua-language-server
    cd lua-language-server
    ./make.sh
}

install_bash_lsp() {
    if command_exists bash-language-server; then
        echog "Bash lsp already installed, skipping..."
        return
    fi
    echog "Installing bash lsp..."
}

install_alacritty() {
    if command_exists alacritty; then
        echog "Alacritty already installed, skipping..."
        return
    fi
    echog "Cloning alacritty repo..."
    git clone https://github.com/alacritty/alacritty.git ~/projects/alacritty
    cd ~/projects/alacritty

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
}

install_tmux(){
    if command_exists tmux; then
        echog "Tmux already installed, skipping..."
        return
    fi
    echog "Installing tmux..."
    cd $HOME
    sudo apt install -y tmux
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
}

install_neovim() {
    if command_exists nvim; then
        echog "Neovim already installed, skipping..."
        return
    fi
    echog "Installing neovim..."
    cd $HOME/Downloads
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
    sudo rm -rf /opt/nvim
    sudo tar -C /opt -xzf nvim-linux64.tar.gz
    export PATH="$PATH:/opt/nvim-linux64/bin"
    append_if_missing 'export PATH="$PATH:/opt/nvim-linux64/bin"' ~/.zshrc
}

install_lazygit() {
    if command_exists lazygit; then
        echog "Lazygit already installed, skipping it..."
        return
    fi
    echog "Installing lazygit..."
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | \grep -Po '"tag_name": *"v\K[^"]*')
    cd $HOME/Downloads
    curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf lazygit.tar.gz lazygit
    sudo install lazygit -D -t /usr/local/bin/
}

install_lazydocker() {
    if command_exists lazydocker; then
        echog "Lazydocker already installed, skipping it..."
    fi
    echog "Installing lazydocker..."
    curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
}

clone_configs() {
    echog "Clonening custom configs..."
    mkdir -p ~/.config/nvim
    mkdir -p ~/projects/dotfiles
    mkdir -p ~/.config/alacritty
    mkdir -p ~/.config/tmux

    git clone https://github.com/igor-gorohovsky/nvim.git ~/.config/nvim
    git clone https://github.com/igor-gorohovsky/dotfiles ~/projects/dotfiles
    cp ~/projects/dotfiles/alacritty.toml ~/.config/alacritty
    cp ~/projects/dotfiles/tmux.conf ~/.config/tmux
}

set_aliases() {
    append_if_missing 'alias v="nvim"' ~/.zshrc
    append_if_missing 'alias c="clear"' ~/.zshrc
    append_if_missing 'alias venv="source .venv/bin/activate"' ~/.zshrc
    append_if_missing 'alias gg="lazygit"' ~/.zshrc
    append_if_missing 'alias dd="lazydocker"' ~/.zshrc
    append_if_missing 'alias e="elixir"' ~/.zshrc
}

main() {
    local START_DIR
    START_DIR=$(pwd)
    cd ~
    mkdir -p projects
    export PATH="$HOME/.local/bin:$PATH"

    initial_setup

    install_zsh

    install_mise

    install_python
    install_node
    install_rust
    install_java
    install_erlang
    install_elixir
    install_lua

    install_ts_lsp
    install_lua_lsp
    install_bash_lsp
    install_pyright
    install_lexical

    install_alacritty
    install_tmux
    install_neovim
    install_lazygit
    install_lazydocker

    clone_configs
    set_aliases

    echog "Development environment setup completed!"
    echog "Please log out and log back in (or restart your session) if necessary."
    cd $START_DIR
}

main "$@"
