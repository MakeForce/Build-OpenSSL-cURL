#!/bin/bash
# This script downlaods and builds the Mac, iOS and tvOS openSSL libraries with Bitcode enabled

# Credits:
#
# Stefan Arentz
#   https://github.com/st3fan/ios-openssl
# Felix Schulze
#   https://github.com/x2on/OpenSSL-for-iPhone/blob/master/build-libssl.sh
# James Moore
#   https://gist.github.com/foozmeat/5154962
# Peter Steinberger, PSPDFKit GmbH, @steipete.
#   https://gist.github.com/felix-schwarz/c61c0f7d9ab60f53ebb0
# Jason Cox, @jasonacox
#   https://github.com/jasonacox/Build-OpenSSL-cURL

set -e

# set trap to help debug build errors
trap 'echo "** ERROR with Build - Check /tmp/openssl*.log"; tail /tmp/openssl*.log' INT TERM EXIT

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
	OPENSSL_VERSION="openssl-1.1.1d"
else
	OPENSSL_VERSION="openssl-$1"
fi

if [ -z "$2" ]; then
    archs="armv7 armv7s arm64 arm64e i386 x86_64"
else
    archs="$2"
fi

if [ -z "$3" ]; then
	bitcode="-fembed-bitcode"
	bitcode_flag="DSO_LDFLAGS=-fembed-bitcode"
	echo_bit="bitcode"
else
    bitcode=""
	bitcode_flag=""
	echo_bit="nobitcode"
	if [ "$3" == "bitcode" ];then
		bitcode="-fembed-bitcode"
		bitcode_flag="DSO_LDFLAGS=-fembed-bitcode"
		echo_bit="bitcode"
	fi
fi

IOS_SDK_VERSION=""
IOS_MIN_SDK_VERSION="7.1"

DEVELOPER=`xcode-select -print-path`

buildIOS()
{
	ARCH=$1

	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"

	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
		#sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
	fi

	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc ${bitcode} -arch ${ARCH}"

	echo "Building ${OPENSSL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"

	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		TARGET="darwin-i386-cc"
		if [[ $ARCH == "x86_64" ]]; then
			TARGET="darwin64-x86_64-cc"
		fi
		if [[ "$OPENSSL_VERSION" = "openssl-1.1.1"* ]]; then
			./Configure no-asm ${TARGET} -no-shared --prefix="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" --openssldir="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" &> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log"
		else
			./Configure no-asm ${TARGET} -no-shared --openssldir="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" &> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log"
		fi
	else
		if [[ "$OPENSSL_VERSION" = "openssl-1.1.1"* ]]; then
			# export CC="${BUILD_TOOLS}/usr/bin/gcc -arch ${ARCH}"
			./Configure iphoneos-cross ${bitcode_flag} --prefix="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" -no-shared --openssldir="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" &> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log"
		else
			./Configure iphoneos-cross -no-shared --openssldir="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" &> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log"
		fi
	fi
	# add -isysroot to CC=
	if [[ "$OPENSSL_VERSION" = "openssl-1.1.1"* ]]; then
		sed -ie "s!^CFLAGS=!CFLAGS=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} !" "Makefile"
	else
		sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} !" "Makefile"
	fi

	make -j8 >> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
	make install_sw >> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
	make clean >> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
	popd > /dev/null
}

echo "Cleaning up"
rm -rf include/openssl/* lib/*

mkdir -p iOS/lib
mkdir -p iOS/include/openssl/

rm -rf "/tmp/${OPENSSL_VERSION}-*"
rm -rf "/tmp/${OPENSSL_VERSION}-*.log"

rm -rf "${OPENSSL_VERSION}"

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

isCopy=0;
count=0;

echo "Building iOS ${archs} libraries ${echo_bit}"

libsslPath=""
libcryptoPath=""
for arch in $archs
do
	buildIOS "${arch}"
	if [ "$isCopy" == "0" ];then
		echo "   Copying headers"
		cp /tmp/${OPENSSL_VERSION}-iOS-${arch}/include/openssl/* iOS/include/openssl/
		isCopy=1;
	fi
	count=`expr $count + 1`;
	libsslPath="$libsslPath /tmp/${OPENSSL_VERSION}-iOS-${arch}/lib/libssl.a"
	libcryptoPath="$libcryptoPath /tmp/${OPENSSL_VERSION}-iOS-${arch}/lib/libcrypto.a"
done

if [ $count == 1 ];then
	cp $libsslPath iOS/lib/libssl.a
	cp $libcryptoPath iOS/lib/libcrypto.a
else
	lipo -create ${libsslPath}  -output iOS/lib/libssl.a
	lipo -create ${libcryptoPath}  -output iOS/lib/libcrypto.a
fi

echo "Cleaning up"

rm -rf /tmp/${OPENSSL_VERSION}-*
rm -rf ${OPENSSL_VERSION}

#reset trap
trap - INT TERM EXIT

echo "Done"