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
	
	# Create all of the logical volumes on the volume group
	lvcreate -L 10G ArchLinux -n rootvol
	lvcreate -L 2G ArchLinux -n swapvol
	lvcreate -L 20G ArchLinux -n homevol
	lvcreate -l +100%FREE ArchLinux -n pool

	# Format the filesystems on each logical volume
	mkfs.btrfs /dev/mapper/ArchLinux-rootvol
	mkfs.btrfs /dev/mapper/ArchLinux-homevol
	mkfs.btrfs /dev/mapper/ArchLinux-pool
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