#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
BUILD_DIR=build
PACKAGE_DIR=package
PACKAGE_NAME=wm8960-modules
REPO=https://github.com/raspberrypi/linux
KERNELS=("kernel" "kernel7" "kernel7l" "kernel8")
KERNEL_SUFFIXES=("+" "-v7+" "-v7l+" "-v8+")
DEFCONFS=("bcmrpi_defconfig" "bcm2709_defconfig" "bcm2711_defconfig" "bcm2711_defconfig")

function clean {
	sudo rm -rf $SCRIPT_DIR/$PACKAGE_DIR
	rm $PACKAGE_NAME*.tar.gz
}

function build_version {
	branch=$1.y
	mkdir -p $SCRIPT_DIR/$BUILD_DIR
	[[ -d $SCRIPT_DIR/$BUILD_DIR/$branch ]] || git clone --depth=1 --branch rpi-$branch $REPO $SCRIPT_DIR/$BUILD_DIR/$branch

	pushd $SCRIPT_DIR/$BUILD_DIR/$branch
	ver=$(make kernelversion)

	for ((i = 0; i < ${#KERNELS[@]}; i++)); do
		echo "Build Kernel Modules $ver${KERNEL_SUFFIXES[$i]}"
		KERNEL=${KERNELS[$i]}
		if [[ $KERNEL = "kernel8" ]]; then
			xcompile=aarch64-linux-gnu-
			arch=arm64
		else
			xcompile=arm-linux-gnueabihf-
			arch=arm
		fi
		make ARCH=$arch CROSS_COMPILE=$xcompile ${DEFCONFS[$i]}
		make ARCH=$arch CROSS_COMPILE=$xcompile modules_prepare
		make -j$(($(nproc) + 1)) ARCH=$arch CROSS_COMPILE=$xcompile modules
		make -j$(($(nproc) + 1)) ARCH=$arch CROSS_COMPILE=$xcompile dtbs

		overlay_dir=$SCRIPT_DIR/$PACKAGE_DIR/boot/overlays
		codec_dir=$SCRIPT_DIR/$PACKAGE_DIR/lib/modules/$ver${KERNEL_SUFFIXES[$i]}/kernel/sound/soc/codecs
		echo "Package wm8960 overlay & codec of kernel version $ver${KERNEL_SUFFIXES[$i]}"
		mkdir -p $overlay_dir
		cp -n arch/arm/boot/dts/overlays/wm8960-soundcard.dtbo $overlay_dir/
		mkdir -p $codec_dir
		cp -n sound/soc/codecs/snd-soc-wm8960.ko $codec_dir/
	done
	popd

	echo "Deploy tarball"
	sudo chown -R 0:0 $PACKAGE_DIR
	tar -zcvf $PACKAGE_NAME-rpi-$ver.tar.gz $PACKAGE_DIR/*
	sudo rm -rf $PACKAGE_DIR
}

if [[ $1 = "clean" ]]; then
	clean
else
	for v in $@; do
		build_version $v
	done
fi

