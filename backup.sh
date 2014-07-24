#!/bin/bash

USER=media
HOST=75.65.80.141
PORT=2212
DATE=$(date +%Y%m%d)
BACKUP_FOLDER=/Backups
BACKUP_FILE="$BACKUP_FOLDER/gmillz-chromebook_backup_$Date.tar.gz"
BACKUP_LOCATION=/mnt/Media/Backups
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

echo "sudo tar "$TAR_ARGS""

if sftp -P $PORT $USER@$HOST <<< 'pwd' >/dev/null 2>&1
then 
    SHOULD_UPLOAD=true
fi

if [ "$SHOULD_UPLOAD" = true ]
then
    echo "Uploading..."
    echo "
        cd $BACKUP_LOCATION
        put $BCACKUP_FILE
        exit
    " | sftp -P $PORT $USER@$HOST
fi
