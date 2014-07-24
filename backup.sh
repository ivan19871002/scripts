#!/bin/bash

user="media"
host="75.65.80.141"
port="2212"
date=$(date +%Y%m%d)
backup_folder="/Backups"
pc_name=$(hostname)
backup_file="$backup_folder/"$pc_name"_backup_$date.tar.gz"
backup=$(basename "$backup_file")
server_location="/mnt/Media/Backups"
should_upload=false

backup_exclude=("/proc/*"
"/sys/*"
"/dev/*"
"/tmp/*"
"/Backups/*"
"/home/gmillz/rpmbuild/*" )

tar_args="-cvpf $backup_file /*"

for exclude in "${backup_exclude[@]}"
do
    tar_args="$tar_args --exclude=$exclude"
done

if [ -f "$backup_file" ]
then
    sudo rm "$backup_file"
fi

echo $tar_args
sudo tar $tar_args

if [ ! -f "$backup_file" ]
then
    exit 1
fi

if sftp -P $port $user@$host <<< 'pwd' >/dev/null 2>&1
then 
    should_upload=true
else
    exit 1
fi

if [ "$should_upload" = true ]
then
    echo "Uploading..."
    scp -P "$port" "$backup_file" $user@$host:"$server_location/$backup"
fi

server_md5=$(ssh $user@$host -p $port \"md5sum "$server_location/$backup"\" | awk '{print $1}')
local_md5=$(md5sum "$backup_file" | awk '{print $1}')

if [ "$server_md5" = "$local_md5" ]
then
    sudo rm -f "$backup_file"
    echo "Backup complete."
else
    file=$(basename "$(ssh $user@$host -p $port \"ls "$server_location/$backup"\")")
    if [ "$file" = "$backup" ]
    then
        ssh $user@$host -p $port \"rm -f "$server_location/$backup"\"
    fi
fi
