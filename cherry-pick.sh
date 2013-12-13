#!/bin/bash

function changeExists {
  for change in "${CHANGES[@]}"
  do
    if [ "$change" = "$CHANGE" ]
	then
      return true
      break
    fi
  done
}

if [ -f "$HOME/scripts/cherry-picks" ]
then
  TYPE="$1"
  IFS_OLD="$IFS"
  IFS=$'\n'

  for line in $(cat "$HOME/scripts/cherry-picks")
  do
    if [ "$line" = "" ]
	then
	  continue
	fi

    DIR="$PWD"
    PAC=$(echo "$line" | cut -d'/' -f5 | cut -d' ' -f1)
    PROTO=$(echo "$line" | cut -d':' -f1 | cut -d' ' -f3)
    ORIGIN=$(echo "$line" | cut -d'/' -f3)

    if [[ "$ORIGIN" == *"cyanogenmod"* ]]
	then
      ADDR="$PROTO://$ORIGIN/CyanogenMod/$PAC"
    elif [[ "$ORIGIN" == *"slimroms"* ]]
	then
      ADDR="$PROTO://$ORIGIN/SlimRoms/$PAC"
    elif [[ "$ORIGIN" == *"android"* ]]
	then
      PAC=$(echo "$line" | cut -d'/' -f4,5,6,7,8 | cut -d' ' -f1)
      ADDR="$PROTO://$ORIGIN/$PAC"
    elif [[ "$ORIGIN" == *"github"* ]]
	then
      GITHUB=$(echo "$line" | cut -d'/' -f4)
      ADDR="$PROTO://$ORIGIN/$GITHUB/$PAC.git"
      TYPE="github"
      COMMIT_ID=$(echo "$line" | cut -d'/' -f7)
    fi

    if [[ $(echo "$PAC" | cut -d'_' -f1) == "android" ]]
	then
      PACK=$(echo "$PAC" | cut -d'_' -f2,3,4,5 | cut -d' ' -f1 | tr "_" "/")
    elif [[ $(echo "$PAC" | cut -d'_' -f1) == "platform" ]]
	then
      PACK=$(echo "$PAC" | cut -d' ' -f1 | cut -d'_' -f2 | tr "_" "/")
    elif [[ $(echo "$PAC" | cut -d'_' -f1) == "proprietary" ]]
    then
        PACK=$(echo "$PAC" | cut -f'_' -f2-5 | cut -d' ' -f1 | tr "_" "/")
    elif [ "$PAC" = "platform_manifest" ]
	then
      PACK="$PAC"
    else
      PACK=$(echo "$line" | cut -d'/' -f5 | cut -d' ' -f1 | tr "_" "/")
    fi

    CHANGE=$(echo "$line" | awk '{print $4;}')

    if [[ $(changeExists) == "true" ]]
	then
      continue
    fi

    DEFAULT=$(echo "$line" | awk '{print $2;}')

    cd "$PACK"

    if [ "$TYPE" = "" ]
	then
      if [ "$DEFAULT" = "fetch" ]
	  then
        TYPE=$(echo "$line" | awk '{print $7;}')
      else
        TYPE="$DEFAULT"
      fi
    fi

    if [ "$TYPE" = "cherry-pick" ]
	then
      git fetch "$ADDR" "$CHANGE" && git cherry-pick FETCH_HEAD
    elif [ "$TYPE" = "checkout" ]
	then
      git fetch "$ADDR" "$CHANGE" && git checkout FETCH_HEAD
    elif [ "$TYPE" = "pull" ]
	then
      git pull $ADDR "$CHANGE"
    elif [ "$TYPE" = "github" ]
	then
      git fetch $ADDR && git cherry-pick $COMMIT_ID
    fi

    cd "$DIR"

    CHANGES=("${CHANGES[@]}" "$CHANGE")
  done
  IFS="$IFS_OLD"
fi
