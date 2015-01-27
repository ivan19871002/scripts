#!/bin/bash

# function to check result of command
function check_result {
    if [ "0" -ne "$?" ]
    then
      (repo forall -c "git reset --hard") > /dev/null
      echo "$1"
      exit 1
    fi
}

# check all variables
if [ -z "$WORKSPACE" ]
then
    echo "WORKSPACE not set, exiting."
    exit 1
fi
if [ -z "$REMOTE" ]
then
    REMOTE=SlimRoms
fi
SOURCE="$WORKSPACE/$REMOTE-$BRANCH"
if [ ! -d "$SOURCE" ]
then
    mkdir -p "$SOURCE"
fi
cd "$SOURCE"

if [ -z "$LUNCH" ]
then
    echo "LUNCH not specified, exiting"
    exit 1
fi
if [ -z "$BRANCH" ]
then
    echo "BRANCH not specified, exiting."
    exit 1
fi
if [ -z "$JOBS" ]
then
    JOBS="4"
fi
if [ -z "$UPLOADER" ]
then
    echo "UPLOAD not specified, not uploading."
fi
if [ -z "$CLEAN" ]
then
    CLEAN="false"
fi
if [ -z "$SYNC" ]
then
    SYNC=true
fi
if [ -z "$CHERRY_PICK" ]
then
    CHERRY_PICK=true
fi
if [ -z "$PROTO" ]
then
    PROTO=http
fi
if [ -z "$BUILD_TYPE" ]
then
    BUILD_TYPE=EXPERIMENTAL
fi

# exports for slim
export SLIM_BUILD_TYPE="$BUILD_TYPE"

if [ -z "$DATE_IN_BUILD" ]
then
    export SLIM_BUILD_EXTRA="$BUILD_NUMBER"
else
    export SLIM_BUILD_EXTRA=$(date +"%Y%m%d")
fi

# colorization fix in Jenkins
export CL_RED="\"\033[31m\""
export CL_GRN="\"\033[32m\""
export CL_YLW="\"\033[33m\""
export CL_BLU="\"\033[34m\""
export CL_MAG="\"\033[35m\""
export CL_CYN="\"\033[36m\""
export CL_RST="\"\033[0m\""

# start time
START=$(date +"%s")

# setup work space
cd "$WORKSPACE"
rm -rf archive
mkdir -p archive
cd "$SOURCE"

# download repo if needed
REPO=$(which repo)
if [ -z "$REPO" ]
then
    mkdir -p "$HOME/bin"
    curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > "$HOME/bin/repo"
    chmod a+x "$HOME/bin/repo"
fi

# include bin in path
export PATH=${PATH}:$HOME/bin

# disable colors so build uses jenkins color fix
export BUILD_WITH_COLORS=0

#CCACHE
export CCACHE_DIR=/mnt/ccache-jenkins/ccache
if [ -d "$CCACHE_DIR" ]
then
    export USE_CCACHE=1
    export CCACHE_NLEVELS=4
    if [ ! "$(ccache -s | grep -E 'max cache size' | awk '{print $4}')" = "100.0" ]
    then
        ccache -M 100G
    fi
fi

# initizize build environment
if [ "$REMOTE" = "SlimRoms" ]
then
    repo init -u $PROTO://github.com/$REMOTE/platform_manifest.git -b "$BRANCH"
    check_result "repo init failed."
else
    repo init -u $PROTO://github.com/$REMOTE/android.git -b "$BRANCH"
    check_result "repo init failed."
fi

VENDOR_MANIFEST="$BRANCH"-vendor_manifest.xml
if [ -f "$WORKSPACE/$VENDOR_MANIFEST" ]
then
    if [ ! -d ".repo/local_manifests" ]
    then
        mkdir -p ".repo/local_manifests"
    fi
    cp "$WORKSPACE/$VENDOR_MANIFEST" ".repo/local_manifests/$VENDOR_MANIFEST"
fi

# repo sync
if [ "$SYNC" = "true" ]
then
    repo sync -d -c > /dev/null
    check_result "repo sync failed"
    echo "repo sync complete."
fi

# cherry pick
if [ "$CHERRY_PICK" = "true" ]
then
    chmod a+x $WORKSPACE/cherry-pick.sh
    . $WORKSPACE/cherry-pick.sh
fi

#init Build
source build/envsetup.sh &> /dev/null

# Lunch
lunch "$LUNCH"
check_result "lunch failed"

# build log, doesn't really work
#WORKSPACE=$WORKSPACE LUNCH=$LUNCH sh $WORKSPACE/scripts/buildlog.sh 2>&1

# Clean up
LAST_CLEAN=0
if [ -f .clean ]
then
    LAST_CLEAN=$(date -r .clean +%s)
fi
TIME_SINCE_LAST_CLEAN=$(expr $(date +%s) - $LAST_CLEAN)
TIME_SINCE_LAST_CLEAN=$(expr $TIME_SINCE_LAST_CLEAN / 60 / 60)
if [ $TIME_SINCE_LAST_CLEAN -gt "24" -o $CLEAN != "none" ]
then
    echo "Cleaning!"
    touch .clean
    make $CLEAN
else
    echo "Skipping clean: $TIME_SINCE_LAST_CLEAN hours since last clean."
fi

# build it
time make -j"$JOBS" bacon
check_result "Build failed."

# remove common folder since its not really common
rm -rf out/target/common

# variables
MODVERSION=`sed -n -e'/ro\.modversion/s/^.*=//p' $OUT/system/build.prop`
DEVICE=`sed -n -e'/ro\.product\.device/s/^.*=//p' $OUT/system/build.prop`
if [ -z "$DEVICE" ]
then
    echo "DEVICE not found, exiting"
    exit 1
fi

# save manifest
if [ -d ".repo/local_manifests" ]
then
    TEMPSTASH=$(mktemp -d)
    mv .repo/local_manifests/* "$TEMPSTASH"
    if [ -f "$TEMPSTASH/slim_manifest.xml" ]
    then
        mv "$TEMPSTASH"/slim_manifest.xml .repo/local_manifests/
    fi
    repo manifest -o "$WORKSPACE"/archive/manifest.xml -r
    mv "$TEMPSTASH"/* .repo/local_manifests/ 2> /dev/null
    rmdir "$TEMPSTASH"
fi

# end date and diff time
END=$(date +%s)
DIFF=$(( $END - $START ))

# archive recovery
if [ -f "$OUT/recovery.img" ]
then
    cp "$OUT/recovery.img" "$WORKSPACE/archive"
fi

# archive build.prop
cp "$OUT/system/build.prop" "$WORKSPACE/archive/build.prop"

# UPLOAD
if [ "$BUILD_TYPE" = "NIGHTLY" ]
then
    echo "
        cd /home/FTP-shared/gmillz/$DEVICE/$BUILD_TYPE
        put $OUT/$MODVERSION.zip
        exit
   " | sftp gmillz@teamhacklg.tk
   LINK="ftp://teamhacklg.tk/gmillz/$DEVICE/$BUILD_TYPE/$MODVERSION.zip"
else
    # upload to goo.im
    if [ "$UPLOADER" = "goo.im" ]
    then
        chmod a+x $WORKSPACE/scripts/upload-goo.sh
        $WORKSPACE/scripts/upload-goo.sh "mkdir" "$DEVICE/$BUILD_TYPE"
        $WORKSPACE/scripts/upload-goo.sh "upload" "$OUT/$MODVERSION.zip" "$DEVICE/$BUILD_TYPE"
        $WORKSPACE/scripts/upload-goo.sh "upload" "$OUT/$MODVERSION.zip.md5sum" "$DEVICE/$BUILD_TYPE"
        LINK="http://goo.im/devs/gmillz/$DEVICE/$BUILD_TYPE/$MODVERSION.zip"
        MD5LINK="http://goo.im/devs/gmillz/$DEVICE/$BUILD_TYPE/$MODVERSION.zip.md5sum"
    # upload to dropbox
    elif [ "$UPLOADER" = "dropbox" ]
    then
        $WORKSPACE/scripts/dropbox_uploader.sh upload "$OUT/$MODVERSION.zip" "$REMOTE/$DEVICE/$MODVERSION.zip"
        $WORKSPACE/scripts/dropbox_uploader.sh upload "$OUT/$MODVERSION.zip.md5sum" "$REMOTE/$DEVICE/$MODVERSION.zip.md5sum"
        LINK=$($WORKSPACE/scripts/dropbox_uploader.sh share "$REMOTE/$DEVICE/$MODVERSION.zip")
        MD5LINK=$($WORKSPACE/scripts/dropbox_uploader.sh share "$REMOTE/$DEVICE/$MODVERSION.zip.md5sum")
    # upload to drive
    elif [ "$UPLOADER" = "drive" ]
    then
        LINK=$(google-drive_uploader.sh "$OUT/$MODVERSION.zip")
        MD5LINK=$(google-drive_uploader.sh "$OUT/$MODVERSION.zip.md5sum")
    fi
fi

# the md5 of the build
MD5=$(cat "$SOURCE/out/target/product/$DEVICE/$MODVERSION.zip.md5sum")

# echo the amount of time the build took
echo "$DEVICE took $DIFF seconds to build"
# echo the link if uploaded else echo the path
if [ -z "$UPLOADER" ]
then
    echo "Build: $OUT/$MODVERSION.zip"
else
    echo "Build: $LINK"
fi

# echo MD5
echo "MD5: $MD5"
