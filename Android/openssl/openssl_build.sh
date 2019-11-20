#!/bin/bash

set -e

# set trap to help debug build errors
trap 'echo "** ERROR with Build - Check openssl*.log"; tail openssl*.log' INT TERM EXIT

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
	OPENSSL_VERSION="openssl-1.1.1d"
else
	OPENSSL_VERSION="openssl-$1"
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


export NDK=${NDK_PATH}

BASE_PATH=`pwd`

mkdir -p build

out_base="$BASE_PATH/build"

build()
{
	ARCH=$1
	mkdir -p "build/${ARCH}"
	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"
	if [[ "$ARCH" == "armeabi-v7a" || "$ARCH" == "armeabi" ]]; then
		arch_name="arm"
	elif [ "$ARCH" == "arm64-v8a" ]; then
		arch_name="arm64"
	elif [ "$ARCH" == "x86" ]; then
		arch_name="x86"
	else
		arch_name="x86_64"
	fi
	
	export ANDROID_NDK_HOME="${NDK}"
	PATH=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin:$PATH
	./Configure android-${arch_name} -no-shared -no-pic no-asm -D__ANDROID_API__=23 --prefix="${out_base}/${ARCH}" --openssldir="${out_base}/${ARCH}" &> "${out_base}/${ARCH}/${OPENSSL_VERSION}-android.log"
	make -j4 >> "${out_base}/${ARCH}/${OPENSSL_VERSION}-android.log" 2>&1
	make install >> "${out_base}/${ARCH}/${OPENSSL_VERSION}-android.log" 2>&1
	make clean >> "${out_base}/${ARCH}/${OPENSSL_VERSION}-android.log" 2>&1
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
	build "${arch}"
done

#reset trap
trap - INT TERM EXIT

echo "Done"

#./openssl_build.sh 1.1.1d armeabi-v7a ~/Library/Developer/Android/ndk/android-ndk-r20