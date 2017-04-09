#!/bin/bash

# Clean disk and enable encryption
prepare(){
	
	# Manually clear disk for consistent results
	#sgdisk --zap-all /dev/sda
	
	# Enable encryption module
	modprobe -a dm-mod dm_crypt

	# Create partitions. /Instructions can be modified in disk.txt
	gdisk /dev/sda < disk.txt
}

# Encrypt the lvm partition then un-encrypt for partitioning
encrypt(){
	cryptsetup -s 512 luksFormat /dev/sda3 < /dev/tty
	echo "Disk successfully encrypted."
	echo "Unlocking disk..."
	cryptsetup luksOpen /dev/sda3 lvm < /dev/tty
	echo
}

# Partition
partition(){
	# Create a physical volume on top of the opened LUKS container
	pvcreate /dev/mapper/lvm

	# Create the volume group ArchLinux, adding the previously created physical volume to it
	vgcreate ArchLinux /dev/mapper/lvm

	# Determine disk space
	DISK=$(pvs | grep /dev/mapper/lvm | awk '{print $5}')
	d=$(echo "${DISK//[!0-9]/}")

	swapt=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')
	swap=$(echo "$swapt / 1000" | bc)

    if [[ $(echo "$d < 800" | bc) == 1 ]]; then
        echo "At least 8G required for this installation."
		exit
    else
		root=$(echo "0.001 * $d" | bc)
		if [[ $(echo "$d < 2000" | bc) == 1 ]]; then
			root=2
			swap=512
		fi
		if [[ $(echo "$d > 20000" | bc) == 1 ]]; then
			root=20
		fi
    fi

	
	# Create all of the logical volumes on the volume group
	lvcreate -L ${root}G ArchLinux -n rootvol
	lvcreate -L ${swap}M ArchLinux -n swapvol
	lvcreate -l +100%FREE ArchLinux -n homevol

	# Format the filesystems on each logical volume
	mkfs.btrfs /dev/mapper/ArchLinux-rootvol
	mkfs.btrfs /dev/mapper/ArchLinux-homevol
	mkfs.ext4 /dev/sda2 < /dev/tty
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
	cp -vf /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
	echo "Ranking mirrors, this may take a while..."
	sed '/^#\S/ s|#||' -i /etc/pacman.d/mirrorlist.backup
	rankmirrors -n 15 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist
}

# Refresh mirrors and install the base system
install_base(){
	pacman -Syy
	pacstrap /mnt base base-devel grub-bios
}

# Unmount and reboot
finish(){
	umount  -R /mnt
	swapoff /dev/ArchLinux/swapvol
	reboot
}

clear

echo "Preparing to install ArchLinux"
echo

wget https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/disk.txt
wget https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/chroot.sh

prepare
encrypt
partition
update_mirrors
install_base

# Create fstab and chroot into the new system
genfstab -U -p /mnt >> /etc/fstab
arch-chroot /mnt /bin/bash < chroot.sh

finish