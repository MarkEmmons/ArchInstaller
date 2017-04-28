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
	
	echo "# Placeholder" >> /home/$USER1/.zshrc

}

# Install 3rd party device driver for Thinkpad wifi-card, must be run as user with root-privileges
install-firmware(){
	
	# Retrieve and unpackage tarball
	mkdir packages
	cd packages/
	wget https://aur.archlinux.org/cgit/aur.git/snapshot/b43-firmware.tar.gz
	tar -xvf b43-firmware.tar.gz
	
	# Prompt user to build package manually for safety and consistency reasons
	cd b43-firmware/
	ls
	echo "Verify PKGBUILD and run makepkg -si"
	
}

# Install X Window System, must be run as user with root-privileges
install_x(){
	
	PACKAGES1="mesa xf86-video-vesa xf86-video-intel xf86-video-fbdev xf86-input-synaptics alsa-utils"
	PACKAGES2="i3 i3status dmenu conky xterm chromium stow xbindkeys feh"
	PACKAGES3="xorg-server xorg-server-utils xorg-xinit xorg-xclock xorg-twm"

	# Run when installing on VirtualBox
	x_for_vbox(){
		sudo pacman -S virtualbox-guest-modules-arch virtualbox-guest-utils
		sudo modprobe -a vboxguest vboxsf vboxvideo
	}

	# Run when installing on personal computer
	#x_for_thinkpad(){
	#	sudo Xorg :0 -configure
	#	sudo mv /root/xorg.conf.new /etc/X11/xorg.conf
	#}

	sudo pacman -S $PACKAGES1
	sudo pacman -S $PACKAGES2
	sudo pacman -S $PACKAGES3

	#x_for_thinkpad
	x_for_vbox

	echo "exec i3" > .xinitrc
	[[ -f .Xauthority ]] && rm .Xauthority

}

# Install final miscellaneous packages, must be run as user with root-privileges in an X session
build(){
	
	# Install additional packages
	DEV_PACKAGES="btrfs-progs ctags clang cmake gnupg lvm2 net-tools"
	WEBDEV_PACKAGES="nodejs npm yarn mongodb mongodb-tools"
	LANG_PACKAGES="ruby rust valgrind"
	TOOL_PACKAGES="leafpad parallel scrot"
	VM_PACKAGES="docker docker-machine virtualbox virtualbox-host-modules-arch"

	sudo pacman -S $DEV_PACKAGES
	sudo pacman -S $WEBDEV_PACKAGES
	sudo pacman -S $LANG_PACKAGES
	sudo pacman -S $TOOL_PACKAGES

	# Configure docker, for more info consult the wiki
	sudo tee /etc/modules-load.d/loop.conf <<< "loop"
	sudo modprobe loop
	sudo pacman -S $VM_PACKAGES
	sudo groupadd docker
	sudo gpasswd -a $USER docker

	# Create packages directory if it does not already exist
	if [[ ! -d "packages" ]]; then
		mkdir packages
	fi
	cd packages

	# ** AUR packages can be unpredictable, do not automate compilation of AUR packages.
	
	# Get Expressvpn
	wget https://aur.archlinux.org/cgit/aur.git/snapshot/expressvpn.tar.gz
	tar -xvf expressvpn.tar.gz
	gpg --recv-key AFF2A1415F6A3A38
	
	# Get Spotify
	wget https://aur.archlinux.org/cgit/aur.git/snapshot/spotify.tar.gz
	tar -xvf spotify.tar.gz
	cd $HOME

	# Retrieve dotfiles
	rm -r .xinitrc .zshrc
	git clone https://github.com/MarkEmmons/dotfiles.git
	export PATH=$PATH:$HOME/dotfiles/bin
	mv $HOME/dotfiles/bin/dotfiles.sh $HOME/dotfiles/bin/dotfiles
	chmod u+x $HOME/dotfiles/bin/*
	
	# "Install" dotfiles
	dotfiles --install
	
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