#!/bin/bash

COMMAND=$1
ARG1=$2
ARG2=$3

function goo-upload {
  FILE="$1"
  FOLDER="$2"
  echo "
    cd /home/gmillz/public_html/$FOLDER
    put $FILE
    exit
  " | sftp gmillz@upload.goo.im
}

function goo-download {
  SRC="$1"
  DST="$2"

  if [[ "$SRC" != *"public_html"* ]]
  then
    SRC="/home/gmillz/public_html/$SRC"
  fi

  echo "
    get $SRC $DST
	exit
  " | sftp gmillz@upload.goo.im
}

function goo-delete {
  FILE="$1"

  if [[ "$FILE" != *"public_html"* ]]
  then
    FILE="/home/gmillz/public_html/$FILE"
  fi

  echo "
    rm $FILE
	exit
  " | sftp gmillz@upload.goo.im
}

function goo-move {
  SRC="$1"
  DST="$2"

  if [[ "$SRC" != *"public_html"* ]]
  then
    SRC="/home/gmillz/public_html/$SRC"
  fi
  if [[ "$DST" != *"public_html"* ]]
  then
    DST="/home/gmillz/public_html/$DST"
  fi

  echo "
    rename $SRC $DST
	exit
  " | sftp gmillz@upload.goo.im
}

function goo-mkdir {
  DIR="$1"

  if [[ "$DIR" != *"public_html"* ]]
  then
    DIR="/home/gmillz/public_html/$DIR"
  fi

  echo "
    mkdir $DIR
	exit
  " | sftp gmillz@upload.goo.im
}

function goo-list {
  DIR="$1"
  for line in $(echo "
    ls $DIR
	exit
  " | sftp gmillz@upload.goo.im)
  do
    if [[ "$line" == *"sftp>"* ]]
    then
      continue
    elif [[ "$line" == *"ls"* ]]
    then
         echo -e '\n'
	  continue
    elif [[ "$line" == *"exit"* ]]
    then
        continue
    else
      echo "$line"
    fi
    
  done
}

function goo-link {
  FILE="$1"
  LINK="http://goo.im/devs/gmillz/$FILE"
  echo "$LINK"
}

function goo-help {
  echo "Goo upload script!"
  echo "Usage: upload-goo.sh COMMAND [PARAMETERS]"
  echo -e '\nCommands:'
  echo "upload [LOCAL_FILE/DIR] <REMOTE_FILE/DIR>"
  echo "download [REMOTE_FILE/DIR] <LOCAL_FILE/DIR>"
  echo "delete [REMOTE_FILE/DIR]"
  echo "move [REMOTE_FILE/DIR] [REMOTE_FILE/DIR]"
  echo "mkdir [REMOTE_DIR]"
  echo "list <REMOTE_DIR>"
  echo "link [REMOTE_FILE]"
  echo "help, displays this dialog"
}

case "$COMMAND" in
  upload) goo-upload "$ARG1" "$ARG2";;
  download) goo-download "$ARG1" "$ARG2";;
  delete) goo-delete "$ARG1";;
  move) goo-move "$ARG1" "$ARG2";;
  mkdir) goo-mkdir "$ARG1";;
  list) goo-list "$ARG1";;
  link) echo $(goo-link "$ARG1");;
  clean) goo-clean;;
  help) goo-help;;
  *) goo-help;;
esac