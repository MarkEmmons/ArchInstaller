#!/bin/bash

BAR="||||||||||||||||||||||||||||||"

SPINNER=('/' '-' '\' '|')
COLS=$(tput cols)

#abs(){
#    [[ $1 -lt 0 ]] && echo $((-1 * $1)) || echo $1
#}
#
#get_percent(){
#    A=$1
#    B=$2
#    if [[ $A -eq $B ]]; then
#        echo "100"
#        return
#    fi
#
#    C=1
#    D=100
#    ABS=$(abs $((100 - ($C * $B))))
#    while [[ $D -gt $ABS ]]; do
#        D=$ABS
#        C=$(($C + 1))
#        ABS=$(abs $((100 - ($C * $B))))
#    done
#
#    C=$(($C - 1))
#    D=$(($B - $A))
#    A=$(($A * $C))
#    B=$(($B * $C))
#
#    if [[ $B -lt 100 ]]; then
#        while [[ $B -lt 100 ]]; do
#            B=$(($B + $D))
#            if [[ $B -gt 100 ]]; then
#                B=100
#            else
#                A=$(($A + 1))
#            fi
#        done
#    else
#        while [[ $B -gt 100 ]]; do
#            B=$(($B - $D))
#            if [[ $B -lt 100 ]]; then
#                B=100
#            else
#                A=$(($A - 1))
#            fi
#        done    
#    fi
#    echo "$A"
#}

progress_bar(){

    FUN_NAME=
    
    # Create padding
    NUM_TABS=$((3 - (${#1} / 8)))
    case $NUM_TABS in
        1)
            FUN_NAME="$1\t"
            ;;
        2)
            FUN_NAME="$1\t\t"
            ;;
        3)
            FUN_NAME="\t\t\t" # Empty string
            ;;
        *)
            FUN_NAME="${1:0:24}" # Given string is too long
            ;;
    esac

    START_TIME=$( date | sed -e 's|:| |g' | awk '{print ((($4*60)+$5)*60) + $6}' )
    
    # Get time elapsed in MM:SS        
    CURRENT_TIME=$( date | sed -e 's|:| |g' | awk '{print ((($4*60)+$5)*60) + $6}' )
    TIME_DIFF=$(($CURRENT_TIME - $START_TIME))
    M=$(($TIME_DIFF / 60))
    S=$(($TIME_DIFF - ($M * 60)))
    
    # Determine padding for right-aligned exit message
    CUR_POS=70
    EXIT_MSG_POS=$(($COLS - 9))
    NUM_SPACES=$(($EXIT_MSG_POS - $CUR_POS))
    SPACES=$(printf "%-${NUM_SPACES}s" " ")
    EXIT_MSG=$(printf "${SPACES// / }  Completed")

    COMPLETED=100
        
    # Print out completed status bar
    { tput setaf 7 && \
        tput bold && \
        echo -ne "\r$FUN_NAME"
        printf "%02d:%02d " $M $S && \
        echo -ne "${SPINNER[((3))]}${BAR} [${COMPLETED}%]" && \
        tput setaf 2 && \
        printf "$EXIT_MSG\n"
        tput sgr0 \
        ;} >&3
}

begin(){
    progress_bar " Getting started" 
}

encrypt(){ 
    progress_bar " Encrypting disk" 
}

partition(){ 
    progress_bar " Partitioning" 
}

update_mirrors(){ 
    progress_bar " Ranking mirrors..." 
}

install_base(){ 
    progress_bar " Installing base system" 
}

install_linux(){ 
    progress_bar " Installing Linux" 
}

configure_users(){ 
    progress_bar " Configuring users" 
}

install_x(){ 
    progress_bar " Installing Xorg" 
}

build(){ 
    progress_bar " Building extras" 
}

tput civis
tput setaf 7 && tput bold && echo "Installing Arch Linux" && tput sgr0
echo ""
tput setaf 7 && tput bold && echo ":: Running installation scripts..." && tput sgr0
begin >/dev/null 3>&2 2>&1
encrypt >/dev/null 3>&2 2>&1
partition >/dev/null 3>&2 2>&1
update_mirrors >/dev/null 3>&2 2>&1
install_base >/dev/null 3>&2 2>&1
tput setaf 7 && tput bold && echo ":: Chrooting into new system..." && tput sgr0
install_linux >/dev/null 3>&2 2>&1
configure_users >/dev/null 3>&2 2>&1
install_x >/dev/null 3>&2 2>&1
build >/dev/null 3>&2 2>&1
tput cnorm
