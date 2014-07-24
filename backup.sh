#!/bin/bash

user="media"
host="75.65.80.141"
port="2212"
date=$(date +%Y%m%d)
backup_folder="/Backups"
backup_file="$backup_folder/gmillz-chromebook_backup_$date.tar.gz"
backup=`basename $backup_file`
server_location="/mnt/Media/Backups"
should_upload=false

backup_exclude=("/proc/*"
"/sys/*"
"/dev/*"
"/tmp/*"
"/Backups/*"
"/home/gmillz/rpmbuild/*" )

tar_args="-cvpf $backup_file '/*'"

for exclude in "${backup_exclude[@]}"
do
    tar_args="$tar_args --exclude=$exclude"
done

sudo tar "$tar_args"

if sftp -P $port $user@$host <<< 'pwd' >/dev/null 2>&1
then 
    should_upload=true
fi

if [ "$should_upload" = true ]
then
    echo "Uploading..."
    echo "
        cd $server_location
        put $backup_file
        exit
    " | sftp -P $port $user@$host
fi

server_md5=`ssh $user@$host -p $port \"md5sum $server_location/$backup\" | awk {print $1}`
local_md5=`md5sum $backup_file | awk {print $1}`

if [ "$server_md5" = "$local_md5" ]
then
    sudo rm -f $backup_file
    echo "Backup complete."
else
    file=`basename $(ssh $user@$host -p $port "ls $server_location/$backup")`
    if [ "$file" = "$backup" ]
    then
        ssh $user@$host -p $port "rm -f $server_location/$backup"
    fi
fi
