#!/bin/bash

# Add user
USER1="a"
USER2="b"
while [ "$USER1" != "$USER2" ]; do
	printf "Choose a user name: "
	read USER1
	printf "Verify user name: "
	read USER2
	if [ "$USER1" != "$USER2" ]; then
		echo "User name verification failed. Try again."
	fi
done

useradd -m -G wheel -s /bin/zsh $USER1
passwd $USER1
sed "s/^root ALL=(ALL) ALL/root ALL=(ALL) ALL\n$USER1 ALL=(ALL) ALL/" -i /etc/sudoers

rm /usr/sbin/create_admin