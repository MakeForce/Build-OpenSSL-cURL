#!/bin/bash

# This script builds openssl+libcurl libraries for the Mac, iOS and tvOS 
#
# Jason Cox, @jasonacox
#   https://github.com/jasonacox/Build-OpenSSL-cURL
#

########################################
# EDIT this section to Select Versions #
########################################

OPENSSL="1.1.1d"	# https://www.openssl.org/source/
LIBCURL="7.66.0"	# https://curl.haxx.se/download.html
NGHTTP2="1.39.2"	# https://nghttp2.org/

########################################

# HTTP2 Support?
NOHTTP2="/tmp/no-http2"
rm -f $NOHTTP2

usage ()
{
        echo "usage: $0 [-disable-http2]"
        exit 127
}

if [ "$1" == "-h" ]; then
        usage
fi

archs="armv7 arm64"
bitcode=""

echo
echo "Building OpenSSL"
cd openssl 
./openssl_build.sh "$OPENSSL" "$archs" $bitcode
cd ..

if [ "$1" == "-disable-http2" ]; then
	touch "$NOHTTP2"
	NGHTTP2="NONE"	
else 
	echo
	echo "Building nghttp2 for HTTP2 support"
	cd nghttp2
	./nghttp2_build.sh "$NGHTTP2" "$archs" $bitcode
	cd ..
fi

echo
echo "Building Curl"
cd curl
./libcurl_build.sh "$LIBCURL" "$archs" $bitcode
cd ..

echo 
echo "Libraries..."
echo
echo "openssl [$OPENSSL]"
xcrun -sdk iphoneos lipo -info openssl/*/lib/*.a
echo
if [ ! "$1" == "-disable-http2" ];then
	echo "nghttp2 (rename to libnghttp2.a) [$NGHTTP2]"
	xcrun -sdk iphoneos lipo -info nghttp2/*/lib/*.a
	echo
fi
echo "libcurl (rename to libcurl.a) [$LIBCURL]"
xcrun -sdk iphoneos lipo -info curl/*/lib/*.a

EXAMPLE="examples/iOS Test App"
ARCHIVE="archive/libcurl-$LIBCURL-openssl-$OPENSSL-nghttp2-$NGHTTP2"

for arch in $archs
do
	ARCHIVE="$ARCHIVE-${arch}"	
done

echo
echo "Creating archive in $ARCHIVE for release v$LIBCURL..."
mkdir -p "$ARCHIVE"
mkdir -p "$ARCHIVE/include/openssl"
mkdir -p "$ARCHIVE/include/curl"
mkdir -p "$ARCHIVE/lib/iOS"

# archive libraries
echo "archive libraries"
cp curl/iOS/lib/libcurl.a $ARCHIVE/lib/iOS/libcurl.a
cp openssl/iOS/lib/libcrypto.a $ARCHIVE/lib/iOS/libcrypto.a
cp openssl/iOS/lib/libssl.a $ARCHIVE/lib/iOS/libssl.a
if [ ! "$1" == "-disable-http2" ];then
	cp nghttp2/iOS/lib/libnghttp2.a $ARCHIVE/lib/iOS/libnghttp2.a
fi

# archive header files
echo "archive header files"
cp openssl/iOS/include/openssl/* "$ARCHIVE/include/openssl"
cp curl/iOS/include/curl/* "$ARCHIVE/include/curl"

# archive root certs
# curl -s https://curl.haxx.se/ca/cacert.pem > $ARCHIVE/cacert.pem
# echo

echo


rm -f $NOHTTP2