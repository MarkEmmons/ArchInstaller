#!/bin/bash

# Get aur packages (compile manually)
get_aur_packages(){

	# ** AUR packages can be unpredictable, do not automate compilation of AUR packages.

	AUR_PACKAGES=( b43-firmware
	bash-pipes
	cava
	expressvpn
	phallus-fonts-git
	fzf-git
	i3-gaps
	neofetch
	spotify )

	# Retrieve snapshots via parallel trickery
	mkdir $HOME/packages
	cd $HOME/packages && \	
	printf "%s\n" "${AUR_PACKAGES[@]}" | parallel "git clone https://aur.archlinux.org/{}.git"
}

# Get dotfiles
get_dotfiles(){

	# Retrieve dotfiles
	rm -rf .xinitrc .zshrc
	git clone https://github.com/MarkEmmons/dotfiles.git

	# Add dotfile scripts to path and make executable
	export PATH=$PATH:$HOME/dotfiles/bin
	chmod a+x $HOME/dotfiles/bin/*

	# "Install" dotfiles
	dot --install
	date
}

# Get aur packages asynchronously
get_aur_packages &
disown

cd $HOME

# Get dotfiles
get_dotfiles