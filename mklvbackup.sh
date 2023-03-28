#!/bin/bash

main(){

    # Расположение журнала
    LOG="/var/log/mklvbackup.log"

    # Группа томов
    VGROUP="$1"

    # Каталог для хранения резервных копий
    BACKUPDIR="$2"

    # Получаем список томов в группе
    VOLUMES=$(lvs --noheadings -o lv_name $VGROUP | tr -d '  ')

    # Подготовка
    # Делаем паузу в пять минут
    # -------------------------
    fancy-log notice "\033[01;32mMKLVBACKUP\033[0m started. Waiting 5 minutes before making actual backup."
    notify 'normal' "Backup process started!\nWaiting for <b>5 minutes</b> before starting an actual backup."
    #sleep 300

    # Создание снапшотов томов
    for VOLUME in $VOLUMES
    do
    fancy-log notice "Starting backup process"
    # Проверка на снапшот
    if [ -z $(lvs --noheadings -o origin $VGROUP/$VOLUME) ]
    then
        # Если поле origin пусто (-z), то том не
        # является снапшотом
        SNAPSHOT="$VOLUME-backup-snapshot"
        lvcreate -L 4G -s -n $SNAPSHOT $VGROUP/$VOLUME #>> $LOG
        pv /dev/$VGROUP/$SNAPSHOT | zstd -16 -T4 -q -o "$BACKUPDIR/$VGROUP-$VOLUME-$(date +%d-%m-%Y-%H%M).zst"
        lvremove -y $VGROUP/$SNAPSHOT
    else
        fancy-log warning "Volume $VOLUME is an existing snapshot, skipping"
    fi
    done
}

# Журналирование

fancy-log ()
# Uses $LOG as a log file name, if defined.
# If not defined, tries to use the first argument as
# a log file name.
#
# Status: ok        notice      warning         error
# Colors: green     blue        yellow          red
{
    local self=$(basename $0 | sed -e 's/\..*$//g')
    # Check if $LOG is defined
    if [ -z "$LOG" ]; then
        # $LOG is not defined
        if [ -z "$3" ]; then
            # Not enough arguments AND $LOG is not
            # defined. Looks like an erroneous call.
            printf "fancy-log: Not enough arguments\n"
            exit 1
        else
            # Use the first argument as a log file name,
            # second and third as severity and message
            local log=$1
            local sev=$2
            local message=$3
        fi
    else
        # If $LOG is defined, use it as a log file name
        # and first/second arguments as severity and message
        local log=$LOG
        local sev=$1
        local message=$2
    fi

    # Trying to create a log file
    if [ ! -e $log ]; then
    touch $log
        if [ ! -e $log ]; then
            printf "fancy-log: Unable to create log file.\n"
            exit 1
        fi
    fi

    # Selecting severity
    case "$sev" in
    ok) sev=$(printf "\033[01;32mok\033[0m")
        ;;
    notice) sev=$(printf "\033[01;34mnotice\033[0m")
        ;;
    warning) sev=$(printf "\033[01;33mwarning\033[0m")
         ;;
    error) sev=$(printf "\033[01;31merror\033[0m")
           ;;
    *)  printf "fancy-log: Incorrect status!\n"
        exit 1
        ;;
    esac

    # Building full message
    local writeout="$(date "+%F %T:") $self: $sev: $message"
    # Appending to a log file
    printf "$writeout\n" >> $log
}

# Перегружаем функцию для корректной отсылки уведомлений
# Credit: https://stackoverflow.com/a/49533938/9520367
function notify-send() {
    #Detect the name of the display in use
    local display=":$(ls /tmp/.X11-unix/* | sed 's#/tmp/.X11-unix/X##' | head -n 1)"
    #Detect the user using such display
    local user=$(who | grep '('$display')' | awk '{print $1}' | head -n 1)
    #Detect the id of the user
    local uid=$(id -u $user)
    sudo -u $user DISPLAY=$display DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus notify-send "$@"
}
notify(){
    # Usage: notify <urgency> <message>
    notify-send -u "$1" "MKLVBACKUP" "$2"
}




main "$@"; exit 0
