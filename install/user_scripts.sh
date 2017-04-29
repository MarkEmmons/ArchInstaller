#!/bin/bash

# Get aur packages (compile manually)
get_aur_packages(){

	AUR_PACKAGES=( https://aur.archlinux.org/cgit/aur.git/snapshot/b43-firmware.tar.gz
	https://aur.archlinux.org/cgit/aur.git/snapshot/expressvpn.tar.gz
	https://aur.archlinux.org/cgit/aur.git/snapshot/spotify.tar.gz )

	# ** AUR packages can be unpredictable, do not automate compilation of AUR packages.
	mkdir $HOME/packages
	cd $HOME/packages && \
	printf "%s\n" "${AUR_PACKAGES[@]}" | parallel "curl {} | tar -xz"
	
	cd $HOME

}

# Get dotfiles
get_dotfiles(){

	# Retrieve dotfiles
	rm -rf .xinitrc .zshrc
	git clone https://github.com/MarkEmmons/dotfiles.git

	# Add dotfile scripts to path and make executable
	export PATH=$PATH:$HOME/dotfiles/bin
	mv $HOME/dotfiles/bin/dotfiles.sh $HOME/dotfiles/bin/dotfiles
	chmod a+x $HOME/dotfiles/bin/*

}

# Get aur packages (compile manually)
get_aur_packages &
disown

# Get dotfiles
get_dotfiles

# "Install" dotfiles
dotfiles --install