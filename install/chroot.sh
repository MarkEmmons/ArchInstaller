#!/bin/bash

HOST=HOST_NAME_TO_BE
ROOT=ROOT_PASS_TO_BE
USER=USER_NAME_TO_BE
PASS=USER_PASS_TO_BE

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
wget https://raw.github.com/MarkEmmons/ArchInstaller/master/install/build.sh
mv build.sh /usr/sbin/build
chmod a+x /usr/sbin/build

wget https://raw.github.com/MarkEmmons/ArchInstaller/master/install/user_scripts.sh
mv user_scripts.sh /usr/bin/user_scripts
chmod a+x /usr/bin/user_scripts