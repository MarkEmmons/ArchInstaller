#!/bin/bash

DIALOG_OK=0
DIALOG_CANCEL=1
DIALOG_ESC=255

ERR_MESSAGE=""

RET_CODE=0

crypt1=
crypt2=
host=
root1=
root2=
user=
pass1=
pass2=

# Get all required user-information at the top
get_user_inputs(){
	
	while [[ $RET_CODE -ne 1 && $RET_CODE -ne 250 ]]; do
    
		IFS=$'\n'
		set -f
		exec 3>&1
		
		values=$(dialog --title "Arch Linux Installer" \
					--ok-label "Submit" \
					--backtitle "Arch Linux" \
					--colors \
					--insecure \
					--mixedform "Enter relevant installation data $ERR_MESSAGE" \
		16 65 0 \
			"Luks Passphrase:"          1 1 ""   1 25 30 0 1 \
			"Retype Luks Passphrase:"   2 1 ""   2 25 30 0 1 \
			"Hostname:"                 3 1 "$host"     3 25 20 0 0 \
			"Root Password:"            4 1 ""    4 25 25 0 1 \
			"Retype Root Password:"     5 1 ""    5 25 25 0 1 \
			"Username:"                 6 1 "$user"     6 25 20 0 0 \
			"Password:"                 7 1 ""    7 25 25 0 1 \
			"Retype Password:"          8 1 ""    8 25 25 0 1 \
		2>&1 1>&3)
		RET_CODE=$?
		set $values
		crypt1=$1 crypt2=$2 host=$3 root1=$4 root2=$5 user=$6 pass1=$7 pass2=$8
		
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
			if [[ -z $crypt1 || -z $crypt2 || -z $host || -z $root1 || \
				-z $root2 || -z $user || -z $pass1 || -z $pass2 ]]; then
				ERR_MESSAGE="\Z1(Fill all fields)"
			elif [[ $crypt1 != $crypt2 || $root1 != $root2 || \
				$pass1 != $pass2 ]]; then
				ERR_MESSAGE="\Z1(Two passwords do not match)"
			else
				clear
				unset crypt2; unset root2;  unset pass2
				
				sed "s|HOST_NAME_TO_BE|\"$host\"|" -i chroot.sh
				sed "s|ROOT_PASS_TO_BE|\"$root1\"|" -i chroot.sh
				sed "s|USER_NAME_TO_BE|\"$user\"|" -i chroot.sh
				sed "s|USER_PASS_TO_BE|\"$pass1\"|" -i chroot.sh
				
				unset host; unset root1; unset user; unset pass1
				return
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
}

# Clean disk and enable encryption
prepare(){
	
	# Manually clear disk for consistent results
	#sgdisk --zap-all /dev/sda
	
	# Enable encryption module
	modprobe -a dm-mod dm_crypt

	# Create partitions. /Instructions can be modified in disk.txt
	gdisk /dev/sda < disk.txt	
	echo "y" > yes.txt
}

# Encrypt the lvm partition then un-encrypt for partitioning
encrypt(){
	echo -n "$crypt1" | \
	cryptsetup -s 512 --key-file="-" luksFormat /dev/sda3
	#cryptsetup -s 512 luksFormat /dev/sda3 < /dev/tty
	echo "Disk successfully encrypted."
	echo "Unlocking disk..."
	echo -n "$crypt1" | \
	cryptsetup --key-file="-" luksOpen /dev/sda3 lvm #< /dev/tty
	unset crypt1
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

# Unmount and reboot
finish(){
	umount -R /mnt
	swapoff /dev/ArchLinux/swapvol
	reboot
}

get_user_inputs

clear

echo "Preparing to install ArchLinux"
echo

wget https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/disk.txt
wget https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/mirror.txt
wget https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/chroot.sh

prepare
encrypt
partition
update_mirrors
install_base

# Create fstab and chroot into the new system
cp .zshrc /mnt/root/.zshrc
genfstab -U -p /mnt >> /mnt/etc/fstab
arch-chroot /mnt /bin/bash < chroot.sh

finish