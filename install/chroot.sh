#!/bin/bash

HOST=HOST_NAME_TO_BE
ROOT=ROOT_PASS_TO_BE
USER=USER_NAME_TO_BE
PASS=USER_PASS_TO_BE

# Normal chroot stuff
install_linux(){

	# Initialize status bar
    START_TIME=$( date | sed -e 's|:| |g' | awk '{print ((($4*60)+$5)*60) + $6}' )
    status_bar "Installing Linux" &
    BAR_ID=$!
	
		percent 0
	# Generate locales
	sed 's|#en_US|en_US|' -i /etc/locale.gen
	locale-gen

		percent 10
	# Export locales
	echo "LANG=en_US.UTF-8" > /etc/locale.conf
	export LANG=en_US.UTF-8

		percent 20
	# Remove when moving from VirtualBox
	systemctl enable dhcpcd.service

		percent 30
	# Configure clock
	[[ -f /etc/localtime ]] && rm /etc/localtime
	ln -s /usr/share/zoneinfo/US/Central /etc/localtime
	hwclock --systohc --utc

		percent 40
	# Add host
	echo "$HOST" > /etc/hostname
	unset $HOST

		percent 50
	# Install Linux
	cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.backup
	sed 's|MODULES=\"\"|MODULES=\"btrfs\"|' -i /etc/mkinitcpio.conf
	grep "^[^#;]" /etc/mkinitcpio.conf | grep "HOOKS=" | sed 's|filesystems|encrypt lvm2 filesystems|' -i /etc/mkinitcpio.conf
		percent 60
	mkinitcpio -p linux

		percent 70
	# Install and configure grub
	pacman --noconfirm -S grub wget curl openssh parallel zsh dialog wpa_actiond wpa_supplicant vim git python2 tmux < /dev/tty
		percent 75
	sed 's|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"cryptdevice=/dev/sda3:ArchLinux root=/dev/mapper/ArchLinux-rootvol\"|' -i /etc/default/grub
		percent 80
	grub-install --target=i386-pc --recheck /dev/sda
		percent 90
	grub-mkconfig -o /boot/grub/grub.cfg
	
		percent 100
	wait $BAR_ID
}

# Create user and add some passwords
configure_users(){

	# Initialize status bar
    START_TIME=$( date | sed -e 's|:| |g' | awk '{print ((($4*60)+$5)*60) + $6}' )
    status_bar "Configuring users" &
    BAR_ID=$!
	
		percent 0
	# Choose password for root and change default shell to zsh
	echo "root:$ROOT" | chpasswd
	unset $ROOT
	chsh -s $(which zsh)

		percent 15
	# Give new user root-privileges
	useradd -m -G wheel -s /bin/zsh $USER
		percent 30
	cp /root/.zshrc /home/$USER/.zshrc
		percent 50
	echo "$USER:$PASS" | chpasswd
		percent 75
	unset $PASS
		percent 90
	sed "s/^root ALL=(ALL) ALL/root ALL=(ALL) ALL\n$USER ALL=(ALL) ALL/" -i /etc/sudoers
	
		percent 100
	wait $BAR_ID
}

# Install X Window System
install_x(){

	# Initialize status bar
    START_TIME=$( date | sed -e 's|:| |g' | awk '{print ((($4*60)+$5)*60) + $6}' )
    status_bar "Installing Xorg" &
    BAR_ID=$!
	
		percent 0
	PACKAGES1="mesa xf86-video-vesa xf86-video-intel xf86-video-fbdev xf86-input-synaptics alsa-utils"
	PACKAGES2="i3 i3status dmenu conky xterm chromium stow xbindkeys feh"
	PACKAGES3="xorg-server xorg-xinit xorg-xclock xorg-twm xorg-xprop"

		percent 5
	# Run when installing on VirtualBox
	x_for_vbox(){
		pacman --noconfirm -S virtualbox-guest-modules-arch virtualbox-guest-utils
		#modprobe -a vboxguest vboxsf vboxvideo
	}
	
		percent 10
	# Add more space to a non-virtual machine
	phys_machine_resize(){
		lvresize -L -120G ArchLinux/pool
		lvresize -L +20G ArchLinux/rootvol
		lvresize -L +100G ArchLinux/homevol
	}

	pacman --noconfirm -S $PACKAGES1
		percent 30
	pacman --noconfirm -S $PACKAGES2
		percent 50
	pacman --noconfirm -S $PACKAGES3
		percent 70

	# Run only if this is a VirtualBox guest
	lspci | grep -e VGA -e 3D | grep VirtualBox > /dev/null && x_for_vbox
	
	# Do not run if this is a VirtualBox guest
	lspci | grep -e VGA -e 3D | grep VirtualBox > /dev/null || phys_machine_resize
		percent 90
	
	echo "exec i3" > /home/$USER/.xinitrc
		percent 95
	[[ -f /home/$USER/.Xauthority ]] && rm /home/$USER/.Xauthority

		percent 100
	wait $BAR_ID
}

build(){

	# Initialize status bar
    START_TIME=$( date | sed -e 's|:| |g' | awk '{print ((($4*60)+$5)*60) + $6}' )
    status_bar "Building extras" &
    BAR_ID=$!
	
		percent 0
	# Fetch scripts to be run by $USER
	wget https://raw.github.com/MarkEmmons/ArchInstaller/master/install/user_scripts.sh
		percent 10
	mv user_scripts.sh /usr/bin/user_scripts
	chmod a+x /usr/bin/user_scripts
		percent 20
	
	# Install additional packages
	DEV_PACKAGES="nodejs npm ctags clang cmake rust cargo"
	WEBDEV_PACKAGES="python-pip gdb yarn mongodb mongodb-tools leafpad"
	LANG_PACKAGES="btrfs-progs ruby valgrind scrot ncmpcpp htop"
	VM_PACKAGES="docker docker-machine virtualbox virtualbox-host-modules-arch"

	pacman --noconfirm -S $DEV_PACKAGES
		percent 30

	# Add a wait script and log results separately
	sudo -u $USER user_scripts > /var/log/chroot/user_scripts.log 2>&1 &
	PID=$!
		percent 40
	#disown

	# Get feh to work without starting X
	
	pacman --noconfirm -S $WEBDEV_PACKAGES
		percent 50
	pacman --noconfirm -S $LANG_PACKAGES
		percent 60

	# Configure docker, for more info consult the wiki
	pacman --noconfirm -S $VM_PACKAGES
		percent 70
	tee /etc/modules-load.d/loop.conf <<< "loop"
	#modprobe loop
		percent 80
	gpasswd -a $USER docker

		percent 90
	# Wait for user scripts to finish
	echo "Waiting on user scripts"
	date
	wait $PID
	echo "We're done!"
	date

		percent 95
	# Don't need these anymore
	rm /usr/bin/user_scripts
	
		percent 100
	wait $BAR_ID
}

# Main
mkdir /var/log/install/chroot
source bar.sh

install_linux > /var/log/install/chroot/install_linux.log 3>&2 2>&1
configure_users > /var/log/install/chroot/configure_users.log 3>&2 2>&1
install_x > /var/log/install/chroot/install_x.log 3>&2 2>&1
build > /var/log/install/chroot/build.log 3>&2 2>&1

date >> /var/log/install/time.log