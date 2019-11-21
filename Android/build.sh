#!/bin/bash

OPENSSL="1.1.1d"	# https://www.openssl.org/source/
LIBCURL="7.66.0"	# https://curl.haxx.se/download.html

archs="armeabi-v7a arm64-v8a x86 x86_64"
# archs="armeabi-v7a"

if [ "$1" == "" ]; then
    echo "need configure NDK_ROOT"
    exit
else
    NDK_PATH="$1"
    echo $NDK_PATH
fi

creatToolschain()
{
    ARCH=$1
    if [ "$ARCH" == "armeabi-v7a" ]; then
		arch_tag="arm"
	elif [ "$ARCH" == "arm64-v8a" ]; then
		arch_tag="arm64"
	elif [ "$ARCH" == "x86" ]; then
		arch_tag="x86"
	else
		arch_tag="x86_64"
	fi
    $NDK_PATH/build/tools/make_standalone_toolchain.py \
        --arch $arch_tag \
        --api 21 \
        --install-dir toolschain/$ARCH
}

if [ ! -d "toolschain" ];then
    mkdir toolschain
    for arch in $archs
    do
        creatToolschain $arch
    done
fi

# echo
# echo "Building OpenSSL"
# cd openssl 
# ./openssl_build.sh "$OPENSSL" "$archs" "$NDK_PATH"
# cd ..

# echo
# echo "Building Curl"
# cd curl
# ./libcurl_build.sh "$LIBCURL" "$archs" ${NDK_PATH}
# cd ..

echo "     create archive"
ARCHIVE="archive/libcurl-$LIBCURL-openssl-$OPENSSL"
mkdir -p "$ARCHIVE"
mkdir -p "$ARCHIVE/include/openssl"
mkdir -p "$ARCHIVE/include/curl"
mkdir -p "$ARCHIVE/lib"

isCopy=false;
for arch in $archs
do
	if [ $isCopy == false ];then
        echo "     Copying header"
        cp openssl/build/${arch}/usr/include/openssl/* "$ARCHIVE/include/openssl"
        cp curl/build/${arch}/usr/include/curl/* "$ARCHIVE/include/curl"
        isCopy=true;
    fi
    mkdir -p "$ARCHIVE/lib/$arch"
    cp curl/build/${arch}/usr/lib/libcurl.a $ARCHIVE/lib/$arch/libcurl.a
    cp openssl/build/${arch}/usr/lib/libcrypto.a $ARCHIVE/lib/$arch/libcrypto.a
    cp openssl/build/${arch}/usr/lib/libssl.a $ARCHIVE/lib/$arch/libssl.a
done