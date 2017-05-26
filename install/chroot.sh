#!/bin/bash

HOST=HOST_NAME_TO_BE
ROOT=ROOT_PASS_TO_BE
USER=USER_NAME_TO_BE
PASS=USER_PASS_TO_BE

CACHE=CACHE_VAL_TO_BE

# Normal chroot stuff
install_linux(){

    STAT_ARRAY=( "Generating locales"
    "Created symlink"
    "installing wpa_supplicant"
    "installing vim-runtime"
    "installing git"
    "Running post-transaction hooks"
    "Installing for i386-pc platform"
    "Generating grub configuration file"
    "Found linux image: /boot/vmlinuz-linux" )

	# Initialize progress bar
    progress_bar " Installing Linux" ${#STAT_ARRAY[@]} "${STAT_ARRAY[@]}" &
    BAR_ID=$!
	
	# Generate locales
	sed 's|#en_US|en_US|' -i /etc/locale.gen
	locale-gen

	# Export locales
	echo "LANG=en_US.UTF-8" > /etc/locale.conf
	export LANG=en_US.UTF-8

	# Remove when moving from VirtualBox
	systemctl enable dhcpcd.service

	# Add host
	echo "$HOST" > /etc/hostname

	# Install Linux
	cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.backup
	sed 's|MODULES=\"\"|MODULES=\"btrfs\"|' -i /etc/mkinitcpio.conf
	grep "^[^#;]" /etc/mkinitcpio.conf | grep "HOOKS=" | sed 's|filesystems|encrypt lvm2 filesystems|' -i /etc/mkinitcpio.conf
	mkinitcpio -p linux

	# Install and configure grub
	#pacman -Sp --noconfirm $PACKAGES | parallel wget -q -P /var/cache/pacman/pkg {}
	pacman --needed --noconfirm --noprogressbar -S zsh parallel wget openssh dialog wpa_actiond wpa_supplicant vim git python2 tmux
	sed 's|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"cryptdevice=/dev/sda3:ArchLinux root=/dev/mapper/ArchLinux-rootvol\"|' -i /etc/default/grub
	grub-install --target=i386-pc --recheck /dev/sda
	grub-mkconfig -o /boot/grub/grub.cfg
	
	wait $BAR_ID
}

# Create user and add some passwords
configure_users(){

    STAT_ARRAY=( "Setting root password"
	"Root password set"
	"Changing shell for root"
    "Shell changed"
	"Adding new user"
	"Setting user password"
	"Adding user to sudoers"
	"New user created" )

	# Initialize progress bar
    progress_bar " Configuring users" ${#STAT_ARRAY[@]} "${STAT_ARRAY[@]}" &
    BAR_ID=$!
	
	# Choose password for root and change default shell to zsh
	echo "Setting root password..."
	echo "root:$ROOT" | chpasswd
	unset $ROOT
	echo "Root password set."
	chsh -s /bin/zsh

	# Give new user root-privileges
	echo "Adding new user..."
	useradd -m -G wheel -s /bin/zsh $USER
	cp /root/.zshrc /home/$USER/.zshrc
	echo "Setting user password..."
	echo "$USER:$PASS" | chpasswd
	unset $PASS
	echo "Adding user to sudoers..."
	sed "s/^root ALL=(ALL) ALL/root ALL=(ALL) ALL\n$USER ALL=(ALL) ALL/" -i /etc/sudoers
	echo "New user created."
	
	wait $BAR_ID
}

# Install X Window System
install_x(){

    STAT_ARRAY=("installing wayland"
    "installing xextproto"
    "installing damageproto"
    "installing mesa"
    "installing xf86-video-fbdev"
    "installing alsa-lib"
    "installing flac"
    "installing alsa-utils"
    "installing cairo"
    "installing i3-wm"
    "installing wireless_tools"
    "installing dmenu"
    "installing lua"
    "installing conky"
    "installing xterm"
    "installing chromium"
    "installing stow"
    "installing xbindkeys"
    "installing fontsproto"
    "installing xorg-fonts-encodings"
    "installing xorg-font-utils"
    "installing xorg-server-common"
    "installing xorg-xinit"
    "installing xorg-xclock"
    "installing xorg-xprop")

	# Initialize progress bar
    progress_bar " Installing Xorg" ${#STAT_ARRAY[@]} "${STAT_ARRAY[@]}" &
    BAR_ID=$!
	
	PACKAGES1="mesa xf86-video-vesa xf86-video-intel xf86-video-fbdev xf86-input-synaptics alsa-utils"
	PACKAGES2="i3 i3status dmenu conky xterm chromium stow xbindkeys feh"
	PACKAGES3="xorg-server xorg-xinit xorg-xclock xorg-twm xorg-xprop"

	# Run when installing on VirtualBox
	x_for_vbox(){
		#pacman -Sp --noconfirm virtualbox-guest-modules-arch virtualbox-guest-utils | \
		#	parallel wget -q -P /var/cache/pacman/pkg {}
		pacman -S --noconfirm virtualbox-guest-modules-arch virtualbox-guest-utils
		#modprobe -a vboxguest vboxsf vboxvideo
	}
	
	# Add more space to a non-virtual machine
	phys_machine_resize(){
		lvresize -L -120G ArchLinux/pool
		lvresize -L +20G ArchLinux/rootvol
		lvresize -L +100G ArchLinux/homevol
	}

	
	#pacman -Sp --noconfirm $PACKAGES1 | parallel wget -q -P /var/cache/pacman/pkg {}
	pacman --needed --noconfirm --noprogressbar -S $PACKAGES1
	#pacman -Sp --noconfirm $PACKAGES2 | parallel wget -q -P /var/cache/pacman/pkg {}
	pacman --needed --noconfirm --noprogressbar -S $PACKAGES2
	#pacman -Sp --noconfirm $PACKAGES3 | parallel wget -q -P /var/cache/pacman/pkg {}
	pacman --needed --noconfirm --noprogressbar -S $PACKAGES3

	# Run only if this is a VirtualBox guest
	lspci | grep -e VGA -e 3D | grep VirtualBox > /dev/null && x_for_vbox
	
	# Do not run if this is a VirtualBox guest
	lspci | grep -e VGA -e 3D | grep VirtualBox > /dev/null || phys_machine_resize
	
	echo "exec i3" > /home/$USER/.xinitrc
	[[ -f /home/$USER/.Xauthority ]] && rm /home/$USER/.Xauthority

	wait $BAR_ID
}

build(){

    STAT_ARRAY=( "installing openssl"
    "installing http-parser"
    "installing nodejs"
    "installing cmake"
    "installing cargo"
    "installing python-pyparsing"
    "installing python-setuptools"
    "installing gdb-common"
    "installing yarn"
    "installing mongodb-tools"
    "installing leafpad"
    "installing btrfs-progs"
    "installing valgrind"
    "installing scrot"
    "installing ncmpcpp"
    "installing htop"
    "installing docker-machine"
    "installing sdl"
    "installing libproxy"
    "installing virtualbox-host"
    "loop"
    "Waiting on user scripts"
    "We're done" )

	# Initialize progress bar
    progress_bar " Building extras" ${#STAT_ARRAY[@]} "${STAT_ARRAY[@]}" &
    BAR_ID=$!
	
	# Fetch scripts to be run by $USER
	wget https://raw.github.com/MarkEmmons/ArchInstaller/master/install/user_scripts.sh
	mv user_scripts.sh /usr/bin/user_scripts
	chmod a+x /usr/bin/user_scripts
	
	# Install additional packages
	DEV_PACKAGES="nodejs npm ctags clang cmake rust cargo"
	WEBDEV_PACKAGES="python-pip gdb yarn mongodb mongodb-tools leafpad"
	LANG_PACKAGES="btrfs-progs ruby valgrind scrot ncmpcpp htop"
	VM_PACKAGES="docker docker-machine virtualbox virtualbox-host-modules-arch"

	#pacman --noconfirm -S $DEV_PACKAGES
	#pacman -Sp --noconfirm $DEV_PACKAGES | parallel wget -q -P /var/cache/pacman/pkg {}
	pacman --needed --noconfirm --noprogressbar -S $DEV_PACKAGES
	# Add a wait script and log results separately
	sudo -u $USER user_scripts > /var/log/install/chroot/user_scripts.log 2>&1 &
	PID=$!
	#disown

	# Get feh to work without starting X
	
	#pacman --noconfirm -S $WEBDEV_PACKAGES
	#pacman -Sp --noconfirm $WEBDEV_PACKAGES | parallel wget -q -P /var/cache/pacman/pkg {}
	pacman --needed --noconfirm --noprogressbar -S $WEBDEV_PACKAGES
	#pacman --noconfirm -S $LANG_PACKAGES
	#pacman -Sp --noconfirm $LANG_PACKAGES | parallel wget -q -P /var/cache/pacman/pkg {}
	pacman --needed --noconfirm --noprogressbar -S $LANG_PACKAGES
	
	# Configure docker, for more info consult the wiki
	#pacman --noconfirm -S $VM_PACKAGES
	#pacman -Sp --noconfirm $VM_PACKAGES | parallel wget -q -P /var/cache/pacman/pkg {}
	pacman --needed --noconfirm --noprogressbar -S $VM_PACKAGES
	tee /etc/modules-load.d/loop.conf <<< "loop"
	#modprobe loop
	gpasswd -a $USER docker

	# Wait for user scripts to finish
	echo "Waiting on user scripts"
	date
	wait $PID
	echo "We're done!"
	date

	# Don't need these anymore
	rm /usr/bin/user_scripts
	
	wait $BAR_ID
}

get_runtime(){

	# Get time at start and completion of script
	H_START=$(cat /var/log/install/time.log | sed -e 's|:| |g' | awk '{print $4}')
	M_START=$(cat /var/log/install/time.log | sed -e 's|:| |g' | awk '{print $5}')
	S_START=$(cat /var/log/install/time.log | sed -e 's|:| |g' | awk '{print $6}')

	H_END=$(date | sed -e 's|:| |g' | awk '{print $4}')
	M_END=$(date | sed -e 's|:| |g' | awk '{print $5}')
	S_END=$(date | sed -e 's|:| |g' | awk '{print $6}')

	# Strip leading zeros
	H_START=$((10#$H_START))
	M_START=$((10#$M_START))
	S_START=$((10#$S_START))

	H_END=$((10#$H_END))
	M_END=$((10#$M_END))
	S_END=$((10#$S_END))	
	
	if [[ $H_START -gt $H_END ]]; then 
		H_END=$(($H_END + 24))
	fi

	if [[ $M_START -gt $M_END ]]; then
		H_END=$(($H_END - 1))
		M_END=$(($M_END + 60))
	fi

	if [[ $S_START -gt $S_END ]]; then
		M_END=$(($M_END - 1))
		S_END=$(($S_END + 60))
	fi

	H_RUN=$(($H_END - $H_START))
	M_RUN=$(($M_END - $M_START))
	S_RUN=$(($S_END - $S_START))

	echo "${H_RUN} hours: ${M_RUN}.${S_RUN}"
}

# Main
mkdir /var/log/install/chroot
source progress_bar.sh

install_linux > /var/log/install/chroot/install_linux.log 3>&2 2>&1

# Configure clock.
[[ -f /etc/localtime ]] && rm /etc/localtime
ln -s /usr/share/zoneinfo/US/Central /etc/localtime
hwclock --systohc --utc

#bash </dev/tty

configure_users > /var/log/install/chroot/configure_users.log 3>&2 2>&1
install_x > /var/log/install/chroot/install_x.log 3>&2 2>&1
build > /var/log/install/chroot/build.log 3>&2 2>&1

RUN_TIME=$(get_runtime)
export RUN_TIME
export USER
export HOST
SHELL="/bin/zsh"
export SHELL
tput setaf 5 && tput bold && echo "Arch Linux has been installed!" && tput sgr0
python archey

rm progress_bar.sh
rm archey