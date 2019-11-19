#!/bin/bash

OPENSSL="1.1.1d"	# https://www.openssl.org/source/
LIBCURL="7.66.0"	# https://curl.haxx.se/download.html

# archs="armeabi armeabi-v7a arm64-v8a x86 x86_64"
archs="arm64-v8a x86 x86_64"

if [ "$1" == "" ]; then
    echo "need configure NDK_ROOT"
    exit
else
    NDK_PATH="$1"
    echo $NDK_PATH
fi

echo
echo "Building OpenSSL"
cd openssl 
./openssl_build.sh "$OPENSSL" "$archs" "$NDK_PATH"
cd ..

echo
echo "Building Curl"
cd curl
./libcurl_build.sh "$LIBCURL" "$archs" ${NDK_PATH}
cd ..