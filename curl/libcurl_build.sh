#!/bin/bash

# This script downlaods and builds the Mac, iOS and tvOS libcurl libraries with Bitcode enabled

# Credits:
#
# Felix Schwarz, IOSPIRIT GmbH, @@felix_schwarz.
#   https://gist.github.com/c61c0f7d9ab60f53ebb0.git
# Bochun Bai
#   https://github.com/sinofool/build-libcurl-ios
# Jason Cox, @jasonacox
#   https://github.com/jasonacox/Build-OpenSSL-cURL 
# Preston Jennings
#   https://github.com/prestonj/Build-OpenSSL-cURL 

set -e

# set trap to help debug any build errors
trap 'echo "** ERROR with Build - Check /tmp/curl*.log"; tail /tmp/curl*.log' INT TERM EXIT

usage ()
{
	echo "usage: $0 [openssl version] [archs (defaults to \"armv7 armv7s arm64 arm64e i386 x86_64\")] [bitcode (defaults to enable bitcode)]"
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

DEVELOPER=`xcode-select -print-path`

OPENSSL="${PWD}/../openssl"  

# HTTP2 support
NOHTTP2="/tmp/no-http2"
if [ ! -f "$NOHTTP2" ]; then
	# nghttp2 will be in ../nghttp2/{Platform}/{arch}
	NGHTTP2="${PWD}/../nghttp2"  
fi

if [ ! -z "$NGHTTP2" ]; then 
	echo "Building with HTTP2 Support (nghttp2)"
else
	echo "Building without HTTP2 Support (nghttp2)"
	NGHTTP2CFG=""
	NGHTTP2LIB=""
fi

buildIOS()
{
	ARCH=$1

	pushd . > /dev/null
	cd "${CURL_VERSION}"
  
	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
	fi

	if [ ! -z "$NGHTTP2" ]; then 
		NGHTTP2CFG="--with-nghttp2=${NGHTTP2}/iOS/${ARCH}"
		NGHTTP2LIB="-L${NGHTTP2}/iOS/${ARCH}/lib"
	fi
	  
	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc"
	export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} ${bitcode}"
	export LDFLAGS="-arch ${ARCH} -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -L${OPENSSL}/iOS/lib ${NGHTTP2LIB}"
   
	echo "Building ${CURL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"

	if [[ "${ARCH}" == *"arm64"* || "${ARCH}" == "arm64e" ]]; then
		./configure -prefix="/tmp/${CURL_VERSION}-iOS-${ARCH}" -disable-shared --enable-static -with-random=/dev/urandom --with-ssl=${OPENSSL}/iOS ${NGHTTP2CFG} --host="arm-apple-darwin" &> "/tmp/${CURL_VERSION}-iOS-${ARCH}.log"
	else
		./configure -prefix="/tmp/${CURL_VERSION}-iOS-${ARCH}" -disable-shared --enable-static -with-random=/dev/urandom --with-ssl=${OPENSSL}/iOS ${NGHTTP2CFG} --host="${ARCH}-apple-darwin" &> "/tmp/${CURL_VERSION}-iOS-${ARCH}.log"
	fi

	make -j8 >> "/tmp/${CURL_VERSION}-iOS-${ARCH}.log" 2>&1
	make install >> "/tmp/${CURL_VERSION}-iOS-${ARCH}.log" 2>&1
	make clean >> "/tmp/${CURL_VERSION}-iOS-${ARCH}.log" 2>&1
	popd > /dev/null
}

echo "Cleaning up"
rm -rf include/curl/* lib/*

mkdir -p iOS/lib
mkdir -p iOS/include/curl/

rm -rf "/tmp/${CURL_VERSION}-*"
rm -rf "/tmp/${CURL_VERSION}-*.log"

rm -rf "${CURL_VERSION}"

if [ ! -e ${CURL_VERSION}.tar.gz ]; then
	echo "Downloading ${CURL_VERSION}.tar.gz"
	curl -LO https://curl.haxx.se/download/${CURL_VERSION}.tar.gz
else
	echo "Using ${CURL_VERSION}.tar.gz"
fi

echo "Unpacking curl"
tar xfz "${CURL_VERSION}.tar.gz"

isCopy=0;
count=0;

echo "Building iOS ${archs} libraries ${echo_bit}"

libcurlPath=""

for arch in $archs
do
	buildIOS "${arch}"
	if [ "$isCopy" == "0" ];then
		echo "   Copying headers "
		cp /tmp/${CURL_VERSION}-iOS-${arch}/include/curl/* iOS/include/curl/
		isCopy=1;
	fi
	count=`expr $count + 1`;
	libcurlPath="$libcurlPath /tmp/${CURL_VERSION}-iOS-${arch}/lib/libcurl.a"
done

if [ $count == 1 ];then
	cp libcurlPath iOS/lib/libcurl.a
else
	lipo -create ${libcurlPath}  -output iOS/lib/libcurl.a
fi

echo "Cleaning up"
rm -rf /tmp/${CURL_VERSION}-*
rm -rf ${CURL_VERSION}

#reset trap
trap - INT TERM EXIT

echo "Done"