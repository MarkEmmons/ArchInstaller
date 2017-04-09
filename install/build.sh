#!/bin/bash

# Do we need zsh?
#which zsh &> /dev/null
#if [[ $?==1 ]]; then
#    sudo pacman -S zsh
#    chsh -s $(which zsh)
#    zsh
#fi

# Install Vim and dependencies
sudo pacman -S vim ctags clang cmake rust python2

# Setup Pacaur and YCM
wget https://aur.archlinux.org/cgit/aur.git/snapshot/cower.tar.gz
wget https://aur.archlinux.org/cgit/aur.git/snapshot/pacaur.tar.gz

# Install Cower
tar -xvf cower.tar.gz
gpg --list-keys
sudo echo "keyring /etc/pacman.d/gnupg/pubring.gpg" >> ~/.gnupg/gpg.conf
export PATH=$PATH:/usr/bin/core_perl
cd cower
makepkg -sri

# Install Pacaur
tar -xvf pacaur.tar.gz
cd pacaur
makepkg -sri
cd ~

# Install Pathogen
mkdir -p ~/.vim/autoload ~/.vim/bundle && \
curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

# Install YCM
cd ~/.vim/bundle && \
git clone https://github.com/Valloric/YouCompleteMe.git
cd YouCompleteMe
git submodule update --init --recursive
python2 install.py --clang-completer --system-libclang

# Install Syntastic
cd ~/.vim/bundle && \
git clone https://github.com/scrooloose/syntastic.git

# Install Nerdtree
cd ~/.vim/bundle && \
git clone https://github.com/scrooloose/nerdtree.git

# Install Tagbar
cd ~/.vim/bundle && \
git clone https://github.com/majutsushi/tagbar.git 

# Install Vim-airline
cd ~/.vim/bundle && \
git clone https://github.com/vim-airline/vim-airline.git

# Install Vim-airline themes
cd ~/.vim/bundle && \
git clone https://github.com/vim-airline/vim-airline-themes.git

# Retrieve dotfiles
cd $HOME
rm .xinitrc
git clone https://github.com/MarkEmmons/dotfiles.git

# Stow dotfiles
cd ~/dotfiles
stow chromium
stow i3
stow vim
stow x
stow zsh

# xinitrc
sudo chmod 777 $HOME/.xinitrc

# Xresources
sudo chmod 777 $HOME/.Xresources

# i3/config
sudo chmod 777 $HOME/.i3/config

## Conky
sudo chmod 777 $HOME/.conkyi3
sudo chmod 777 $HOME/.bin/conky-i3
sudo chmod 777 $HOME/.bin/toggle_monitor

# chromium-flags
sudo chmod 777 $HOME/.config/chromium-flags.conf
cd $HOME

# Install ohmyzsh
sh -c "$(wget https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"
rm .zshrc