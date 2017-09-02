#!/bin/bash

# Get aur packages (compile manually)
get_aur_packages(){

	# ** AUR packages can be unpredictable, do not automate compilation of AUR packages.
	#phallus-fonts-git

	AUR_PACKAGES=( b43-firmware
	bash-pipes
	cava
	expressvpn
	fzf-git
	gohufont
	i3-gaps
	neofetch
	spotify
	wal-git )

	# Retrieve snapshots via parallel trickery
	mkdir $HOME/packages
	cd $HOME/packages && \
	printf "%s\n" "${AUR_PACKAGES[@]}" | parallel "git clone https://aur.archlinux.org/{}.git"
	cd gohufont && makepkg
	cd ../wal-git && makepkg
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