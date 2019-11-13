#!/bin/bash
# This script downlaods and builds the Mac, iOS and tvOS nghttp2 libraries 
#
# Credits:
# Jason Cox, @jasonacox
#   https://github.com/jasonacox/Build-OpenSSL-cURL 
#
# NGHTTP2 - https://github.com/nghttp2/nghttp2
#

# > nghttp2 is an implementation of HTTP/2 and its header 
# > compression algorithm HPACK in C
# 
# NOTE: pkg-config is required
 
set -e

# set trap to help debug build errors
trap 'echo "** ERROR with Build - Check /tmp/nghttp2*.log"; tail /tmp/nghttp2*.log' INT TERM EXIT

usage ()
{
	echo "usage: $0 [nghttp2 version] [archs (defaults to \"armv7 armv7s arm64 arm64e i386 x86_64\")] [bitcode (defaults to enable bitcode)]"
	trap - INT TERM EXIT
	exit 127
}

if [ "$1" == "-h" ]; then
	usage
fi

if [ -z $1 ]; then
	NGHTTP2_VERNUM="1.39.2"
else
	NGHTTP2_VERNUM="$1"
fi

if [ -z "$2" ]; then
    archs="armv7 armv7s arm64 arm64e i386 x86_64"
else
    archs="$2"
fi

if [ -z "$3" ]; then
	bitcode="-fembed-bitcode"
	echo_bit="bitcode"
else
    bitcode=""
	echo_bit="nobitcode"
	if [ "$3" == "bitcode" ];then
		bitcode="-fembed-bitcode"
		echo_bit="bitcode"
	fi
fi

IOS_SDK_VERSION=""
IOS_MIN_SDK_VERSION="7.1"

NGHTTP2_VERSION="nghttp2-${NGHTTP2_VERNUM}"
DEVELOPER=`xcode-select -print-path`

NGHTTP2="${PWD}/../nghttp2"

# Check to see if pkg-config is already installed
if (type "pkg-config" > /dev/null) ; then
	echo "pkg-config installed"
else
	echo "ERROR: pkg-config not installed... attempting to install."

	# Check to see if Brew is installed
	if ! type "brew" > /dev/null; then
		echo "FATAL ERROR: brew not installed - unable to install pkg-config - exiting."
		exit
	else
		echo "brew installed - using to install pkg-config"
		brew install pkg-config
	fi

	# Check to see if installation worked
	if (type "pkg-config" > /dev/null) ; then
		echo "SUCCESS: pkg-config installed"
	else
		echo "FATAL ERROR: pkg-config failed to install - exiting."
		exit
	fi
fi

buildIOS()
{
	ARCH=$1

	pushd . > /dev/null
	cd "${NGHTTP2_VERSION}"
  
	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
	fi
  
	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc"
	export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} ${bitcode}"
        export LDFLAGS="-arch ${ARCH} -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK}"
   
	echo "Building ${NGHTTP2_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"
    if [[ "${ARCH}" == "arm64" || "${ARCH}" == "arm64e"  ]]; then
		./configure --disable-shared --disable-app --disable-threads --enable-lib-only  --prefix="${NGHTTP2}/iOS/${ARCH}" --host="arm-apple-darwin" &> "/tmp/${NGHTTP2_VERSION}-iOS-${ARCH}.log"
    else
		./configure --disable-shared --disable-app --disable-threads --enable-lib-only --prefix="${NGHTTP2}/iOS/${ARCH}" --host="${ARCH}-apple-darwin" &> "/tmp/${NGHTTP2_VERSION}-iOS-${ARCH}.log"
    fi

    make -j8 >> "/tmp/${NGHTTP2_VERSION}-iOS-${ARCH}.log" 2>&1
    make install >> "/tmp/${NGHTTP2_VERSION}-iOS-${ARCH}.log" 2>&1
    make clean >> "/tmp/${NGHTTP2_VERSION}-iOS-${ARCH}.log" 2>&1
    popd > /dev/null
}

echo "Cleaning up"
rm -rf include/nghttp2/* lib/*

rm -fr iOS

mkdir -p iOS/lib
mkdir -p iOS/include/nghttp2/

rm -rf "/tmp/${NGHTTP2_VERSION}-*"
rm -rf "/tmp/${NGHTTP2_VERSION}-*.log"

rm -rf "${NGHTTP2_VERSION}"

if [ ! -e ${NGHTTP2_VERSION}.tar.gz ]; then
	echo "Downloading ${NGHTTP2_VERSION}.tar.gz"
	curl -LO https://github.com/nghttp2/nghttp2/releases/download/v${NGHTTP2_VERNUM}/${NGHTTP2_VERSION}.tar.gz
else
	echo "Using ${NGHTTP2_VERSION}.tar.gz"
fi

echo "Unpacking nghttp2"
tar xfz "${NGHTTP2_VERSION}.tar.gz"

isCopy=0;
count=0;

echo "Building iOS ${archs} libraries ${echo_bit}"

nghttp2Path=""

for arch in $archs
do
	buildIOS "${arch}"
    if [ "$isCopy" == "0" ];then
		echo "   Copying headers"
		cp ${NGHTTP2}/iOS/${ARCH}/include/nghttp2/* iOS/include/nghttp2/
		isCopy=1;
	fi
	count=`expr $count + 1`;
	nghttp2Path="$nghttp2Path ${NGHTTP2}/iOS/${ARCH}/lib/libnghttp2.a"
done

if [ $count == 1 ];then
	cp nghttp2Path iOS/lib//libnghttp2.a
else
	lipo -create ${nghttp2Path}  -output iOS/lib/libnghttp2.a
fi

echo "Cleaning up"
rm -rf /tmp/${NGHTTP2_VERSION}-*
rm -rf ${NGHTTP2_VERSION}

#reset trap
trap - INT TERM EXIT

echo "Done"