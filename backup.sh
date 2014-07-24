#!/bin/bash

USER=media
HOST=75.65.80.141
PORT=2212
DATE=$(date +%Y%m%d)
BACKUP_FOLDER=/Backups
BACKUP_FILE="$BACKUP_FOLDER/gmillz-chromebook_backup_$Date.tar.gz"
BACKUP=`basename $BACKUP_FILE`
SERVER_LOCATION=/mnt/Media/Backups
SHOULD_UPLOAD=false

BACKUP_EXCLUDE=("/proc/*"
"/sys/*"
"/dev/*"
"/tmp/*"
"/Backups/*"
"/home/gmillz/rpmbuild/*" )

TAR_ARGS="-cvpf $BACKUP_FILE '/*'"

for exclude in "${BACKUP_EXCLUDE[@]}"
do
    TAR_ARGS="$TAR_ARGS --exclude=$exclude"
done

sudo tar "$TAR_ARGS"

if sftp -P $PORT $USER@$HOST <<< 'pwd' >/dev/null 2>&1
then 
    SHOULD_UPLOAD=true
fi

if [ "$SHOULD_UPLOAD" = true ]
then
    echo "Uploading..."
    echo "
        cd $SERVER_LOCATION
        put $BACKUP_FILE
        exit
    " | sftp -P $PORT $USER@$HOST
fi

SERVER_MD5=`ssh $USER@$HOST -p $PORT \"md5sum $SERVER_LOCATION/$BACKUP\" | awk {print $1}`
LOCAL_MD5=`md5sum $BACKUP_FILE | awk {print $1}`

if [ "$SERVER_MD5" = "$LOCAL_MD5" ]
then
    sudo rm -f $BACKUP_FILE
    echo "Backup complete."
else
    FILE=`basename $(ssh $USER@$HOST -p $PORT "ls $TEST")`
    if [ "$FILE" = "$BACKUP" ]
    then
        sudo rm -f $BACKUP_FILE
        ssh $USER@$HOST -p $PORT "rm -f $SERVER_LOCATION/$BACKUP"
    fi
fi
