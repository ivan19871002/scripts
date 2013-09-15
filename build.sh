#!/bin/bash

function check_result {
  if [ "0" -ne "$?" ]
  then
    #(repo forall -c "git reset --hard") > /dev/null
    rm -f .repo/local_manifests/*.xml
    echo "$1"
    exit 1
  fi
}

~/bin/remove-old-logs.sh

if [ -f "/home/gmillz/bin/bgbuild-config" ]
then
  source ~/bin/bgbuild-config
fi

SOURCE="/home/gmillz/$BRANCH"
if [ ! -d "$SOURCE" ]
then
  mkdir -p "$SOURCE"
  FIRST=true
fi
cd "$SOURCE"

if [ ! -d "/home/gmillz/logs" ]
then
  mkdir -p "/home/gmillz/logs"
fi

if [ -z "$UPLOADER" ]
then
  echo "UPLOAD not specified, not uploading."
fi
if [ -z "$JOBS" ]
then
  JOBS="4"
fi
if [ -z "$DEVICE" ]
then
  echo "DEVICE not specified, exiting."
  exit 1
else
  LUNCH="slim_$DEVICE-userdebug"
fi
if [ -z "$BRANCH" ]
then
  echo "BRANCH not specified, exiting."
  exit 1
fi
if [ -z "$CLEAN" ]
then
  CLEAN="none"
fi
if [ -z "$SYNC" ]
then
  SYNC=true
fi
if [ -z "$CHERRY_PICK" ]
then
  CHERRY_PICK=true
fi
if [ -z "$LOGGING" ]
then
  LOGGING=true
fi
if [ -z "$SEND_EMAIL" ]
then
  SEND_EMAIL=false
fi
if [ -z "$EMAIL" ]
then
  echo "EMAIL not set, disabling SEND_EMAIL"
  SEND_EMAIL=false
fi
if [ -z "$BUILDSERVER_EMAIL" ]
then
  echo "BUILDSERVER_EMAIL not set, disabling SEND_EMAIL"
  SEND_EMAIL=false
fi
if [ -z "$WORKSPACE" ]
then
  echo "WORKSPACE not set, exiting."
  exit 1
fi

if [ "$LOGGING" = "true" ]
then
  # these lines explained at http://serverfault.com/questions/103501/how-can-i-fully-log-all-bash-scripts-actions
  exec 3>&1 4>&2
  trap 'exec 2>&4 1>&3' 0 1 2 3
  exec 1> "$LOGFILE" 2>&1
  # Everything below will go to the log file
fi

START=$(date +"%s")

if [ ! -d "$WORKSPACE" ]
then
  mkdir -p "$WORKSPACE"
fi
cd "$WORKSPACE"
rm -rf archive
mkdir -p archive
cd "$SOURCE"

if [ "$FIRST" != "true" ]
then
  rm -rf .repo/manifests*
  mkdir -p "$WORKSPACE"/manifests
  for manifest in $(ls .repo/local_manifests)
  do
    if [ "$manifest" != "slim_manifest.xml" ]
    then
      cp -f .repo/local_manifests/"$manifest" "$WORKSPACE"/manifests/$manifest
      rm -f .repo/local_manifests/"$manifest"
    fi
  done
fi
repo init -u git://github.com/SlimRoms/platform_manifest.git -b "$BRANCH"
check_result "repo init failed."

if [ "$FIRST" = "true" ]
then
  repo sync
else
  TEMPSTASH=$(mktemp -d)
  mv .repo/local_manifests/* "$TEMPSTASH"
  mv "$TEMPSTASH"/slim_manifest.xml .repo/local_manifests/
  repo manifest -o "$WORKSPACE"/archive/manifest.xml -r
  mv "$TEMPSTASH"/* .repo/local_manifests/ 2> /dev/null
  rmdir "$TEMPSTASH"

  for manifest in $(ls "$WORKSPACE/manifests")
  do
    cp -f "$WORKSPACE/manifests/$manifest" ".repo/local_manifests/$manifest"
  done
fi

if [ "$SYNC" = "true" ]
then
  repo sync
fi
if [ "$CHERRY_PICK" = "true" || -f "~/bin/cherry-pick.sh" ]
then
  cherry-pick.sh
fi

rm -f "$WORKSPACE"/changecount
WORKSPACE="$WORKSPACE" LUNCH="$LUNCH" bash ~/bin/buildlog.sh 2>&1
if [ -f "$WORKSPACE/changecount" ]
then
  CHANGE_COUNT=$(cat "$WORKSPACE/changecount")
  rm -f "$WORKSPACE/changecount"
  if [ "$CHANGE_COUNT" -eq "0" ]
  then
    echo "Zero changes since last build, aborting."
  fi
fi

#init Build
source build/envsetup.sh &> /dev/null

# Lunch
if ! lunch "$LUNCH" &> "$LOGFILE.lunch"
then
  if [ "$SEND_EMAIL" = "true" ]
  then
    echo "
      Subject: $DEVICE lunch failed

      Log:
      $(cat "$LOGFILE.lunch")
    " | esmtp "$EMAIL" -f "$BUILDSERVER_EMAIL"
    exit 1
  fi
fi
rm -f "$LOGFILE.lunch"

# Clean up
if [ "$CLEAN" != "none" ]
then
  LAST_CLEAN=0
  if [ -f .clean ]
  then
    LAST_SYNC=$(date -r .clean +%s)
  fi
  TIME_SINCE_LAST_CLEAN=$(expr $(date +%s) - "$LAST_CLEAN")
  TIME_SINCE_LAST_CLEAN=$(expr "$TIME_SINCE_LAST_CLEAN" / 60 / 60)
  if [ "$TIME_SINCE_LAST_CLEAN" -gt "20" ]
  then
    touch .clean
	if [ "$LOGGING" = "true" ]
	then
      make "$CLEAN" &> "$LOGFILE.clean"
	else
	  make "$CLEAN"
	fi
  elif [ "$FORCE_CLEAN" = "true"
    touch .clean
	if [ "$LOGGING" = "true" ]
	then
      make "$CLEAN" &> "$LOGFILE.clean"
	else
	  make "$CLEAN"
	fi
  else
    echo "Skipping clean: $TIME_SINCE_LAST_CLEAN hours since last clean."
  fi
fi

# build it
if ! make -j2 bacon > "$LOGFILE.build" 2>&1
then
  if [ "$SEND_EMAIL" = "true" ]
  then
    echo "
      Subject: $DEVICE failed

      Log:
      $(tail -30 $LOGFILE.build)
    " | esmtp "$EMAIL" -f "$BUILDSERVER_EMAIL"
  fi
  exit 1
fi
if [ "$LOGGING" != "true" ]
then
  rm -f "$LOGFILE.build"
fi

MODVERSION=`sed -n -e'/ro\.modversion/s/^.*=//p' out/target/product/$DEVICE/system/build.prop`
END=$(date +%s)
DIFF=$(( $END - $START ))

for f in $(ls out/target/product/$DEVICE/Slim-*.zip*)
do
  cp "$f" "$WORKSPACE"/archive/$(basename "$f")
done
if [ -f out/target/product/$DEVICE/utilities/update.zip ]
then
  cp out/target/product/$DEVICE/utilities/update.zip "$WORKSPACE"/archive/recovery.zip
fi
if [ -f out/target/product/$DEVICE/recovery.img ]
then
  cp out/target/product/$DEVICE/recovery.img "$WORKSPACE"/archive
fi

ZIP=$(ls "$WORKSPACE"/archive/Slim-*.zip)
unzip -p $ZIP system/build.prop > "$WORKSPACE"/archive/build.prop

# upload to goo.im
if [ "$UPLOADER" = "goo" ]
then
  upload-goo "$DEVICE" "$SOURCE/out/target/product/$DEVICE/$MODVERSION.zip"
  upload-goo "$DEVICE" "$SOURCE/out/target/product/$DEVICE/$MODVERSION.zip.md5sum"
  LINK="http://goo.im/devs/gmillz/$DEVICE/$MODVERSION.zip"
  MD5LINK="http://goo.im/devs/gmillz/$DEVICE/$MODVERSION.zip.md5sum"
# upload to dropbox
elif [ "$UPLOADER" = "dropbox" ]
then
  dropbox_uploader.sh upload "$SOURCE/out/target/product/$DEVICE/$MODVERSION.zip" "slim/$DEVICE/$MODVERSION.zip"
  dropbox_uploader.sh upload "$SOURCE/out/target/product/$DEVICE/$MODVERSION.zip.md5sum" "slim/$DEVICE/$MODVERSION.zip.md5sum"
  LINK=$(dropbox_uploader.sh share "slim/$DEVICE/$MODVERSION.zip")
  MD5LINK=$(dropbox_uploader.sh share "slim/$DEVICE/$MODVERSION.zip.md5sum")
elif [ "$UPLOADER" = "flo-nightly" ]
then
  # Server details
  HOST="192.241.138.156"
  USER="root"
  # upload to server
  echo "
    cd /var/www/html/downloads/flo
    put "$FILE"
    exit
  " | sftp $USER@$HOST
  # clean server so only 5 files get kept
  echo "
    cd /var/www/html/downloads/flo
    (ls -t|head -n 5;ls)|sort|uniq -u|xargs rm
    exit
  " | ssh $USER@$HOST &>> $LOGFILE
fi

MD5=$(cat "$SOURCE/out/target/product/$DEVICE/$MODVERSION.zip.md5sum")
echo "$DEVICE took $DIFF to build"
echo "Build: $LINK"
echo "MD5: $MD5"

# sending result email
if [ "$SEND_EMAIL" = "true" ]
then
  if [ "$UPLOADER" = "none" ]
  then
    echo "
      Subject: $DEVICE build finished, lasted $DIFF seconds

      Not uploaded.

    " | esmtp "$EMAIL" -f "$BUILDSERVER_EMAIL"
  else
    echo "
      Subject: $DEVICE build finished, lasted $DIFF seconds

      Link to build: $LINK
      MD5: $MD5LINK

    " | esmtp "$EMAIL" -f "$BUILDSERVER_EMAIL"
  fi
fi

mkdir -p "/home/gmillz/completed-builds/$MODVERSION"

for f in $(ls $WORKSPACE/archive)
do
  cp $WORKSPACE/archive/$f /home/gmillz/completed-builds/$MODVERSION/$f
done

if [ "$UPLOADER" != "none" ]
then
  sed -i "s/UPLOADER=$UPLOADER/UPLOADER=none/g" ~/bin/bgbuild-config
fi
