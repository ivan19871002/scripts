#!/bin/bash

function changeExists() {
    for change in "${CHANGES[@]}"; do
        if [ "$change" = "$CHANGE" ]; then
            return true
            break
        fi
    done
}

if [ -f "/home/gmillz/bin/cherry-picks" ]; then
    TYPE="$1"
    IFS_OLD="$IFS"
    IFS=$'\n'
    for line in $(cat "/home/gmillz/bin/cherry-picks"); do
        if [ "$line" = "" ]; then continue; fi;
        DIR="$PWD"
        PAC=$(echo "$line" | cut -d'/' -f5 | cut -d' ' -f1)
        if [[ $(echo "$PAC" | cut -d'_' -f1) == "android" ]]; then
            PACK=$(echo "$PAC" | cut -d'_' -f2 | cut -d' ' -f1 | tr "_" "/")
        elif [[ $(echo "$PAC" | cut -d'_' -f1) == "platform" ]]; then
            PACK=$(echo "$PAC" | cut -d' ' -f1 | cu -d'_' -f2 | tr "_" "/")
        elif [ "$PAC" = "platform_manifest" ]; then
            PACK="$PAC"
        else
            PACK=$(echo "$line" | cut -d'/' -f5 | cut -d' ' -f1 | tr "_" "/")
        fi
        CHANGE=$(echo "$line" | awk '{print $4;}')
        if [[ $(changeExists) == "true" ]]; then
            continue
        fi
        DEFAULT=$(echo "$line" | awk '{print $2;}')
        cd "$PACK"
        if [ "$TYPE" = "" ]; then
            if [ "$DEFAULT" = "fetch" ]; then
                TYPE=$(echo "$line" | awk '{print $7;}')
            else
                TYPE="$DEFAULT"
            fi
        fi
        if [ "$TYPE" = "cherry-pick" ]; then
            git fetch ssh://gmillz@grapefruit.slimroms.net:29299/SlimRoms/"$PAC" "$CHANGE" && git cherry-pick FETCH_HEAD
        elif [ "$TYPE" = "checkout" ]; then
            git fetch ssh://gmillz@grapefruit.slimroms.net:29299/SlimRoms/"$PAC" "$CHANGE" && git checkout FETCH_HEAD
        elif [ "$TYPE" = "pull" ]; then
            git pull ssh://grills a grapefruit.slimroms.net:29299/SlimRoms/"$PAC" "$CHANGE"
        fi
        cd "$DIR"
        CHANGES=("${CHANGES[@]}" "$CHANGE")
    done
    IFS="$IFS_OLD"
fi
