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

source bar.sh

# Clean disk and enable encryption
prepare(){
	
	# Fetch some extra stuff
	wget https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/disk.txt
	wget https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/mirror.txt
	wget https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/chroot.sh
	wget https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/bar.sh

	# Set time for time-keeping
	rm /etc/localtime
	ln -s /usr/share/zoneinfo/US/Central /etc/localtime
	hwclock --systohc --utc
	
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
}

begin(){

	# Initialize status bar
    START_TIME=$( date | sed -e 's|:| |g' | awk '{print ((($4*60)+$5)*60) + $6}' )
    status_bar "Getting started" &
    BAR_ID=$!

		percent 0
	
	# Enable encryption module
	modprobe -a dm-mod dm_crypt
	
		percent 25

	# Create partitions. Instructions can be modified in disk.txt
	gdisk /dev/sda < disk.txt
	
		percent 100
	wait $BAR_ID
}

# Encrypt the lvm partition then un-encrypt for partitioning
encrypt(){

	# Initialize status bar
    START_TIME=$( date | sed -e 's|:| |g' | awk '{print ((($4*60)+$5)*60) + $6}' )
    status_bar "Encrypting disk" &
    BAR_ID=$!
	
		percent 0
	
	echo "Encrypting disk..."
		percent 10

	echo -n "$CRYPT" | \
	cryptsetup -s 512 --key-file="-" luksFormat /dev/sda3
		percent 45

	echo "Disk successfully encrypted."
		percent 65
	echo "Unlocking disk..."
		percent 85
	echo -n "$CRYPT" | \
	cryptsetup --key-file="-" luksOpen /dev/sda3 lvm #< /dev/tty
		percent 100
	unset CRYPT
	echo
	wait $BAR_ID
}

# Partition
partition(){

	# Initialize status bar
    START_TIME=$( date | sed -e 's|:| |g' | awk '{print ((($4*60)+$5)*60) + $6}' )
    status_bar "Partitioning" &
    BAR_ID=$!
	
		percent 0
	
	# Create a physical volume on top of the opened LUKS container
	pvcreate /dev/mapper/lvm
		percent 10

	# Create the volume group ArchLinux, adding the previously created physical volume to it
	vgcreate ArchLinux /dev/mapper/lvm
		percent 20
	
	# Create all of the logical volumes on the volume group
	lvcreate -L 10G ArchLinux -n rootvol
		percent 25
	lvcreate -L 2G ArchLinux -n swapvol
		percent 30
	lvcreate -L 20G ArchLinux -n homevol
		percent 35
	lvcreate -l +100%FREE ArchLinux -n pool
		percent 40

	# Format the filesystems on each logical volume
		percent 45
	mkfs.btrfs /dev/mapper/ArchLinux-rootvol
		percent 50
	mkfs.btrfs /dev/mapper/ArchLinux-homevol
		percent 55
	mkfs.btrfs /dev/mapper/ArchLinux-pool
		percent 60
	mkfs.ext4 /dev/sda2 <<< "y"
		percent 65
	mkswap /dev/mapper/ArchLinux-swapvol
		percent 70

	# Mount the filesystems
		percent 75
	mount /dev/ArchLinux/rootvol /mnt
		percent 80
	mkdir /mnt/home /mnt/boot
		percent 85
	mount /dev/ArchLinux/homevol /mnt/home
		percent 90
	mount /dev/sda2 /mnt/boot
		percent 95
	swapon /dev/ArchLinux/swapvol
	
		percent 100
	wait $BAR_ID
}
	
# Update mirror list for faster install times
update_mirrors(){

	# Initialize status bar
    START_TIME=$( date | sed -e 's|:| |g' | awk '{print ((($4*60)+$5)*60) + $6}' )
    status_bar "Updating mirror list" &
    BAR_ID=$!
	
		percent 0
	#cp -vf /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
	#sed '/^#\S/ s|#||' -i /etc/pacman.d/mirrorlist.backup
	#rankmirrors -n 15 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist
	echo "Ranking mirrors..."
		percent 25
	wget https://raw.github.com/MarkEmmons/armrr/master/armrr
		percent 50
	chmod u+x armrr
		percent 75
	./armrr US < mirror.txt
		percent 100
	wait $BAR_ID
}

# Refresh mirrors and install the base system
install_base(){

	# Initialize status bar
    START_TIME=$( date | sed -e 's|:| |g' | awk '{print ((($4*60)+$5)*60) + $6}' )
    status_bar "Installing base system" &
    BAR_ID=$!
	
		percent 0
		percent 33
	pacman -Syy
		percent 67
	pacstrap /mnt base base-devel grub-bios
		percent 100
	wait $BAR_ID
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
	tput cnorm
	reboot
}

tput civis
clear

echo "Preparing to install ArchLinux"
echo

prepare
begin >begin.log 3>&2 2>&1
encrypt >encrypt.log 3>&2 2>&1
partition >partition.log 3>&2 2>&1
update_mirrors >update_mirrors.log 3>&2 2>&1
install_base >install_base.log 3>&2 2>&1
chroot_mnt
finish


heresafunction >test1.log 3>&2 2>&1
newfunction >test2.log 3>&2 2>&1
