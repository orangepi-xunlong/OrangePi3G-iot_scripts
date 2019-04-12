#!/bin/bash
set -e
##############################################
##
## Compile kernel
##
##############################################
if [ -z $ROOT ]; then
	ROOT=`cd .. && pwd`
fi
# Platform
if [ -z $PLATFORM ]; then
	PLATFORM="3g-iot-A"
fi
# Cleanup
if [ -z $CLEANUP ]; then
	CLEANUP="0"
fi
# kernel option
if [ -z $BUILD_KERNEL ]; then
	BUILD_KERNEL="0"
fi
# module option
if [ -z $BUILD_MODULE ]; then
	BUILD_MODULE="0"
fi
# Knernel Direct
LINUX=$ROOT/kernel
# Compile Toolchain
TOOLS=$ROOT/toolchain/arm-eabi-4.7/bin/arm-eabi-
# OUTPUT DIRECT
OBJ=$ROOT/output/obj
BUILD=$ROOT/output/obj/KERNEL_OBJ
CORES=4
# MTK
export PATH=$ROOT/external/make:$PATH
export TARGET_PRODUCT=$MTK_PROJECT

if [ ! -e $ROOT/output/project ]; then
	VAR=""
else
	VAR=$(cat $ROOT/output/project)
fi
	
if [ ! -z $VAR ]; then
	if [ $MTK_PROJECT != $VAR ]; then 
		sudo rm $OBJ -rf
	fi
fi

EXTERNAL=$ROOT/external/
if [ ! -d $OBJ ]; then
	mkdir -p $OBJ
	cp -rfa $ROOT/external/$MTK_PROJECT/* $OBJ 
	echo "$MTK_PROJECT" > $ROOT/output/project
	if [ $MTK_PROJECT = "hexing72_cwet_lca" ]; then
		cp $EXTERNAL/project/a/config/common/custom.conf $EXTERNAL/mediatek/config/common/
		cp $EXTERNAL/project/a/kernel/drivers/keypad/kpd.c $EXTERNAL/mediatek/kernel/drivers/keypad/
		cp $EXTERNAL/project/a/ddp_rdma.c $EXTERNAL/mediatek/platform/mt6572/kernel/drivers/dispsys/
		cp $EXTERNAL/project/a/lk/* $EXTERNAL/mediatek/platform/mt6572/lk/
	else
		cp $EXTERNAL/project/b/config/common/custom.conf $EXTERNAL/mediatek/config/common/
		cp $EXTERNAL/project/b/kernel/drivers/keypad/kpd.c $EXTERNAL/mediatek/kernel/drivers/keypad/
		rm -rf $EXTERNAL/mediatek/platform/mt6572/kernel/drivers/dispsys/ddp_rdma.c
		cp $EXTERNAL/project/b/lk/* $EXTERNAL/mediatek/platform/mt6572/lk/
		
	fi
fi 



# Perpare souce code
if [ ! -d $LINUX ]; then
	whiptail --title "OrangePi Build System" --msgbox \
		"Kernel doesn't exist, pls perpare linux source code." 10 40 0 --cancel-button Exit
	exit 0
fi

clear
echo -e "\e[1;31m Start Compile.....\e[0m"
export PATH=$ROOT/external/make:$PATH

if [ $CLEANUP = "1" ]; then
	make -C $LINUX ARCH=arm CROSS_COMPILE=$TOOLS O=$BUILD clean
	echo -e "\e[1;31m Clean up kernel \e[0m"
fi

if [ ! -f $BUILD/.config ]; then
	make -C $LINUX ARCH=arm CROSS_COMPILE=$TOOLS O=$BUILD ${PLATFORM}_linux_defconfig
	echo -e "\e[1;31m Using ${PLATFORM}_linux_defconfig \e[0m"
fi

	make -C $LINUX  CROSS_COMPILE=$TOOLS O=$BUILD silentoldconfig
if [ $BUILD_KERNEL = "1" ]; then
	# make kernel
	make -C $LINUX ARCH=arm CROSS_COMPILE=$TOOLS -j${CORES} O=$BUILD
fi

if [ $BUILD_MODULE = "1" ]; then
	# make module
	echo -e "\e[1;31m Start Compile Module \e[0m"
	make -C $LINUX ARCH=arm CROSS_COMPILE=$TOOLS -j${CORES} O=$BUILD modules

	# Compile Mali450 driver
	#echo -e "\e[1;31m Compile Mali450 Module \e[0m"
	if [ ! -d $BUILD/lib ]; then
		mkdir -p $BUILD/lib
	fi 
	#make -C ${LINUX}/modules/gpu ARCH=arm64 CROSS_COMPILE=$TOOLS LICHEE_KDIR=${LINUX} LICHEE_MOD_DIR=$BUILD/lib LICHEE_PLATFORM=linux
	#echo -e "\e[1;31m Build Mali450 succeed \e[0m"

	# install module
	echo -e "\e[1;31m Start Install Module \e[0m"
	make -C $LINUX ARCH=arm CROSS_COMPILE=$TOOLS -j${CORES} O=$BUILD modules_install INSTALL_MOD_PATH=$ROOT/output
	# Install mali driver
	#MALI_MOD_DIR=$BUILD/lib/modules/`cat $LINUX/include/config/kernel.release 2> /dev/null`/kernel/drivers/gpu
	#install -d $MALI_MOD_DIR
	#mv ${BUILD}/lib/mali.ko $MALI_MOD_DIR
fi

#if [ $BUILD_KERNEL = "1" ]; then
	# compile dts
#	echo -e "\e[1;31m Start Compile DTS \e[0m"
#	make -C $LINUX ARCH=arm64 CROSS_COMPILE=$TOOLS -j${CORES} dtbs
	#$ROOT/kernel/scripts/dtc/dtc -Odtb -o "$BUILD/OrangePiH6.dtb" "$LINUX/arch/arm64/boot/dts/${PLATFORM}.dts"
	## DTB conver to DTS
	# Command:
	# dtc -I dtb -O dts -o target_file.dts source_file.dtb
	########
	# Update DTB with uboot
#	echo -e "\e[1;31m Cover sys_config.fex to DTS \e[0m"
#	cd $ROOT/scripts/pack/
#	./pack
#	cd -

#fi
	
mkimg=$ROOT/external/mediatek/build/tools/mkimage
kernel_zimg=$ROOT/output/obj/KERNEL_OBJ/arch/arm/boot/zImage

${mkimg} ${kernel_zimg} KERNEL > $ROOT/output/obj/KERNEL_OBJ/kernel_${MTK_PROJECT}.bin
$ROOT/external/mkbootimg --kernel $ROOT/output/obj/KERNEL_OBJ/kernel_${MTK_PROJECT}.bin --board 2016.07.04  --output $ROOT/output/boot.img

clear
whiptail --title "OrangePi Build System" --msgbox \
	"Build Kernel OK. The path of output file: ${BUILD}" 10 80 0
