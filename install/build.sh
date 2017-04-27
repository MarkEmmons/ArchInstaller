#!/bin/bash

# Create a user with root-privileges, must be run as root
create_admin(){

	USER1="a"
	USER2="b"

	while [ "$USER1" != "$USER2" ]; do
		printf "Choose a user name: "
		read USER1
		printf "Verify user name: "
		read USER2
		if [ "$USER1" != "$USER2" ]; then
			echo "User name verification failed. Try again."
		fi
	done

	# Give new user root-privileges
	useradd -m -G wheel -s /bin/zsh $USER1
	passwd $USER1
	sed "s/^root ALL=(ALL) ALL/root ALL=(ALL) ALL\n$USER1 ALL=(ALL) ALL/" -i /etc/sudoers

}

# Install 3rd party device driver for Thinkpad wifi-card, must be run as user with root-privileges
install-firmware(){
	
	# Retrieve and unpackage tarball
	mkdir packages
	cd packages/
	wget https://aur.archlinux.org/cgit/aur.git/snapshot/b43-firmware.tar.gz
	tar -xvf b43-firmware.tar.gz
	
	# Build and install package
	cd b43-firmware/
	# TODO assert PKGBUILD
	makepkg -si

	# Remove tarball
	cd ../
	rm b43-firmware.tar.gz
	cd $HOME
	
}

# Install X Window System, must be run as user with root-privileges
install_x(){
	PACKAGES1="mesa xf86-video-vesa xf86-video-intel xf86-video-fbdev xf86-input-synaptics alsa-utils"
	PACKAGES2="i3 i3status dmenu conky xterm chromium stow xbindkeys"
	PACKAGES3="xorg-server xorg-server-utils xorg-xinit xorg-xclock xorg-twm"

	# Run when installing on VirtualBox
	x_for_vbox(){
		sudo pacman -S xorg
		sudo pacman -S virtualbox-guest-modules-arch virtualbox-guest-utils
		sudo modprobe -a vboxguest vboxsf vboxvideo
	}

	# Run when installing on personal computer
	x_for_thinkpad(){
		sudo Xorg :0 -configure
		sudo mv /root/xorg.conf.new /etc/X11/xorg.conf
	}

	sudo pacman -S $PACKAGES1
	sudo pacman -S $PACKAGES2
	sudo pacman -S $PACKAGES3

	#x_for_thinkpad
	x_for_vbox

	echo "exec 13" > .xinitrc
	[[ -f .Xauthority ]] && rm .Xauthority

}

# Install final miscellaneous packages, must be run as user with root-privileges
build(){
	# Do we need zsh?
	which zsh &> /dev/null
	if [[ $? -eq 1 ]]; then
		sudo pacman -S zsh
		chsh -s $(which zsh)
		zsh
	fi

	# Install Vim and dependencies
	sudo pacman -S vim ctags clang cmake python2

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
	sudo rm /usr/sbin/build
}

while [[ $# -gt 1 ]]
do
key="$1"

case $key in
	-c|--create-admin)
	create_admin
	;;	
	-f|--install-firmware)
	install_firmware
	;;
	-x|--install-x)
	install_x
	;;
	-b|--build)
	build
	;;
esac
shift
done