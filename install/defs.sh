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

SRC="https://raw.githubusercontent.com/MarkEmmons/ArchInstaller/master/install/"
CHROOT="chroot.sh"
PBAR="progress_bar.sh"
ARCHEY="archey"

cache_packages(){

	# See if an old installation is available
	cryptsetup isLuks /dev/sda3 || return

	# Unlock previous device
	echo "Previous installation found, enter passphrase to unlock" >&3
	cryptsetup luksOpen /dev/sda3 lvm < /dev/tty

	STAT_ARRAY=( "linux-api-headers"
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
	"nodejs"
	"Modifying pacstrap"
	"Successfully cached packages" )

	# Initialize progress bar
    progress_bar " Backing up pkg-cache" ${#STAT_ARRAY[@]} "${STAT_ARRAY[@]}" &
    BAR_ID=$!

	# Mount the filesystems
	echo "Mounting former file system"
	mount /dev/ArchLinux/rootvol /mnt > /dev/null
	RET=$?
	while [[ $RET -gt 0 ]]; do
		mount /dev/ArchLinux/rootvol /mnt > /dev/null
		RET=$?
	done

	# TODO: cache {dotfiles, aur packages, .vim/bundle}

	# Backup pacman cache
	echo "Backing up pacman pkg cache"
	tar -cvzf /tmp/pkg.tar.gz --directory /mnt/var/cache/pacman/pkg .

	# Modify pacstrap to untar pkg cache
	echo "Modifying pacstrap"
	sed '/Installing packages to/ i tar -xvf /tmp/pkg.tar.gz --directory /mnt/var/cache/pacman/pkg' -i $(which pacstrap)

	# Unmount before exiting
	umount -R /mnt

	# Close LUKS container
	vgchange -a n ArchLinux
	cryptsetup luksClose lvm

	echo "Successfully cached packages"

	CACHE=1
}

uinfo_dialog(){

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
}
