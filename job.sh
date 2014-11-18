#!/bin/bash

cd "$WORKSPACE"
mkdir -p android
export WORKSPACE="$PWD"

if [ -d scripts ]
then
  rm -rf scripts
fi

git clone git://github.com/gmillz/scripts.git

cd scripts

exec ./build.sh
