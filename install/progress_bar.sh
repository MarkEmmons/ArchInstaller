#!/bin/bash

BARS=( "                              "
"                              "
"                              "
"                              "
"|                             "
"|                             "
"|                             "
"||                            "
"||                            "
"||                            "
"|||                           "
"|||                           "
"|||                           "
"|||                           "
"||||                          "
"||||                          "
"||||                          "
"|||||                         "
"|||||                         "
"|||||                         "
"||||||                        "
"||||||                        "
"||||||                        "
"||||||                        "
"|||||||                       "
"|||||||                       "
"|||||||                       "
"||||||||                      "
"||||||||                      "
"||||||||                      "
"|||||||||                     "
"|||||||||                     "
"|||||||||                     "
"||||||||||                    "
"||||||||||                    "
"||||||||||                    "
"||||||||||                    "
"|||||||||||                   "
"|||||||||||                   "
"|||||||||||                   "
"||||||||||||                  "
"||||||||||||                  "
"||||||||||||                  "
"|||||||||||||                 "
"|||||||||||||                 "
"|||||||||||||                 "
"|||||||||||||                 "
"||||||||||||||                "
"||||||||||||||                "
"||||||||||||||                "
"|||||||||||||||               "
"|||||||||||||||               "
"|||||||||||||||               "
"||||||||||||||||              "
"||||||||||||||||              "
"||||||||||||||||              "
"||||||||||||||||              "
"|||||||||||||||||             "
"|||||||||||||||||             "
"|||||||||||||||||             "
"||||||||||||||||||            "
"||||||||||||||||||            "
"||||||||||||||||||            "
"|||||||||||||||||||           "
"|||||||||||||||||||           "
"|||||||||||||||||||           "
"||||||||||||||||||||          "
"||||||||||||||||||||          "
"||||||||||||||||||||          "
"||||||||||||||||||||          "
"|||||||||||||||||||||         "
"|||||||||||||||||||||         "
"|||||||||||||||||||||         "
"||||||||||||||||||||||        "
"||||||||||||||||||||||        "
"||||||||||||||||||||||        "
"|||||||||||||||||||||||       "
"|||||||||||||||||||||||       "
"|||||||||||||||||||||||       "
"|||||||||||||||||||||||       "
"||||||||||||||||||||||||      "
"||||||||||||||||||||||||      "
"||||||||||||||||||||||||      "
"|||||||||||||||||||||||||     "
"|||||||||||||||||||||||||     "
"|||||||||||||||||||||||||     "
"||||||||||||||||||||||||||    "
"||||||||||||||||||||||||||    "
"||||||||||||||||||||||||||    "
"||||||||||||||||||||||||||    "
"|||||||||||||||||||||||||||   "
"|||||||||||||||||||||||||||   "
"|||||||||||||||||||||||||||   "
"||||||||||||||||||||||||||||  "
"||||||||||||||||||||||||||||  "
"||||||||||||||||||||||||||||  "
"||||||||||||||||||||||||||||| "
"||||||||||||||||||||||||||||| "
"||||||||||||||||||||||||||||| "
"||||||||||||||||||||||||||||||"
"||||||||||||||||||||||||||||||" )

SPINNER=('/' '-' '\' '|')
COLS=$(tput cols)

abs(){
    [[ $1 -lt 0 ]] && echo $((-1 * $1)) || echo $1
}

get_percent(){
    A=$1
    B=$2
    if [[ $A -eq $B ]]; then
        echo "100"
        return
    fi

    C=1
    D=100
    ABS=$(abs $((100 - ($C * $B))))
    while [[ $D -gt $ABS ]]; do
        D=$ABS
        C=$(($C + 1))
        ABS=$(abs $((100 - ($C * $B))))
    done

    C=$(($C - 1))
    D=$(($B - $A))
    A=$(($A * $C))
    B=$(($B * $C))

    if [[ $B -lt 100 ]]; then
        while [[ $B -lt 100 ]]; do
            B=$(($B + $D))
            if [[ $B -gt 100 ]]; then
                B=100
            else
                A=$(($A + 1))
            fi
        done
    else
        while [[ $B -gt 100 ]]; do
            B=$(($B - $D))
            if [[ $B -lt 100 ]]; then
                B=100
            else
                A=$(($A - 1))
            fi
        done    
    fi
    echo "$A"
}

progress_bar(){

    # Get name of log file to scan
    LOG_FILE=$(readlink /proc/self/fd/2)
    BAR=${BARS[0]}

    FUN_NAME=
    ARR_LEN=$2
    STAT_ARRAY=("$@")
    
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
            FUN_NAME="${1:0:23} " # Given string is too long
            ;;
    esac

    i=2
    SPIN=0
    LINE=${STAT_ARRAY[$i]}
    COMPLETED=0
    START_TIME=$( date | sed -e 's|:| |g' | awk '{print ((($4*60)+$5)*60) + $6}' )
    
    while [[ $i -le $(($ARR_LEN + 1)) ]]; do

        # Determine bar length
        grep "$LINE" $LOG_FILE >/dev/null
        if [[ $? -eq 0 ]]; then
            i=$(($i + 1))
            COMPLETED=$(get_percent $(($i-2)) $ARR_LEN)
            BAR=${BARS[$COMPLETED]}
            LINE=${STAT_ARRAY[$i]}
        fi

        # Get time elapsed in MM:SS        
        CURRENT_TIME=$( date | sed -e 's|:| |g' | awk '{print ((($4*60)+$5)*60) + $6}' )
        TIME_DIFF=$(($CURRENT_TIME - $START_TIME))
        M=$(($TIME_DIFF / 60))
        S=$(($TIME_DIFF - ($M * 60)))        

        # Print out status bar
        { tput setaf 7 && \
            tput bold && \
            echo -ne "\r$FUN_NAME"
            printf "%02d:%02d " $M $S && \
            echo -ne "${SPINNER[(($SPIN))]}${BAR} [${COMPLETED}%]" && \
            tput sgr0 \
            ;} >&3

        SPIN=$((($SPIN + 1) % 4))
        sleep 0.15
    done

    # In case it isn't already
    COMPLETED=100
    BAR=${BARS[100]}
    
    # Determine padding for right-aligned exit message
    CUR_POS=70
    EXIT_MSG_POS=$(($COLS - 9))
    NUM_SPACES=$(($EXIT_MSG_POS - $CUR_POS))
    SPACES=$(printf "%-${NUM_SPACES}s" " ")
    EXIT_MSG=$(printf "${SPACES// / }  Completed")
        
    # Print out completed status bar
    { tput setaf 7 && \
        tput bold && \
        tput sc && \
        echo -ne "\r$FUN_NAME"
        printf "%02d:%02d " $M $S && \
        echo -ne "${SPINNER[((3))]}${BAR} [${COMPLETED}%]" && \
        tput rc && \
        tput setaf 2 && \
        printf "$EXIT_MSG\n"
        tput sgr0 \
        ;} >&3
}