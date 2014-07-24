#!/bin/bash
# Modified for Arch Linux from ChrUbuntu's cros-haswell-modules.sh
# https://googledrive.com/host/0B0YvUuHHn3MndlNDbXhPRlB2eFE/cros-haswell-modules.sh
# + touchpad:
# original cros-haswell-modules.sh by Jay Lee http://goo.gl/kz917j 
# updated to support c720p touchscreen by motley.slate@gmail.com
# updated to support als system - Yannick@ekiga
# This script is designed for Fedora 20
# Changelog:
# Version 12 (Jason Knight <jason@jasonknight.us>)
# - Fixes ZRAM in 3.15
# - Builds optional, faster lz4 compression backend too
# Version 11 (ty masmullin)
# - a fix for backlight issue in kernel 3.15 seems to be already applied in the fedora kernel (good!!)
# - change kernel patches from Benson Leung's...
# - add a fix for i2c driver issue with kernel 3.15
# - a little cleanup for readability
# Version 10.1
# - removed zmalloc compilation as it seems useless now.
# Version 10
# - Remove the fix for suspend; kernel 3.14.6 has the fix.
# Version 9
# - fix suspend for 3.14.2 by reverting patch https://github.com/torvalds/linux/commit/1569a4c4ceba
# Version 8
# - updated for linux 3.14.x
# - Updated zram folder as it is now outside staging
# Version 7.1
# Apply since kernel 3.13.3-201.fc20.x86_64
# - Fix the atmel touchscreen module for kernel 3.13.x

set -e

# Determine kernel version
# e.g. 3.12.5-302.fc20.x86_64
archkernver=$(uname -r)
# e.g. 3.12.5
kernver=$(uname -r | cut -d'-' -f 1)
# e.g. 302.fc20
fnumversion=$(uname -r | cut -d'-' -f 2 | cut -d'.' -f 1,2)
# e.g. x86_64
arch=$(uname -r | cut -d'-' -f 2 | cut -d'.' -f 3)
# e.g. 3.12
kernvermaj=$(uname -r | cut -d'-' -f 1 | cut -d'.' -f 1,2)
# e.g. fc20
fversion=$(uname -r | cut -d'-' -f 2 | cut -d'.' -f 2)
# e.g. 302.fc20.x86_64
extraversion=$(uname -r | cut -d'-' -f 2)

# Install necessary deps to build a kernel
echo "Installing linux-headers..."
su -c 'yum install rpmdevtools yum-utils kernel-devel kernel-headers ncurses-devel pesign'

# Grab kernel source
rpmdev-setuptree
yumdownloader --source kernel
su -c "yum-builddep kernel-$kernver-$fnumversion.src.rpm"
rpm -Uvh kernel-$kernver-$fnumversion.src.rpm
cd $HOME/rpmbuild/SPECS
rpmbuild -bp --target=$(uname -m) kernel.spec

cd $HOME/rpmbuild/BUILD/kernel-$kernvermaj.$fversion/linux-$archkernver

# Use Benson Leung's post-Pixel Chromebook patches:
# https://patchwork.kernel.org/bundle/bleung/chromeos-laptop-deferring-and-haswell/
#echo "Applying Chromebook Haswell Patches..."
#for patch in 3078491 3078481; do
#  wget -O - https://patchwork.kernel.org/patch/$patch/raw/ | patch -p1
#done

for patch in 3074401 3074431 3074411; do
  wget -O - https://patchwork.kernel.org/patch/$patch/raw/ | sed 's/drivers\/platform\/x86\/chromeos_laptop.c/drivers\/platform\/chrome\/chromeos_laptop.c/g'| patch -p1
done

# i2c driver issue with kernel 3.15
wget -O - https://raw.githubusercontent.com/masmullin2000/arch-c720p/master/i2c-designware-pcidrv.patch | patch -p1
# Backlight control issue with kernel 3.15
# wget -O - https://bugs.freedesktop.org/attachment.cgi?id=101813 | patch -p1

# fetch the chromeos_laptop and atmel maxtouch source code
# Copy made from chromium.googlesource.com chromeos-3.8 branch
# https://chromium.googlesource.com/chromiumos/third_party/kernel-next/+/refs/heads/chromeos-3.8
wget https://googledrive.com/host/0BxMvXgjEztvAbEdYM1o0ck5rOVE --output-document=patch_atmel_mxt_ts.c
# Fix for kernel >=3.13
sed -i -e "s/INIT_COMPLETION(/reinit_completion(\&/g" patch_atmel_mxt_ts.c
wget https://googledrive.com/host/0BxMvXgjEztvAdVBjQUljYWtiR2c --output-document=patch_chromeos_laptop.c

# copy source files into kernel tree replacing existing Ubuntu source
cp ./patch_atmel_mxt_ts.c drivers/input/touchscreen/atmel_mxt_ts.c
cp ./patch_chromeos_laptop.c drivers/platform/chrome/chromeos_laptop.c

echo "Building relevant modules..."
# Touchpad
cd drivers/platform/chrome/
mv Makefile Makefile.orig
echo 'KERNELVERSION = '$archkernver'
obj-m := chromeos_laptop.o

KDIR  := /lib/modules/$(shell uname -r)/build
PWD   := $(shell pwd)

default:
	$(MAKE) -C $(KDIR) M=$(PWD) modules' > Makefile
make -C /lib/modules/$archkernver/build M=$PWD modules
rm Makefile
mv Makefile.orig Makefile
cd ../../..

cd drivers/i2c/busses/
mv Makefile Makefile.orig
echo 'KERNELVERSION = '$archkernver'
obj-m := i2c-designware-core.o

KDIR  := /lib/modules/$(shell uname -r)/build
PWD   := $(shell pwd)

default:
	$(MAKE) -C $(KDIR) M=$(PWD) modules' > Makefile
make -C /lib/modules/$archkernver/build M=$PWD modules
rm Makefile

echo 'KERNELVERSION = '$archkernver'
obj-m := i2c-designware-pci.o
i2c-designware-pci-objs := i2c-designware-pcidrv.o

KDIR  := /lib/modules/$(shell uname -r)/build
PWD   := $(shell pwd)

default:
	$(MAKE) -C $(KDIR) M=$(PWD) modules' > Makefile
make -C /lib/modules/$archkernver/build M=$PWD modules
rm Makefile

echo 'KERNELVERSION = '$archkernver'
obj-m := i2c-designware-platform.o
i2c-designware-platform-objs := i2c-designware-platdrv.o

KDIR  := /lib/modules/$(shell uname -r)/build
PWD   := $(shell pwd)

default:
	$(MAKE) -C $(KDIR) M=$(PWD) modules' > Makefile
make -C /lib/modules/$archkernver/build M=$PWD modules
rm Makefile
mv Makefile.orig Makefile
cd ../../..

# Touchscreen
cd drivers/input/touchscreen/
mv Makefile Makefile.orig
echo 'KERNELVERSION = '$archkernver'
obj-m := atmel_mxt_ts.o

KDIR  := /lib/modules/$(shell uname -r)/build
PWD   := $(shell pwd)

default:
	$(MAKE) -C $(KDIR) M=$(PWD) modules' > Makefile
make -C /lib/modules/$archkernver/build M=$PWD modules
rm Makefile
mv Makefile.orig Makefile
cd ../../..

# ALS: /drivers/staging/iio/light/isl29018.o
cd drivers/staging/iio/light/
mv Makefile Makefile.orig
echo 'KERNELVERSION = '$archkernver'
obj-m := isl29018.o

KDIR  := /lib/modules/$(shell uname -r)/build
PWD   := $(shell pwd)

default:
	$(MAKE) -C $(KDIR) M=$(PWD) modules' > Makefile
make -C /lib/modules/$archkernver/build M=$PWD modules
rm Makefile
mv Makefile.orig Makefile
cd ../../../..


# ZRAM

cd drivers/block/zram
mv Makefile Makefile.orig
echo 'KERNELVERSION = '$archkernver'
obj-m := zram.o
zram-y	:=	zram_drv.o zcomp.o zcomp_lzo.o zcomp_lz4.o

obj-$(CONFIG_ZRAM)	+=	zram.o

KDIR  := /lib/modules/$(shell uname -r)/build
PWD   := $(shell pwd)
ccflags-y	+=  -DCONFIG_ZRAM_LZ4_COMPRESS

default:
	$(MAKE) -C $(KDIR) M=$(PWD) modules' > Makefile
make -C /lib/modules/$archkernver/build M=$PWD modules
rm Makefile
mv Makefile.orig Makefile
cd ../../..

# Compile patched i915 video driver (lazy mode...)
# make SUBDIRS=drivers/gpu/drm/i915 modules

echo "Installing relevant modules and driver..."
# Touchpad, TouchScreen, Zram...
su -c "cp drivers/platform/chrome/chromeos_laptop.ko /lib/modules/$archkernver/kernel/drivers/platform/chrome/ \
&& cp drivers/i2c/busses/i2c-designware-*.ko /lib/modules/$archkernver/kernel/drivers/i2c/busses/ \
&& cp drivers/input/touchscreen/atmel_mxt_ts.ko /lib/modules/$archkernver/kernel/drivers/input/touchscreen/ \
&& mkdir -p /lib/modules/$archkernver/kernel/drivers/staging/iio/light \
&& cp drivers/staging/iio/light/isl29018.ko /lib/modules/$archkernver/kernel/drivers/staging/iio/light/ \
&& mkdir -p /lib/modules/$archkernver/kernel/drivers/block/zram \
&& cp drivers/block/zram/z*.ko /lib/modules/$archkernver/kernel/drivers/block/zram/ \
&& depmod -a $archkernver && yum install xorg-x11-drv-synaptics"
# && cp drivers/gpu/drm/i915/i915.ko /lib/modules/$archkernver/kernel/drivers/gpu/drm/i915/i915.ko \


echo "Les modules pour le pavé, l'écran tactiles, l'ALS et ZRAM sont prêts."
echo -e "Pour utiliser votre nouveau noyau patché, tapez : \n$ reboot"
