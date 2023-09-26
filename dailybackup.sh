#!/bin/bash
export PROG=/usr/bin/rsync
export BACKUPARGS="-a -r -v -h "
export HOST=`/usr/bin/hostname -s 2>/dev/null`
export SOURCE="/home/"
export DESTDIR=/mnt/chem1/$HOST
export OUTPUT=/root/dailybackup.out
export ERRORS=/root/dailybackup.err
eval $PROG $BACKUPARGS $SOURCE root@newnas:$DESTDIR >$OUTPUT 2>$ERRORS
if [ ! $? ]; then
    mail -s "Backup on $HOST had problems" cparish@richmond.edu <$ERRORS
fi
