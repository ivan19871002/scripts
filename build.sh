#!/bin/bash

function check_result {
    if [ "0" -ne "$?" ]
    then
      (repo forall -c "git reset --hard") > /dev/null
      echo "$1"
      exit 1
    fi
}

if [ -z "$REMOTE" ]
then
    REMOTE=SlimRoms
fi
SOURCE="$HOME/$REMOTE-$BRANCH"
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
if [ -z "$PROTO" ]
then
    PROTO=http
fi
if [ -z "$BUILD_TYPE" ]
then
    BUILD_TYPE=EXPERIMENTAL
fi
export SLIM_BUILD_TYPE="$BUILD_TYPE"
export SLIM_BUILD_EXTRA="$BUILD_NUMBER"

# colorization fix in Jenkins
export CL_RED="\"\033[31m\""
export CL_GRN="\"\033[32m\""
export CL_YLW="\"\033[33m\""
export CL_BLU="\"\033[34m\""
export CL_MAG="\"\033[35m\""
export CL_CYN="\"\033[36m\""
export CL_RST="\"\033[0m\""

START=$(date +"%s")

if [ ! -d "$WORKSPACE" ]
then
    mkdir -p "$WORKSPACE"
fi
cd "$WORKSPACE"
rm -rf archive
mkdir -p archive
cd "$SOURCE"

REPO=$(which repo)
if [ -z "$REPO" ]
then
    mkdir -p "$HOME/bin"
    curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > "$HOME/bin/repo"
    chmod a+x "$HOME/bin/repo"
fi

export PATH=${PATH}:$HOME/bin

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

export BUILD_WITH_COLORS=0

if [ "$REMOTE" = "SlimRoms" ]
then
    repo init -u $PROTO://github.com/$REMOTE/platform_manifest.git -b "$BRANCH"
    check_result "repo init failed."
else
    repo init -u $PROTO://github.com/$REMOTE/android.git -b "$BRANCH"
    check_result "repo init failed."
fi

if [ "$SYNC" = "true" ]
then
    repo sync -d -c > /dev/null
    check_result "repo sync failed"
    echo "repo sync complete."
fi
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

WORKSPACE=$WORKSPACE LUNCH=$LUNCH sh $WORKSPACE/scripts/buildlog.sh 2>&1

# Clean up
if [ "$CLEAN" != "none" ]
then
    make "$CLEAN"
fi

# build it
time make -j"$JOBS" bacon
check_result "Build failed."

MODVERSION=`sed -n -e'/ro\.modversion/s/^.*=//p' $OUT/system/build.prop`
DEVICE=`sed -n -e'/ro\.product\.device/s/^.*=//p' $OUT/system/build.prop`
if [ -z "$DEVICE" ]
then
    echo "DEVICE not found, exiting"
    exit 1
fi

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

END=$(date +%s)
DIFF=$(( $END - $START ))

for f in $(ls "$OUT"/*.zip*)
do
    if [[ $(basename "$f") == *"ota"* ]]
    then
        continue
    fi
    cp "$f" "$WORKSPACE"/archive/$(basename "$f")
done
if [ -f "$OUT/recovery.img" ]
then
    cp "$OUT/recovery.img" "$WORKSPACE/archive"
fi

cp "$OUT/system/build.prop" "$WORKSPACE/archive/build.prop"

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
elif [ "$UPLOADER" = "drive" ]
then
    LINK=$(google-drive_uploader.sh "$OUT/$MODVERSION.zip")
    MD5LINK=$(google-drive_uploader.sh "$OUT/$MODVERSION.zip.md5sum")
fi

MD5=$(cat "$SOURCE/out/target/product/$DEVICE/$MODVERSION.zip.md5sum")
echo "$DEVICE took $DIFF to build"
if [ -z "$UPLOADER" ]
then
    echo "Build: $OUT/$MODVERSION.zip"
else
    echo "Build: $LINK"
fi
echo "MD5: $MD5"
