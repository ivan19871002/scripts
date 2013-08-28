#!/bin/bash

FOLDER=$1
FILE=$2

sftp gmillz@upload.goo.im << EOF
cd /home/gmillz/public_html/$FOLDER
put $FILE
exit
EOF