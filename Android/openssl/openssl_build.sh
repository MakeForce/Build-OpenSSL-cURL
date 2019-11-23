#!/bin/bash

usage ()
{
	echo "usage: $0 [openssl version] [archs (defaults to \"armeabi-v7a arm64-v8a x86 x86_64\")] [NDK path]"
	trap - INT TERM EXIT
	exit 127
}

if [ "$1" == "-h" ]; then
	usage
fi

if [ -z $1 ]; then
	OPENSSL_VERSION="openssl-1.1.1d"
else
	OPENSSL_VERSION="openssl-$1"
fi

if [ -z "$2" ]; then
    archs="armeabi-v7a arm64-v8a x86 x86_64"
else
    archs="$2"
fi

if [ "$3" != "" ]; then
	NDK_PATH="$3"
fi

if [ ! ${NDK_PATH} ]; then
	echo "FATAL ERROR: NDK not found"
	exit
fi

BASE_PATH=`pwd`

rm -rf build
mkdir -p build

BASE_PATH=$BASE_PATH/build
TOOLCHAIN_BASE="${PWD}/../toolschain"

build()
{
	ARCH=$1
	
	mkdir -p build/$ARCH/usr
	mkdir -p build/$ARCH/logs

	OUT_PATH="$BASE_PATH/$ARCH/usr"
	LOGS_PATH="$BASE_PATH/$ARCH/logs"

	pushd . > /dev/null
	if [ "$ARCH" == "armeabi-v7a" ]; then
		arch_name="arm"
		ARCH_TAG=arm-linux-androideabi
	elif [ "$ARCH" == "arm64-v8a" ]; then
		arch_name="arm64"
		ARCH_TAG=aarch64-linux-android
	elif [ "$ARCH" == "x86" ]; then
		arch_name="x86"
		ARCH_TAG=x86
	else
		arch_name="x86_64"
		ARCH_TAG=x86_64
	fi

	# NDK_r16b 编译方式

	export ANDROID_NDK_HOME=$NDK_PATH
	PATH=$ANDROID_NDK_HOME/toolchains/$ARCH_TAG-4.9/prebuilt/darwin-x86_64/bin:$PATH

	cd "${OPENSSL_VERSION}"
	./Configure android-${arch_name} \
				-D__ANDROID_API__=14 \
				--prefix="$OUT_PATH" \
				--openssldir="$OUT_PATH/openssl" \
				&> "$LOGS_PATH/configure_$OPENSSL_VERSION.log"

	# NDK toolchain 编译方式

	# export ANDROID_NDK_HOME="${TOOLCHAIN_BASE}/$ARCH"
	# PATH=$ANDROID_NDK_HOME/bin:$PATH

	# cd "${OPENSSL_VERSION}"
	# ./Configure android-${arch_name} \
	# 			--prefix="$OUT_PATH" \
	# 			&> "$LOGS_PATH/configure_$OPENSSL_VERSION.log"
	
	# openssl-OpenSSL_1_0_2p toolchain 编译方式

	# TOOLCHAIN="${TOOLCHAIN_BASE}/$ARCH"
	# PATH=$TOOLCHAIN/bin:$PATH
	# export AR=$TOOLCHAIN/bin/${ARCH_TAG}-ar
	# export AS=$TOOLCHAIN/bin/${ARCH_TAG}-as
	# export CC=$TOOLCHAIN/bin/${ARCH_TAG}-gcc
	# export CXX=$TOOLCHAIN/bin/${ARCH_TAG}-g++
	# # export CPP=$TOOLCHAIN/bin/${ARCH_TAG}-c++
	# export LD=$TOOLCHAIN/bin/${ARCH_TAG}-ld
	# export NM==$TOOLCHAIN/bin/${ARCH_TAG}-nm
	# export RANLIB=$TOOLCHAIN/bin/${ARCH_TAG}-ranlib
	# export STRIP=$TOOLCHAIN/bin/${ARCH_TAG}-stripb

	# tar xfz openssl-OpenSSL_1_0_2p.tar.gz

	# cd openssl-OpenSSL_1_0_2p

	# ./Configure android-armv7 \
	#             -D__ANDROID_API__=14 \
	#             --prefix="${OUT_PATH}" \
	#             --openssldir=${OUT_PATH}/openssl \
	#             &> "${LOGS_PATH}/configure_openssl.log"
	
	make -j4 >> "$LOGS_PATH/build_$OPENSSL_VERSION.log" 2>&1
	make install >> "$LOGS_PATH/install_$OPENSSL_VERSION.log" 2>&1
	make clean >> "$LOGS_PATH/clean_$OPENSSL_VERSION.log" 2>&1
	popd > /dev/null
}

if [ ! -e ${OPENSSL_VERSION}.tar.gz ]; then
	echo "Downloading ${OPENSSL_VERSION}.tar.gz"
	curl -LO https://www.openssl.org/source/${OPENSSL_VERSION}.tar.gz
else
	echo "Using ${OPENSSL_VERSION}.tar.gz"
fi

if [[ "$OPENSSL_VERSION" = "openssl-1.1.1"* ]]; then
	echo "** Building OpenSSL 1.1.1 **"
else
	if [[ "$OPENSSL_VERSION" = "openssl-1.0."* ]]; then
		echo "** Building OpenSSL 1.0.x - WARNING: End of Life Version - Upgrade to 1.1.1 **"
	else
		echo "** WARNING: This build script has not been tested with $OPENSSL_VERSION **"
	fi
fi

echo "Unpacking openssl"
tar xfz "${OPENSSL_VERSION}.tar.gz"

for arch in $archs
do
	echo "         Building ${OPENSSL_VERSION} for ${arch}"
	build ${arch}
done

rm -rf ${OPENSSL_VERSION}

echo "Done"