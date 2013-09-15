#!/bin/bash

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]
then
  ARCH=amd64
else
  ARCH=i386
fi

function debian_install {
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
}

function arch_install {
  if [ "$ARCH" = "amd64" ]
  then
    local ADDITIONAL_PACKAGES=( 'gcc-multilib' 'lib32-zlib' 'lib32-ncurses' 'lib32-readline' )
  fi
  if [ -n "$ADDITIONAL_PACKAGES" ]
  then
    local REQUIRED_PACKAGES=( ${ADDITIONAL_PACKAGES[@]} 'gcc' 'git' 'flex' 'bison' 'gperf' 'sdl' 'wxgtk' 'squashfs-tools' 'curl' 'ncurses' 'zlib' 'schedtool' 'perl-switch' 'zip' 'unzip' 'libxslt' )
  else
    local REQUIRED_PACKAGES=( 'gcc' 'git' 'flex' 'bison' 'gperf' 'sdl' 'wxgtk' 'squashfs-tools' 'curl' 'ncurses' 'zlib' 'schedtool' 'perl-switch' 'zip' 'unzip' 'libxslt' )
  fi

  # Install jdk
  wget https://aur.archlinux.org/packages/jd/jdk6/jdk6.tar.gz
  tar -zxf jdk6.tar.gz
  cd jdk6
  makepkg -i
}


DISTRO=$(cat /etc/issue | cut -d' ' -f1)
if [ "$DISTRO" = "Debian" ]
then
  debian_install
elif [ "$DISTRO" = "Arch" ]
then
  arch_install
fi