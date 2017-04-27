#!/bin/bash

#https://aur.archlinux.org/cgit/aur.git/snapshot/b43-firmware.tar.gz

PACKAGES1="mesa xf86-video-vesa xf86-video-intel xf86-video-fbdev xf86-input-synaptics alsa-utils"
PACKAGES2="i3 i3status dmenu conky xterm chromium stow xbindkeys"
PACKAGES3="xorg-server xorg-server-utils xorg-xinit xorg-xclock xorg-twm"

x_for_vbox(){
	sudo pacman -S xorg
	sudo pacman -S virtualbox-guest-modules-arch virtualbox-guest-utils
	sudo modprobe -a vboxguest vboxsf vboxvideo
}

x_for_thinkpad(){
	sudo Xorg :0 -configure
	sudo mv /root/xorg.conf.new /etc/X11/xorg.conf
}

sudo pacman -S $PACKAGES1
sudo pacman -S $PACKAGES2
sudo pacman -S $PACKAGES3

#x_for_thinkpad
x_for_vbox

echo "exec 13" > .xinitrc

[[ -f .Xauthority ]] && rm .Xauthority
sudo rm /usr/sbin/inx