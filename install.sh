#!/bin/bash

DIALOG_OK=0
DIALOG_CANCEL=1
DIALOG_ESC=255

ERR_MESSAGE=""

RET_CODE=0

CRYPT=
RE_CRYPT=
HOST=
ROOT=
RE_ROOT=
USER=
PASS=
RE_PASS=

# Clean disk and enable encryption
prepare(){
	
	# Fetch some extra stuff
	wget https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/disk.txt
	wget https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/mirror.txt
	wget https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/localtime
	wget https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/chroot.sh

	# Set time for time-keeping
	rm /etc/localtime
	mv localtime /etc/localtime
	
	while [[ $RET_CODE -ne 1 && $RET_CODE -ne 250 ]]; do
    
		IFS=$'\n'
		set -f
		exec 3>&1
		
		VALUES=$(dialog --title "Arch Linux Installer" \
					--ok-label "Submit" \
					--backtitle "Arch Linux" \
					--colors \
					--insecure \
					--mixedform "Enter relevant installation data $ERR_MESSAGE" \
		16 65 0 \
			"Luks Passphrase:"          1 1 ""   1 25 30 0 1 \
			"Retype Luks Passphrase:"   2 1 ""   2 25 30 0 1 \
			"Hostname:"                 3 1 "$HOST"     3 25 20 0 0 \
			"Root Password:"            4 1 ""    4 25 25 0 1 \
			"Retype Root Password:"     5 1 ""    5 25 25 0 1 \
			"Username:"                 6 1 "$USER"     6 25 20 0 0 \
			"Password:"                 7 1 ""    7 25 25 0 1 \
			"Retype Password:"          8 1 ""    8 25 25 0 1 \
		2>&1 1>&3)
		RET_CODE=$?
		set $VALUES
		CRYPT=$1 RE_CRYPT=$2 HOST=$3 ROOT=$4 RE_ROOT=$5 USER=$6 PASS=$7 RE_PASS=$8
		
		exec 3>&-
		set +f
		unset IFS
		
		case $RET_CODE in
		$DIALOG_CANCEL)
			dialog \
			--clear \
			--backtitle "$backtitle" \
			--yesno "Really quit?" 10 30
			case $? in
			$DIALOG_OK)
				clear
				break
				;;
			$DIALOG_CANCEL)
				RET_CODE=99
				;;
			esac
			;;
		$DIALOG_OK)
			if [[ -z $CRYPT || -z $RE_CRYPT || -z $HOST || -z $ROOT || \
				-z $RE_ROOT || -z $USER || -z $PASS || -z $RE_PASS ]]; then
				ERR_MESSAGE="\Z1(Fill all fields)"
			elif [[ $CRYPT != $RE_CRYPT || $ROOT != $RE_ROOT || \
				$PASS != $RE_PASS ]]; then
				ERR_MESSAGE="\Z1(Two passwords do not match)"
			else
				clear
				unset RE_CRYPT; unset RE_ROOT;  unset RE_PASS
				
				sed "s|HOST_NAME_TO_BE|\"$HOST\"|" -i chroot.sh
				sed "s|ROOT_PASS_TO_BE|\"$ROOT\"|" -i chroot.sh
				sed "s|USER_NAME_TO_BE|\"$USER\"|" -i chroot.sh
				sed "s|USER_PASS_TO_BE|\"$PASS\"|" -i chroot.sh
				
				unset HOST; unset ROOT; unset USER; unset PASS
				break
			fi
			;;
		$DIALOG_ESC)
			clear
			echo "Escape key pressed"
			exit
			;;
		*)
			clear
			echo "Return code was $RET_CODE"
			exit
			;;
		esac
	done
	
	# Echo start time
	date > time.log
	
	# Enable encryption module
	modprobe -a dm-mod dm_crypt

	# Create partitions. /Instructions can be modified in disk.txt
	gdisk /dev/sda < disk.txt	
	echo "y" > yes.txt
}

# Encrypt the lvm partition then un-encrypt for partitioning
encrypt(){
	echo "Encrypting disk..."
	echo -n "$CRYPT" | \
	cryptsetup -s 512 --key-file="-" luksFormat /dev/sda3
	#cryptsetup -s 512 luksFormat /dev/sda3 < /dev/tty
	echo "Disk successfully encrypted."
	echo "Unlocking disk..."
	echo -n "$CRYPT" | \
	cryptsetup --key-file="-" luksOpen /dev/sda3 lvm #< /dev/tty
	unset CRYPT
	echo
}

# Partition
partition(){
	# Create a physical volume on top of the opened LUKS container
	pvcreate /dev/mapper/lvm

	# Create the volume group ArchLinux, adding the previously created physical volume to it
	vgcreate ArchLinux /dev/mapper/lvm
	
	# Create all of the logical volumes on the volume group
	lvcreate -L 10G ArchLinux -n rootvol
	lvcreate -L 2G ArchLinux -n swapvol
	lvcreate -L 20G ArchLinux -n homevol
	lvcreate -l +100%FREE ArchLinux -n pool

	# Format the filesystems on each logical volume
	mkfs.btrfs /dev/mapper/ArchLinux-rootvol
	mkfs.btrfs /dev/mapper/ArchLinux-homevol
	mkfs.btrfs /dev/mapper/ArchLinux-pool
	mkfs.ext4 /dev/sda2 < yes.txt
	mkswap /dev/mapper/ArchLinux-swapvol

	# Mount the filesystems
	mount /dev/ArchLinux/rootvol /mnt
	mkdir /mnt/home /mnt/boot
	mount /dev/ArchLinux/homevol /mnt/home
	mount /dev/sda2 /mnt/boot
	swapon /dev/ArchLinux/swapvol
}
	
# Update mirror list for faster install times
update_mirrors(){
	#cp -vf /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
	#sed '/^#\S/ s|#||' -i /etc/pacman.d/mirrorlist.backup
	#rankmirrors -n 15 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist
	echo "Ranking mirrors..."
	wget https://raw.github.com/MarkEmmons/armrr/master/armrr
	chmod u+x armrr
	./armrr US < mirror.txt
}

# Refresh mirrors and install the base system
install_base(){
	pacman -Syy
	pacstrap /mnt base base-devel grub-bios
}

# Create fstab and chroot into the new system
chroot_mnt(){
	cp .zshrc /mnt/root/.zshrc
	mkdir /mnt/var/log/install
	mv *.log /mnt/var/log/install

	genfstab -U -p /mnt >> /mnt/etc/fstab
	arch-chroot /mnt /bin/bash < chroot.sh
}

# Unmount and reboot
finish(){
	umount -R /mnt
	swapoff /dev/ArchLinux/swapvol
	reboot
}

clear

echo "Preparing to install ArchLinux"
echo

prepare
encrypt
partition
update_mirrors
install_base
chroot_mnt
finish