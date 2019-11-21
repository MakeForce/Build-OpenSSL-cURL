# Build-OpenSSL-cURL
Copy from https://github.com/jasonacox/Build-OpenSSL-  

由于某些原因curl禁用`--disable-ldap --disable-ldaps --without-zlib`，如果需要使用请自行注释掉  


## Android

需要指定NDK的路径，测试版本为NDK16B，其他的NDK版本为测试  
注：__暂不支持HTTP2__   
eg：`./build.sh ~/Library/Developer/Android/ndk/android-ndk-r16b`

## iOS

如果不支持「HTTP2」请使用参数`-disable-http2`  
eg：`./build.sh -disable-http2`