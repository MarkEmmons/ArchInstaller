#!/bin/bash

# Install final miscellaneous packages and dotfiles. Must be run in X session
build(){
	
	# Install additional packages
	DEV_PACKAGES="nodejs npm ctags clang cmake rust cargo"
	WEBDEV_PACKAGES="python-pip gdb yarn mongodb mongodb-tools leafpad"
	LANG_PACKAGES="btrfs-progs ruby valgrind scrot ncmpcpp htop"
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

echo "Running build..."
build