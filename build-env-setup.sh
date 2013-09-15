#!/bin/bash

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]
then
  ARCH=amd64
else
  ARCH=i386
fi

REQUIRED_PACKAGES=( "git" "gnupg" "flex" "bison" "gperf" "build-essential" "zip" "curl" \
	"libc6-dev" "libncurses5:$ARCH" "libncurses5-dev" "x11proto-core-dev" "libx11-dev:$ARCH" \
	"libreadline6-dev:$ARCH" "libgl1-mesa-glx:$ARCH" "libgl1-mesa-dev" "g++-multilib" \
	"mingw32" "tofrodos" "python-markdown" "libxml2-utils" "xsltproc" "zlib1g-dev:$ARCH" )

INSTALLED_PACKAGES=$(dpkg --get-selections)

for package in "${REQUIRED_PACKAGES[@]}"
do
  if [[ "$INSTALLED_PACKAGES" != *"$package"* ]]
  then
    echo "$package doesn't exist"
    MISSING_PACKAGES="$MISSING_PACKAGES $package"
  fi
done

# install java and all missing packages
#if su
#  then
#  apt-get purge openjdk*
#  add-apt-repository ppa:webupd8team/java
#  apt-get update
#  apt-get install oracle-java6-installer
#  apt-get install "$MISSING_PACKAGES"
#fi