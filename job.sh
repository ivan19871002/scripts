#!/bin/bash

cd "$WORKSPACE"
mkdir -p android
export WORKSPACE="$PWD"

if [ ! -d scripts ]
then
  git clone git://github.com/gmillz/scripts.git
fi

cd scripts
git reset --hard
git pull -s resolve

exec ./build.sh
