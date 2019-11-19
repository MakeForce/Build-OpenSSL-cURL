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


export NDK=${NDK_PATH}
export HOST_TAG="darwin-x86_64"
export TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/$HOST_TAG

BASE_PATH=`pwd`

mkdir -p build

out_base="$BASE_PATH/build/"

OPENSSL="${PWD}/../openssl/build"

build()
{
	ARCH=$1

	pushd . > /dev/null
	cd "${CURL_VERSION}"

	if [ "$ARCH" == "armeabi" ]; then
		arch_tag="arm-linux-androideabi"
		tooL_name="arm-linux-androideabi"
	elif [ "$ARCH" == "armeabi-v7a" ]; then
		arch_tag="armv7a-linux-androideabi"
		tooL_name="arm-linux-androideabi"
	elif [ "$ARCH" == "arm64-v8a" ]; then
		arch_tag="aarch64-linux-android"
		tooL_name="aarch64-linux-android"
	elif [ "$ARCH" == "x86" ]; then
		arch_tag="i686-linux-android"
		tooL_name="i686-linux-android"
	else
		arch_tag="x86_64-linux-android"
		tooL_name="x86_64-linux-android"
	fi

	export AR=$TOOLCHAIN/bin/${tooL_name}-ar
	export AS=$TOOLCHAIN/bin/${tooL_name}-as
	if [ "${tooL_name}" == "arm-linux-androideabi" ]; then
		export CC=$TOOLCHAIN/bin/armv7a-linux-androideabi23-clang
		export CXX=$TOOLCHAIN/bin/armv7a-linux-androideabi23-clang++
	else
		export CC=$TOOLCHAIN/bin/${tooL_name}23-clang
		export CXX=$TOOLCHAIN/bin/${tooL_name}23-clang++
	fi
	export LD=$TOOLCHAIN/bin/${tooL_name}-ld
	export NM==$TOOLCHAIN/bin/${tooL_name}-nm
	export RANLIB=$TOOLCHAIN/bin/${tooL_name}-ranlib
	export STRIP=$TOOLCHAIN/bin/${tooL_name}-stripb

	./configure --host ${arch_tag} --with-pic --disable-shared --enable-static --disable-ldap --disable-ldaps --without-zlib  --prefix="${out_base}/${ARCH}" --with-ssl="${OPENSSL}/${ARCH}/openssl" #&> "${out_base}/${CURL_VERSION}-android-${ARCH}.log"


	make -j4 #>> "${out_base}/${CURL_VERSION}-android-${ARCH}.log" 2>&1
	make install #>> "${out_base}/${CURL_VERSION}-android-${ARCH}.log" 2>&1
	make clean #>> "${out_base}/${CURL_VERSION}-android-${ARCH}.log" 2>&1
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
	build "${arch}"
done

#reset trap
trap - INT TERM EXIT

echo "Done"