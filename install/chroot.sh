# Generate locales
cp /etc/locale.gen /etc/locale.gen.backup
sed 's|#en_US|en_US|' -i /etc/locale.gen
locale-gen

# Export locales
echo "LANG=en_US.UTF-8" > /etc/locale.conf
export LANG=en_US.UTF-8

# SSD Optimization
systemctl enable dhcpcd.service
systemctl enable fstrim.service
systemctl enable fstrim.timer

# Configure clock
ln -s /usr/share/zoneinfo/US/Central /etc/localtime 
hwclock --systohc --utc

# Add host
HOST1="a"
HOST2="b"
while [ "$HOST1" != "$HOST2" ]; do
	printf "Choose a host name: "
	read HOST1 < /dev/tty
	printf "Verify host name: "
	read HOST2 < /dev/tty
	if [ "$HOST1" != "$HOST2" ]; then
		echo "Host name verification failed. Try again."
	fi
done
echo "$HOST1" > /etc/hostname
unset $HOST1; unset $HOST2

# Install Linux
cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.backup
sed 's|MODULES=\"\"|MODULES=\"btrfs\"|' -i /etc/mkinitcpio.conf
grep "^[^#;]" /etc/mkinitcpio.conf | grep "HOOKS=" | sed 's|filesystems|encrypt lvm2 filesystems|' -i /etc/mkinitcpio.conf
mkinitcpio -p linux

# Install and configure grub
pacman -S grub wget curl openssh gdb zsh dialog wpa_actiond wpa_supplicant git python2 tmux < /dev/tty
sed 's|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"cryptdevice=/dev/sda3:ArchLinux root=/dev/mapper/ArchLinux-rootvol\"|' -i /etc/default/grub
grub-install --target=i386-pc --recheck /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

# Choose password for root and change default shell to zsh
echo "Choose password for root: "
passwd < /dev/tty
chsh -s $(which zsh)

# Download post-installation build scripts
wget https://raw.github.com/MarkEmmons/ArchInstaller/master/install/create_admin.sh
mv create_admin.sh /usr/sbin/create_admin
chmod u+x /usr/sbin/create_admin

wget https://raw.github.com/MarkEmmons/ArchInstaller/master/install/X.sh
mv X.sh /usr/sbin/inx
chmod a+x /usr/sbin/inx

# wget https://raw.github.com/markemmons/Dotfilr/master/dotfilr.sh
wget https://raw.github.com/MarkEmmons/Dotfilr/master/Arch/wDotfilr.sh
mv wDotfilr.sh /usr/sbin/dotfilr
chmod a+x /usr/sbin/dotfilr