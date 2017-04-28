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

	echo "exec i3" > .xinitrc
	[[ -f .Xauthority ]] && rm .Xauthority

}

# Install final miscellaneous packages, must be run as user with root-privileges
build(){

	# Retrieve dotfiles
	rm .xinitrc
	git clone https://github.com/MarkEmmons/dotfiles.git

	# Install Vim and dependencies
	sudo pacman -S vim ctags clang cmake python2

	#export PATH=$PATH:$HOME/dotfiles/bin
	# Needs to be finished

	sudo rm /usr/sbin/build
}

# Build is designed to be run one step at a time. 
# If more arguments are given we exit with error.

if [[ $# -ne 1 ]]; then
	echo "ERROR: Expected exactly 1 argument got $#."
	exit 1
fi

case $1 in
	-c|--create-admin)
		echo "Running create_admin..."
		create_admin
		;;	
	-f|--install-firmware)
		echo "Running install_firmware..."
		install_firmware
		;;
	-x|--install-x)
		echo "Running install_x..."
		install_x
		;;
	-b|--build)
		echo "Running build..."
		build
		;;
	*)
		echo "ERROR: Unknown argument $key."
		;;
esac