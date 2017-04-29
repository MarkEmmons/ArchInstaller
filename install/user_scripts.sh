#!/bin/bash

# Get aur packages (compile manually)
get_aur_packages(){

	cd $HOME

	# Create packages directory if it does not already exist
	if [[ ! -d "packages" ]]; then
		mkdir packages
	fi
	cd packages

	# ** AUR packages can be unpredictable, do not automate compilation of AUR packages.
	
	# Get Expressvpn
	wget https://aur.archlinux.org/cgit/aur.git/snapshot/expressvpn.tar.gz
	tar -xvf expressvpn.tar.gz
	
	# Get Spotify
	wget https://aur.archlinux.org/cgit/aur.git/snapshot/spotify.tar.gz
	tar -xvf spotify.tar.gz
	
}

# Get dotfiles
get_dotfiles(){

	cd $HOME

	# Retrieve dotfiles
	rm -rf .xinitrc .zshrc
	git clone https://github.com/MarkEmmons/dotfiles.git

	# Add dotfile scripts to path and make executable
	export PATH=$PATH:$HOME/dotfiles/bin
	mv $HOME/dotfiles/bin/dotfiles.sh $HOME/dotfiles/bin/dotfiles
	chmod a+x $HOME/dotfiles/bin/*

}


# Get aur packages (compile manually)
get_aur_packages

# Get dotfiles
get_dotfiles

# "Install" dotfiles
dotfiles --install