#!/bin/bash

FILE="$1"
FOLDER="$2"

BROWSER="Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:13.0) Gecko/20100101 Firefox/13.0.1"

if [ ! -f "$FILE" ]
then
  echo "please provide a file in arg"
  exit 1
fi

if [ ! -f "credits.ini" ]
then
  echo "credits file doesn't exist, creating now"
  echo "Enter email:"
  read EMAIL
  echo "EMAIL=$EMAIL" > credits.ini
  echo "Enter password:"
  read PASS
  echo "PASS=$PASS" >> credits.ini
fi

source credits.ini

ACCOUNT_TYPE="GOOGLE" #gooApps = HOSTED , gmail=GOOGLE
MIME_TYPE=`file -b --mime-type $FILE`

curl -v --data-urlencode Email="$EMAIL" --data-urlencode Passwd="$PASS" -d accountType="$ACCOUNT_TYPE" -d service=writely -d source=cURL "https://www.google.com/accounts/ClientLogin" > /tmp/login.txt

TOKEN=`cat /tmp/login.txt | grep Auth | cut -d \= -f 2`

UPLOADLINK=$(curl -Sv -k --request POST -H "Content-Length: 0" -H "Authorization: GoogleLogin auth=${TOKEN}" -H "GData-Version: 3.0" -H "Content-Type: $MIME_TYPE" \
	-H "Slug: $FILE" "https://docs.google.com/feeds/upload/create-session/default/private/full?convert=false" -D /dev/stdout | grep "Location:" | sed s/"Location: "//)

curl -Sv -k --request POST --data-binary "@$FILE" -H "Authorization: GoogleLogin auth=${TOKEN}" -H "GData-Version: 3.0" -H "Content-Type: $MIME_TYPE" -H "Slug: $FILE" "$UPLOADLINK" > /tmp/goolog.upload.txt

L=$(cat /tmp/goolog.upload.txt | cut -d'<' -f4 | cut -d'>' -f2 | cut -d'A' -f2)
LINK="https://docs.google.com/file/d/$L"

rm /tmp/login.txt
rm /tmp/goolog.upload.txt

echo "$LINK"