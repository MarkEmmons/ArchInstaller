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

# Install X Window System
install_x(){
	
	PACKAGES1="mesa xf86-video-vesa xf86-video-intel xf86-video-fbdev xf86-input-synaptics alsa-utils"
	PACKAGES2="i3 i3status dmenu conky xterm chromium stow xbindkeys feh"
	PACKAGES3="xorg-server xorg-server-utils xorg-xinit xorg-xclock xorg-twm"

	# Run when installing on VirtualBox
	x_for_vbox(){
		pacman --noconfirm -S virtualbox-guest-modules-arch virtualbox-guest-utils
		modprobe -a vboxguest vboxsf vboxvideo
	}
	
	# Add more space to a non-virtual machine
	phys_machine_resize(){
		lvresize -L -120G ArchLinux/pool
		lvresize -L +20G ArchLinux/rootvol
		lvresize -L +100G ArchLinux/homevol
	}

	pacman --noconfirm -S $PACKAGES1
	pacman --noconfirm -S $PACKAGES2
	pacman --noconfirm -S $PACKAGES3

	# Run only if this is a VirtualBox guest
	lspci | grep -e VGA -e 3D | grep VirtualBox > /dev/null && x_for_vbox
	
	# Do not run if this is a VirtualBox guest
	lspci | grep -e VGA -e 3D | grep VirtualBox > /dev/null || phys_machine_resize
	
	echo "exec i3" > .xinitrc
	[[ -f .Xauthority ]] && rm .Xauthority

}

# Install final miscellaneous packages and dotfiles. Must be run in X session
build(){
	
	# Install additional packages
	DEV_PACKAGES="python-pip gdb nodejs npm ctags clang cmake rust cargo"
	WEBDEV_PACKAGES="yarn mongodb mongodb-tools leafpad"
	LANG_PACKAGES="btrfs-progs ruby valgrind scrot"
	VM_PACKAGES="docker docker-machine virtualbox virtualbox-host-modules-arch"

	pacman --noconfirm -S $DEV_PACKAGES

	sudo -u $SUDO_USER user_scripts &
	disown

	pacman --noconfirm -S $WEBDEV_PACKAGES
	pacman --noconfirm -S $LANG_PACKAGES

	# Configure docker, for more info consult the wiki
	tee /etc/modules-load.d/loop.conf <<< "loop"
	modprobe loop
	pacman --noconfirm -S $VM_PACKAGES
	gpasswd -a $SUDO_USER docker
		
	# Don't need these anymore
	rm /usr/sbin/build
	rm /usr/bin/user_scripts
	
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