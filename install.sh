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

CACHE=0

cache_packages(){

	# Unlock previous device
	echo "Previous installation found, enter passphrase to unlock" >&3
	cryptsetup luksOpen /dev/sda3 lvm < /dev/tty

	# Mount the filesystems
	mount /dev/ArchLinux/rootvol /mnt
	
	# Backup pacman cache
	tar -cvzf /tmp/pkg.tar.gz /mnt/var/cache/pacman/pkg

	# Unmount before exiting
	umount -R /mnt

	# Close LUKS container
	vgchange -a n ArchLinux
	cryptsetup luksClose lvm
	
	CACHE=1
}

# Clean disk and enable encryption
prepare(){
	
	# Fetch some extra stuff
	wget https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/disk.txt
	wget https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/zap.txt
	wget https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/mirror.txt
	wget https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/chroot.sh
	wget https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/progress_bar.sh
	wget https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/archey

	# Dissalow screen blanking for installation
	setterm -blank 0
	
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
				sed "s|CACHE_VAL_TO_BE|\"$CACHE\"|" -i chroot.sh
				
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

    STAT_ARRAY=( "" )

	# Initialize progress bar
    progress_bar " Getting started" ${#STAT_ARRAY[@]} "${STAT_ARRAY[@]}" &
    BAR_ID=$!

	# Enable encryption module
	modprobe -a dm-mod dm_crypt
	
	# Zap any former entry
	sgdisk --zap-all /dev/sda
	
	# Create partitions. Instructions can be modified in disk.txt
	gdisk /dev/sda < disk.txt
	
	wait $BAR_ID
}

# Encrypt the lvm partition then un-encrypt for partitioning
encrypt(){

    STAT_ARRAY=( "Encrypting disk"
    "Disk successfully encrypted"
    "Unlocking disk"
	"Disk successfully unlocked" )

	# Initialize progress bar
    progress_bar " Encrypting disk" ${#STAT_ARRAY[@]} "${STAT_ARRAY[@]}" &
    BAR_ID=$!
	
	echo "Encrypting disk..."
	echo -n "$CRYPT" | \
	cryptsetup -s 512 --key-file="-" luksFormat /dev/sda3

	echo "Disk successfully encrypted."
	echo "Unlocking disk..."
	echo -n "$CRYPT" | \
	cryptsetup --key-file="-" luksOpen /dev/sda3 lvm #< /dev/tty
	unset CRYPT
	echo "Disk successfully unlocked."
	echo
	wait $BAR_ID
}

# Partition
partition(){

    STAT_ARRAY=( "Physical volume \"/dev/mapper/lvm\" successfully created."
    "Logical volume \"homevol\" created."
    "/dev/mapper/ArchLinux-rootvol"
    "/dev/mapper/ArchLinux-homevol"
    "/dev/mapper/ArchLinux-pool"
    "Creating filesystem with"
    "Allocating group tables:"
    "Setting up swapspace version" )

	# Initialize progress bar
    progress_bar " Partitioning" ${#STAT_ARRAY[@]} "${STAT_ARRAY[@]}" &
    BAR_ID=$!
	
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
	mkfs.ext4 /dev/sda2 <<< "y"
	mkswap /dev/mapper/ArchLinux-swapvol

	# Mount the filesystems
	mount /dev/ArchLinux/rootvol /mnt
	mkdir /mnt/home /mnt/boot
	mount /dev/ArchLinux/homevol /mnt/home
	mount /dev/sda2 /mnt/boot
	swapon /dev/ArchLinux/swapvol
	
	wait $BAR_ID
}
	
# Update mirror list for faster install times
update_mirrors(){

	STAT_ARRAY=( "Ranking mirrors..."
	"Got armrr"
	"Running armrr..."
	"Got new mirror list" )

	# Initialize progress bar
    progress_bar " Updating mirror list" ${#STAT_ARRAY[@]} "${STAT_ARRAY[@]}" &
    BAR_ID=$!
	
	#cp -vf /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
	#sed '/^#\S/ s|#||' -i /etc/pacman.d/mirrorlist.backup
	#rankmirrors -n 15 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist
	echo "Ranking mirrors..."
	wget https://raw.github.com/MarkEmmons/armrr/master/armrr
	echo "Got armrr"
	chmod u+x armrr
	echo "Running armrr..."
	./armrr US < mirror.txt
	echo "Got new mirror list"
	wait $BAR_ID
}

# Refresh mirrors and install the base system
install_base(){

	# Initialize progress bar
    #progress_bar " Installing base system" ${#STAT_ARRAY[@]} "${STAT_ARRAY[@]}" &
    #BAR_ID=$!
	
	pacman -Syy
	pacstrap /mnt base base-devel grub-bios >&3
	#wait $BAR_ID
}

# Create fstab and chroot into the new system
chroot_mnt(){

	# Copy over relevant files
	cp progress_bar.sh /mnt/progress_bar.sh
	cp .zshrc /mnt/root/.zshrc
	mkdir /mnt/var/log/install
	mv *.log /mnt/var/log/install
	mv archey /mnt/archey

	# Generate an fstab
	genfstab -U -p /mnt >> /mnt/etc/fstab
	
	arch-chroot /mnt /bin/bash < chroot.sh
}

# Unmount and reboot
finish(){
	umount -R /mnt
	swapoff /dev/ArchLinux/swapvol
	read -n1 -rsp $'Press any key to continue or Ctrl+C to exit...\n' < /dev/tty
	tput cnorm
	reboot
}

tput civis
clear

echo "Preparing to install ArchLinux"
echo

prepare

source progress_bar.sh

[[ -b /dev/sda3 ]] && cache_packages >cache_packages.log 3>&2 2>&1

tput setaf 7 && tput bold && echo "Installing Arch Linux" && tput sgr0
echo ""
tput setaf 7 && tput bold && echo ":: Running installation scripts..." && tput sgr0
begin >begin.log 3>&2 2>&1
encrypt >encrypt.log 3>&2 2>&1
partition >partition.log 3>&2 2>&1
update_mirrors >update_mirrors.log 3>&2 2>&1
install_base >install_base.log 3>&2 2>&1
tput setaf 7 && tput bold && echo ":: Chrooting into new system..." && tput sgr0
chroot_mnt
finish