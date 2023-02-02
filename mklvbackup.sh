#!/bin/bash

main(){

    # Расположение журнала
    LOG="/var/log/mkbackup.log"

    # Группа томов
    VGROUP="$1"

    # Каталог для хранения резервных копий
    BACKUPDIR="$2"

    # Получаем список томов в группе
    VOLUMES=$(lvs --noheadings -o lv_name $VGROUP | tr -d '  ')

    # Подготовка
    # Делаем паузу в пять минут
    # -------------------------
    fancy-log notice "MKLVBACKUP started. Waiting 5 minutes before making actual backups."


    # Создание снапшотов томов
    for VOLUME in $VOLUMES
    do
    echo "Working with $VOLUME..."
    # Проверка на снапшот
    if [ -z $(lvs --noheadings -o origin $VGROUP/$VOLUME) ]
    then
        # Если поле origin пусто (-z), то том не
        # является снапшотом
        echo "Volume $VOLUME is not a snapshot"
        SNAPSHOT="$VOLUME-backup-snapshot"
        lvcreate -L 4G -s -n $SNAPSHOT $VGROUP/$VOLUME
        pv /dev/$VGROUP/$SNAPSHOT | zstd -16 -T4 -q -o "$BACKUPDIR/$VGROUP-$VOLUME-$(date +%d-%m-%Y-%H%M).zst"
        lvremove -y $VGROUP/$SNAPSHOT
    else
        echo "Volume $VOLUME is a snapshot, skipping"
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


main "$@"; exit 0
