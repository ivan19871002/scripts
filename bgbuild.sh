#!/bin/bash

if [ ! -d "/home/gmillz/logs" ]
then
  mkdir -p "/home/gmillz/logs"
fi

SOURCE="/home/gmillz/slim4.3"

if [ -f "/home/gmillz/bin/bgbuild-uploader" ]
then
  UPLOADER=$(cat "/home/gmillz/bin/bgbuild-uploader")
  rm "/home/gmillz/bin/bgbuild-uploader"
fi
if [ -f "/home/gmillz/bin/bgbuild-device" ]
then
  DEVICE=$(cat "/home/gmillz/bin/bgbuild-device")
  rm "/home/gmillz/bin/bgbuild-device"
fi
if [ -f "/home/gmillz/bin/bgbuild-jobs" ]
then
  JOBS=$(cat "/home/gmillz/bin/bgbuild-jobs")
  rm "/home/gmillz/bin/bgbuild-jobs"
fi
if [ -f "/home/gmillz/bin/bgbuild-clean" ]
then
  CLEAN=$(cat "/home/gmillz/bin/bgbuild-clean")
  rm "/home/gmillz/bin/bgbuild-clean"
fi

if [ -z "$DEVICE" ]
then
  DEVICE="flo"
fi
if [ -z "$UPLOADER" ]
then
  UPLOADER="none"
fi
if [ -z "$JOBS" ]
then
  JOBS="4"
fi
if [ -z "$CLEAN" ]
then
  CLEAN=installclean
fi

DATE=$(date +"%Y%m%d-%H:%M")
LOGNAME="log-$DEVICE-$DATE.log"
LOGFILE="/home/gmillz/logs/$LOGNAME"

cd "$SOURCE"

# these lines explained at http://serverfault.com/questions/103501/how-can-i-fully-log-all-bash-scripts-actions
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1> "$LOGFILE" 2>&1
# Everything below will go to the log file

export CCACHE_DIR="/mnt/ccache/ccache"
export CCACHE_HARDLINK="0"
export CCACHE_LOGFILE="$LOGFILE.ccache"
export CCACHE_UMASK="002"
export USE_CCACHE="1"
export CCACHE_BASEDIR="$PWD"

echo "=========================="
echo " OPTIONS: "
echo "--------------------------------------------------------"
echo "uploader: $UPLOADER"
echo "jobs: $JOBS"
echo "device: $DEVICE"
echo "clean: $CLEAN"
echo "=========================="

START=$(date +"%s")

if [[ $(repo status) != "nothing to commit (working directory clean)" ]]
then
  (repo forall -c "git reset --hard") > /dev/null
fi
repo sync

cherry-pick.sh

#init Build
source build/envsetup.sh &> /dev/null

# Lunch menu
if ! lunch slim_"$DEVICE"-userdebug &> "$LOGFILE.lunch"
then
  echo "
    Subject: $DEVICE lunch failed

    Log:
    $(cat "$LOGFILE.lunch")
  " | esmtp griffinn.millender@gmail.com -f buildserver@slimroms.net
  exit 1
fi
rm -f "$LOGFILE.lunch"

# Clean up
if [ "$CLEAN" != "none" ]
then
  make "$CLEAN" &> "$LOGFILE.clean"
fi

#build it
if ! make -j2 bacon > "$LOGFILE.build" 2>&1
then
  echo "
    Subject: $DEVICE failed

    Log:
    $(tail -30 $LOGFILE.build)
  " | esmtp griffinn.millender@gmail.com -f buildserver@slimroms.net
  exit 1
fi
rm -f "$LOGFILE.clean"

MODVERSION=`sed -n -e'/ro\.modversion/s/^.*=//p' out/target/product/$DEVICE/system/build.prop`
END=$(date +%s)
DIFF=$(( $END - $START ))

# upload to goo.im
if [ "$UPLOADER" = "goo" ]
then
  upload-goo "$DEVICE" "$SOURCE/out/target/product/$DEVICE/$MODVERSION.zip"
  upload-goo "$DEVICE" "$SOURCE/out/target/product/$DEVICE/$MODVERSION.zip.md5"
  LINK="http://goo.im/devs/gmillz/$DEVICE/$MODVERSION.zip"
  MD5LINK="http://goo.im/devs/gmillz/$DEVICE/$MODVERSION.zip.md5"
# upload to dropbox
elif [ "$UPLOADER" = "dropbox" ]
then
  dropbox_uploader.sh upload "$SOURCE/out/target/product/$DEVICE/$MODVERSION.zip" "slim/$DEVICE/$MODVERSION.zip"
  dropbox_uploader.sh upload "$SOURCE/out/target/product/$DEVICE/$MODVERSION.zip.md5sum" "slim/$DEVICE/$MODVERSION.zip.md5sum"
  LINK=$(dropbox_uploader.sh share "slim/$DEVICE/$MODVERSION.zip")
  MD5LINK=$(dropbox_uploader.sh share "slim/$DEVICE/$MODVERSION.zip.md5sum")
fi

MD5=$(cat "$SOURCE/out/target/product/$DEVICE/$MODVERSION.zip.md5sum")
echo "$DEVICE took $DIFF to build"
echo "Build: $LINK"
echo "MD5: $MD5"

# sending result email
if [ "$UPLOADER" = "none" ]
then
  echo "
    Subject: $DEVICE build finished, lasted $DIFF seconds

    Not uploaded.

  " | esmtp griffinn.millender@gmail.com -f buildserver@slimroms.net
else
  echo "
    Subject: $DEVICE build finished, lasted $DIFF seconds

    Link to build: $LINK
    MD5: $MD5LINK

  " | esmtp griffinn.millender@gmail.com -f buildserver@slimroms.net
fi
