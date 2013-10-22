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

#chmod a+x "$WORKSPACE"/remove-old-logs.sh
#. "$WORKSPACE"/remove-old-logs.sh

if [ -f $HOME/scripts/build-config ]
then
  echo CONFIG found
  source $HOME/scripts/build-config
else
  echo CONFIG not found exiting
  exit 1
fi

SOURCE="$HOME/$BRANCH"
if [ ! -d "$SOURCE" ]
then
  mkdir -p "$SOURCE"
  FIRST=true
fi
cd "$SOURCE"

if [ ! -d $HOME/logs ]
then
  mkdir -p $HOME/logs
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
if [ -z "$WORKSPACE" ]
then
  echo "WORKSPACE not set, exiting."
  exit 1
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

curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > "$HOME/bin/repo"
chmod a+x "$HOME/bin/repo"
export PATH=${PATH}:$HOME/bin

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
if [ "$CHERRY_PICK" = "true" ]
then
  chmod a+x $WORKSPACE/cherry-pick.sh
  . $WORKSPACE/cherry-pick.sh
fi

#rm -f "$WORKSPACE"/changecount
#WORKSPACE="$WORKSPACE" LUNCH="$LUNCH" bash $HOME/scripts/buildlog.sh 2>&1
#if [ -f "$WORKSPACE/changecount" ]
#then
#  CHANGE_COUNT=$(cat "$WORKSPACE/changecount")
#  rm -f "$WORKSPACE/changecount"
#  if [ "$CHANGE_COUNT" -eq "0" ]
#  then
#    echo "Zero changes since last build, aborting."
#  fi
#fi

#init Build
source build/envsetup.sh &> /dev/null

# Lunch
lunch "$LUNCH"

# Clean up
if [ "$CLEAN" != "none" ]
then
    make "$CLEAN"
fi

# build it
make -j2 bacon

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
elif [ "$UPLOADER" = "drive" ]
then
  LINK=$(google-drive_uploader.sh "$SOURCE/out/target/product/$DEVICE/$MODVERSION.zip")
  MD5LINK=$(google-drive_uploader.sh "$SOURCE/out/target/product/$DEVICE/$MODVERSION.zip.md5sum")
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

mkdir -p "/home/gmillz/completed-builds/$MODVERSION"

for f in $(ls $WORKSPACE/archive)
do
  cp $WORKSPACE/archive/$f /home/gmillz/completed-builds/$MODVERSION/$f
done

if [ "$UPLOADER" != "none" ]
then
  sed -i "s/UPLOADER=$UPLOADER/UPLOADER=none/g" $HOME/scripts/build-config
fi
