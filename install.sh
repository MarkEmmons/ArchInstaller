#!/bin/bash

wget https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/defs.sh"
source defs.sh

# Clean disk and enable encryption
prepare(){

    tput civis
    clear

    echo "Preparing to install ArchLinux"
    echo

    # Fetch some extra stuff
	wget "$SRC$CHROOT"
	wget "$SRC$PBAR"
	wget "$SRC$ARCHEY"

	# Dissalow screen blanking for installation
	setterm -blank 0

	# Set time for time-keeping
	rm /etc/localtime
	ln -s /usr/share/zoneinfo/US/Central /etc/localtime
	hwclock --systohc --utc

    uinfo_dialog

	# Echo start time
	date > time.log
}

begin(){

    STAT_ARRAY=( "Enabling encryption"
	"Zapping former partitions"
	"Creating new partitions"
	"Done" )

	# Initialize progress bar
    progress_bar " Getting started" ${#STAT_ARRAY[@]} "${STAT_ARRAY[@]}" &
    BAR_ID=$!

	# Enable encryption module
	echo "Enabling encryption"
	modprobe -a dm-mod dm_crypt

	# Zap any former entry
	echo "Zapping former partitions"
	sgdisk --zap-all /dev/sda

	# Create partitions. Instructions can be modified in disk.txt
	echo "Creating new partitions"
	gdisk /dev/sda <<< "n


+1007K
ef02
n


+100M

n



8e00
w
Y
"

	echo "Done"
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
	cryptsetup --key-file="-" luksOpen /dev/sda3 lvm
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
	./armrr US <<< "n
y"
	echo "Got new mirror list"
	wait $BAR_ID
}

# Refresh mirrors and install the base system
install_base(){

	STAT_ARRAY=( "Creating install root at"
	"linux-api-headers"
	"pambase"
	"dhcpcd"
	"man-pages"
	"git"
	"python2"
	"http-parser"
	"sudo"
	"xterm"
	"nodejs"
	"feh"
	"members in group base"
	"installing linux-api-headers"
	"installing dhcpcd"
	"installing man-pages"
	"installing pacman"
	"installing autoconf"
	"installing automake"
	"installing binutils"
	"installing bison"
	"installing fakeroot"
	"installing gcc"
	"installing guile"
	"installing make"
	"installing patch"
	"may fail on some machines"
	"Updating system user accounts"
	"Rebuilding certificate stores" )

	# Initialize progress bar
    progress_bar " Installing base system" ${#STAT_ARRAY[@]} "${STAT_ARRAY[@]}" &
    BAR_ID=$!

	#pacman -Syy
	pacstrap /mnt base base-devel grub-bios ttf-liberation

	# Copy over relevant files
	mkdir /mnt/var/log/install
	mv *.log /mnt/var/log/install
	mv archey /mnt/archey
	cp progress_bar.sh /mnt/progress_bar.sh
	cp /etc/zsh/zshrc /mnt/root/.zshrc

	# Generate an fstab
	genfstab -U -p /mnt >> /mnt/etc/fstab

	wait $BAR_ID
}

# Create fstab and chroot into the new system
chroot_mnt(){
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

prepare

# See if we can put this in prepare
source progress_bar.sh

tput setaf 7 && tput bold && echo "Installing Arch Linux" && tput sgr0
echo ""
tput setaf 7 && tput bold && echo ":: Running installation scripts..." && tput sgr0

cache_packages >cache_packages.log 3>&2 2>&1

sed "s|CACHE_VAL_TO_BE|\"$CACHE\"|" -i chroot.sh

begin >begin.log 3>&2 2>&1
encrypt >encrypt.log 3>&2 2>&1
partition >partition.log 3>&2 2>&1
update_mirrors >update_mirrors.log 3>&2 2>&1
install_base >install_base.log 3>&2 2>&1

tput setaf 7 && tput bold && echo ":: Chrooting into new system..." && tput sgr0

chroot_mnt
finish
