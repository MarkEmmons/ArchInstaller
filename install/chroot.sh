#!/bin/bash

HOST=HOST_NAME_TO_BE
ROOT=ROOT_PASS_TO_BE
USER=USER_NAME_TO_BE
PASS=USER_PASS_TO_BE

# Install X Window System
install_x(){
	
	PACKAGES1="mesa xf86-video-vesa xf86-video-intel xf86-video-fbdev xf86-input-synaptics alsa-utils"
	PACKAGES2="i3 i3status dmenu conky xterm chromium stow xbindkeys feh"
	PACKAGES3="xorg-server xorg-xinit xorg-xclock xorg-twm xorg-xprop"

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
	
	echo "exec i3" > /home/$USER/.xinitrc
	[[ -f /home/$USER/.Xauthority ]] && rm /home/$USER/.Xauthority

}

# Install final miscellaneous packages and dotfiles. Must be run in X session
build(){
	
	# Install additional packages
	DEV_PACKAGES="nodejs npm ctags clang cmake rust cargo"
	WEBDEV_PACKAGES="python-pip gdb yarn mongodb mongodb-tools leafpad"
	LANG_PACKAGES="btrfs-progs ruby valgrind scrot ncmpcpp htop"
	VM_PACKAGES="docker docker-machine virtualbox virtualbox-host-modules-arch"

	pacman --noconfirm -S $DEV_PACKAGES

	sudo -u $USER user_scripts &
	D_ID=$!
	#disown

	pacman --noconfirm -S $WEBDEV_PACKAGES
	pacman --noconfirm -S $LANG_PACKAGES

	# Configure docker, for more info consult the wiki
	tee /etc/modules-load.d/loop.conf <<< "loop"
	modprobe loop
	pacman --noconfirm -S $VM_PACKAGES
	gpasswd -a $USER docker
		
	# Don't need these anymore
	#rm /usr/sbin/build
	wait $D_ID
	rm /usr/bin/user_scripts
	
}

# Generate locales
sed 's|#en_US|en_US|' -i /etc/locale.gen
locale-gen

# Export locales
echo "LANG=en_US.UTF-8" > /etc/locale.conf
export LANG=en_US.UTF-8

# Remove when moving from VirtualBox
systemctl enable dhcpcd.service

# Configure clock
[[ -f /etc/localtime ]] && rm /etc/localtime
ln -s /usr/share/zoneinfo/US/Central /etc/localtime 
hwclock --systohc --utc

# Add host
#HOST1="a"
#HOST2="b"
#while [ "$HOST1" != "$HOST2" ]; do
#	printf "Choose a host name: "
#	read HOST1 < /dev/tty
#	printf "Verify host name: "
#	read HOST2 < /dev/tty
#	if [ "$HOST1" != "$HOST2" ]; then
#		echo "Host name verification failed. Try again."
#	fi
#done
#echo "$HOST1" > /etc/hostname
#unset $HOST1; unset $HOST2

# Add host
echo "$HOST" > /etc/hostname
unset $HOST

# Install Linux
cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.backup
sed 's|MODULES=\"\"|MODULES=\"btrfs\"|' -i /etc/mkinitcpio.conf
grep "^[^#;]" /etc/mkinitcpio.conf | grep "HOOKS=" | sed 's|filesystems|encrypt lvm2 filesystems|' -i /etc/mkinitcpio.conf
mkinitcpio -p linux

# Install and configure grub
pacman --noconfirm -S grub wget curl openssh parallel zsh dialog wpa_actiond wpa_supplicant vim git python2 tmux < /dev/tty
sed 's|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"cryptdevice=/dev/sda3:ArchLinux root=/dev/mapper/ArchLinux-rootvol\"|' -i /etc/default/grub
grub-install --target=i386-pc --recheck /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

# Choose password for root and change default shell to zsh
echo "Choose password for root: "
#passwd < /dev/tty
echo "root:$ROOT" | chpasswd
unset $ROOT
chsh -s $(which zsh)

# Give new user root-privileges
useradd -m -G wheel -s /bin/zsh $USER
cp /root/.zshrc /home/$USER/.zshrc
#passwd $USER
echo "$USER:$PASS" | chpasswd
unset $PASS
sed "s/^root ALL=(ALL) ALL/root ALL=(ALL) ALL\n$USER ALL=(ALL) ALL/" -i /etc/sudoers
unset $USER

# Download post-installation build scripts
#wget https://raw.github.com/MarkEmmons/ArchInstaller/master/install/build.sh
#mv build.sh /usr/sbin/build
#chmod a+x /usr/sbin/build

wget https://raw.github.com/MarkEmmons/ArchInstaller/master/install/user_scripts.sh
mv user_scripts.sh /usr/bin/user_scripts
chmod a+x /usr/bin/user_scripts

install_x
build