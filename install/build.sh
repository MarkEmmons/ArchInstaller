#!/bin/bash

# Create a user with root-privileges
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
	
	# Create placeholder zshrc to avoid unnecessary warnings
	echo "# Placeholder" >> /home/$USER1/.zshrc

}

# Install 3rd party device driver for Thinkpad wifi-card
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

# Install X Window System
install_x(){
	
	PACKAGES1="mesa xf86-video-vesa xf86-video-intel xf86-video-fbdev xf86-input-synaptics alsa-utils"
	PACKAGES2="i3 i3status dmenu conky xterm chromium stow xbindkeys feh"
	PACKAGES3="xorg-server xorg-server-utils xorg-xinit xorg-xclock xorg-twm"

	# Run when installing on VirtualBox
	x_for_vbox(){
		pacman -S virtualbox-guest-modules-arch virtualbox-guest-utils
		modprobe -a vboxguest vboxsf vboxvideo
	}

	# Run when installing on personal computer
	#x_for_thinkpad(){
	#	sudo Xorg :0 -configure
	#	sudo mv /root/xorg.conf.new /etc/X11/xorg.conf
	#}

	pacman -S $PACKAGES1
	pacman -S $PACKAGES2
	pacman -S $PACKAGES3

	#x_for_thinkpad
	x_for_vbox

	echo "exec i3" > .xinitrc
	[[ -f .Xauthority ]] && rm .Xauthority

}

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
	chmod u+x $HOME/dotfiles/bin/*

}

# Install final miscellaneous packages and dotfiles. Must be run in X session
build(){
	
	# Install additional packages
	DEV_PACKAGES="btrfs-progs ctags clang cmake net-tools"
	WEBDEV_PACKAGES="nodejs npm yarn mongodb mongodb-tools"
	LANG_PACKAGES="ruby rust valgrind"
	TOOL_PACKAGES="leafpad parallel scrot"
	VM_PACKAGES="docker docker-machine virtualbox virtualbox-host-modules-arch"

	pacman -S $DEV_PACKAGES
	pacman -S $WEBDEV_PACKAGES
	pacman -S $LANG_PACKAGES
	pacman -S $TOOL_PACKAGES

	# Configure docker, for more info consult the wiki
	tee /etc/modules-load.d/loop.conf <<< "loop"
	modprobe loop
	pacman -S $VM_PACKAGES
	groupadd docker
	gpasswd -a $SUDO_USER docker

	# Get aur packages (compile manually)
	sudo -u $SUDO_USER get_aur_packages
	
	# Get dotfiles
	sudo -u $SUDO_USER get_dotfiles
	
	# "Install" dotfiles
	sudo -u $SUDO_USER dotfiles --install
	
	# Don't need this anymore
	rm /usr/sbin/build

}

# User must run build with root privileges
if [[ $EUID -ne 0 ]]; then
	echo "error: you cannot perform this operation unless you are root."
	exit 1
fi

# User must provide exactly one argument
if [[ $# -ne 1 ]]; then
	echo "error: expected exactly 1 argument got $#."
	exit 1
fi

# Pick an installation step
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