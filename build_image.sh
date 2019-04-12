#!/bin/bash
################################################################
##
##
##
################################################################
set -e

if [ -z $ROOT ]; then
	ROOT=`cd .. && pwd`
fi

if [ -z $1 ]; then
    DISTRO="xenial"
else
    DISTRO=$1
fi

if [ -z $2 ]; then
    PLATFORM="4G-iot"
else
    PLATFORM=$2
fi

if [ $3 = "1" ]; then
    IMAGETYPE="desktop"
    disk_size="3800"
else
    IMAGETYPE="server"
    disk_size="488"
fi

if [ $PLATFORM = "3g-iot-A" ]; then
	MTK_PROJECT="hexing72_cwet_lca"
elif [ $PLATFORM = "3g-iot-B" ]; then
	MTK_PROJECT="hexing72_cwet_kk"
else
	MTK_PROJECT=
fi

OUTPUT="$ROOT/output"
VER="v1.0"
IMAGENAME="OrangePi_${PLATFORM}_${DISTRO}_${IMAGETYPE}_${VER}"
IMAGE=$OUTPUT/$IMAGENAME
ROOTFS=$OUTPUT/rootfs
PRELOADERBIN=$OUTPUT/preloader_$MTK_PROJECT.bin
LKBIN=$OUTPUT/lk.bin
LOGOBIN=$OUTPUT/logo.bin
BOOTIMG=$OUTPUT/boot.img

if [ ! -f $PRELOADERBIN -o ! -f $LKBIN ]; then
	echo "Please build lk"
	exit 0
fi
if [ ! -f $KERNEL ]; then
	echo "Please build linux"
	exit 0
fi

if [ ! -d $IMAGE ]; then
	mkdir -p $IMAGE
fi
rm -rf $IMAGE/*

copy_file_to_rootfs (){
	mkdir -p $OUTPUT/rootfs/etc/firmware
	mkdir -p $OUTPUT/rootfs/system/etc/firmware 
	cp -rfa $ROOT/external/firmware/* $OUTPUT/rootfs/system/etc/firmware
	cp -rfa $ROOT/external/firmware/* $OUTPUT/rootfs/etc/firmware
	cp $ROOT/external/6620_launcher $OUTPUT/rootfs/usr/local/sbin
	cp $ROOT/external/wmt_loader $OUTPUT/rootfs/usr/local/sbin
	cp $ROOT/external/rc.local $OUTPUT/rootfs/etc/
	echo "ttyMT0" >> $OUTPUT/rootfs/etc/securetty
}

set -x

cp $PRELOADERBIN $IMAGE
cp $LKBIN $IMAGE
cp $LOGOBIN $IMAGE
cp $BOOTIMG $IMAGE
cp $ROOT/external/system/$MTK_PROJECT/*  $IMAGE
copy_file_to_rootfs

if [ $PLATFORM = "3g-iot-A" ]; then
	mkfs.ubifs -r $ROOTFS -o $OUTPUT/ubifs.img -m 4096 -e 253952 -c 1800 -v
	echo "image=$OUTPUT/ubifs.img" >> $ROOT/external/ubi_android.ini
	ubinize -o $IMAGE/rootfs.img -m 4096 -p 262144 -O 4096 -v $ROOT/external/ubi_android.ini
	rm -rf $OUTPUT/ubifs.img
elif [ $PLATFORM = "3g-iot-B" ]; then
	dd if=/dev/zero bs=1M count=$disk_size of=$IMAGE/rootfs.img
	mkfs.ext4 -F -b 4096 -E stride=2,stripe-width=1024 -L rootfs $IMAGE/rootfs.img
	if [ ! -d /media/tmp ]; then
		mkdir -p /media/tmp
	fi

	mount -t ext4 $IMAGE/rootfs.img /media/tmp
	#Add rootfs into Image
	cp -rfa $OUTPUT/rootfs/* /media/tmp
	umount /media/tmp
else
	echo bb
fi
sync
set +x
clear
