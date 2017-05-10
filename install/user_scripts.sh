#!/bin/bash

# Get aur packages (compile manually)
get_aur_packages(){

	# ** AUR packages can be unpredictable, do not automate compilation of AUR packages.

	AUR_PACKAGES=( https://aur.archlinux.org/cgit/aur.git/snapshot/b43-firmware.tar.gz
	https://aur.archlinux.org/cgit/aur.git/snapshot/bash-pipes.tar.gz
	https://aur.archlinux.org/cgit/aur.git/snapshot/cava.tar.gz
	https://aur.archlinux.org/cgit/aur.git/snapshot/expressvpn.tar.gz
	https://aur.archlinux.org/cgit/aur.git/snapshot/phallus-fonts-git.tar.gz
	https://aur.archlinux.org/cgit/aur.git/snapshot/fzf-git.tar.gz
	https://aur.archlinux.org/cgit/aur.git/snapshot/i3-gaps.tar.gz
	https://aur.archlinux.org/cgit/aur.git/snapshot/neofetch.tar.gz
	https://aur.archlinux.org/cgit/aur.git/snapshot/spotify.tar.gz )

	# Retrieve snapshots via parallel trickery
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

# Get aur packages asynchronously
get_aur_packages &
disown

# Get dotfiles
get_dotfiles

# "Install" dotfiles
dotfiles --install