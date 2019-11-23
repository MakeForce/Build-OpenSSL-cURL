#!/bin/bash

set -e

# set trap to help debug any build errors
trap 'echo "** ERROR with Build - Check /tmp/curl*.log"; tail /tmp/curl*.log' INT TERM EXIT

usage ()
{
	echo "usage: $0 [openssl version] [archs (defaults to \"armeabi armeabi-v7a arm64-v8a x86 x86_64\")] [NDK path]"
	trap - INT TERM EXIT
	exit 127
}

if [ "$1" == "-h" ]; then
	usage
fi

if [ -z $1 ]; then
	CURL_VERSION="curl-7.66.0"
else
	CURL_VERSION="curl-$1"
fi

if [ -z "$2" ]; then
    archs="armeabi armeabi-v7a arm64-v8a x86 x86_64"
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

OPENSSL_BASE="${PWD}/../openssl/build"
TOOLCHAIN_BASE="${PWD}/../toolschain"

# export NDK=$NDK_PATH
export HOST_TAG=darwin-x86_64

build()
{
	ARCH=$1

	mkdir -p build/$ARCH/usr
	mkdir -p build/$ARCH/logs

	OUT_PATH="$BASE_PATH/$ARCH/usr"
	LOGS_PATH="$BASE_PATH/$ARCH/logs"

	pushd . > /dev/null
	
	if [ "$ARCH" == "armeabi-v7a" ]; then
		ARCH_TAG="arm-linux-androideabi"
	elif [ "$ARCH" == "arm64-v8a" ]; then
		ARCH_TAG="aarch64-linux-android"
	elif [ "$ARCH" == "x86" ]; then
		ARCH_TAG="i686-linux-android"
	else
		ARCH_TAG="x86_64-linux-android"
	fi

	OPENSSL=$OPENSSL_BASE/$ARCH/usr
	export NDK="${TOOLCHAIN_BASE}/$ARCH"
	PATH=$ANDROID_NDK_HOME/bin:$PATH
	export TOOLCHAIN="${TOOLCHAIN_BASE}/$ARCH"
	export AR=$TOOLCHAIN/bin/$ARCH_TAG-ar
	export AS=$TOOLCHAIN/bin/$ARCH_TAG-as
	export CC=$TOOLCHAIN/bin/$ARCH_TAG-clang
	export CXX=$TOOLCHAIN/bin/$ARCH_TAG-clang++
	# export CC=$TOOLCHAIN/bin/$ARCH_TAG-gcc
	# export CC=$TOOLCHAIN/bin/$ARCH_TAG-g++
	export LD=$TOOLCHAIN/bin/$ARCH_TAG-ld
	export NM=$TOOLCHAIN/bin/$ARCH_TAG-nm
	export RANLIB=$TOOLCHAIN/bin/$ARCH_TAG-ranlib
	export STRIP=$TOOLCHAIN/bin/$ARCH_TAG-strip

	cd "${CURL_VERSION}"
	./configure --host $ARCH_TAG \
				--with-pic \
				--disable-shared \
				--enable-static \
				--disable-ldap --disable-ldaps \
				--without-zlib  \
				--prefix="${OUT_PATH}" \
				--with-ssl="${OPENSSL}" \
				&> "$LOGS_PATH/configure_${CURL_VERSION}.log"


	make -j4 >> "$LOGS_PATH/build_${CURL_VERSION}.log" 2>&1
	make install >> "$LOGS_PATH/install_${CURL_VERSION}.log" 2>&1
	make clean >> "$LOGS_PATH/clean_${CURL_VERSION}.log" 2>&1
	popd > /dev/null
}

if [ ! -e ${CURL_VERSION}.tar.gz ]; then
	echo "Downloading ${CURL_VERSION}.tar.gz"
	curl -LO https://curl.haxx.se/download/${CURL_VERSION}.tar.gz
else
	echo "Using ${CURL_VERSION}.tar.gz"
fi

echo "Unpacking curl"
tar xfz "${CURL_VERSION}.tar.gz"

for arch in $archs
do
	echo "         Building ${CURL_VERSION} for ${arch}"
	build "${arch}"
done

#reset trap
trap - INT TERM EXIT

echo "Done"