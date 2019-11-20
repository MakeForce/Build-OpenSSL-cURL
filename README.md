# Build-OpenSSL-cURL
Copy from https://github.com/jasonacox/Build-OpenSSL-  

由于某些原因curl禁用`--disable-ldap --disable-ldaps --without-zlib`，如果需要使用请自行注释掉  


## Android

需要指定NDK的路径，注意目前只能使用20.0及其以上的版本  
注：__暂不支持HTTP2__   
eg：`./build.sh ~/Library/Developer/Android/ndk/android-ndk-r20`

## iOS

如果不支持「HTTP2」请使用参数`-disable-http2`  
eg：`./build.sh -disable-http2`