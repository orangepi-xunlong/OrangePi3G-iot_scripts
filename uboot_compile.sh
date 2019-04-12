#!/bin/bash
set -e
#################################
##
## Compile preloader and lk
## 
#################################
# ROOT must be top direct.
if [ -z $ROOT ]; then
	ROOT=`cd .. && pwd`
fi
# PLATFORM.
if [ -z $PLATFORM ]; then
	PLATFORM="3g-iot-A"
fi
# Uboot direct
BOOTLOADER=$ROOT/bootloader
UBOOT=$BOOTLOADER
PRELOADER=$ROOT/bootloader/preloader
LK=$ROOT/bootloader/lk
# Compile Toolchain
TOOLS=$ROOT/toolchain/arm-linux-androideabi-4.7/bin/arm-linux-androideabi-
KERNEL=${ROOT}/kernel

BUILD=$ROOT/output
OBJ=$BUILD/obj
CORES=$((`cat /proc/cpuinfo | grep processor | wc -l` - 1))
if [ $CORES -eq 0 ]; then
	CORES=1
fi


# Perpar souce code
if [ ! -d $UBOOT ]; then
	whiptail --title "OrangePi Build System" \
		--msgbox "u-boot doesn't exist, pls perpare u-boot source code." \
		10 50 0
	exit 0
fi

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



export CROSS_COMPILE=$TOOLS
export TOOLCHAIN_PREFIX=$TOOLS
export TOOLCHAIN_PATH=$ROOT/toolchain/arm-linux-androideabi-4.7/bin

echo -e "\e[1;35m Build Preloader\e[0m"
cd $PRELOADER
./sh.sh
echo -e "\e[1;35m Build LK\e[0m"
cd $LK
./sh.sh
cd $ROOT/scripts
cp $BUILD/obj/PRELOADER_OBJ/bin/preloader_$MTK_PROJECT.bin $BUILD
cp $BUILD/obj/BOOTLOADER_OBJ/build-$MTK_PROJECT/lk.bin $BUILD
cp $BUILD/obj/BOOTLOADER_OBJ/build-$MTK_PROJECT/logo.bin $BUILD

echo -e "\e[1;31m =======================================\e[0m"
echo -e "\e[1;31m         Complete compile....		 \e[0m"
echo -e "\e[1;31m =======================================\e[0m"
echo " "
whiptail --title "OrangePi Build System" \
	--msgbox "Build lk finish. The output path: $BUILD" 10 60 0
