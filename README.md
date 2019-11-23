# Build-OpenSSL-cURL

openssl: 1.1.1d  
curl: 7.66.0 

由于某些原因curl禁用`--disable-ldap --disable-ldaps --without-zlib`，如果需要使用请自行注释掉  

## Android

__注:__  
1. 需要指定NDK的路径，测试版本为NDK16B，其他的NDK版本需要自行测试;    
2. 由于某些原因目前指定的android_api 版本为14，如果需要其他版本请自行修改;  
3. curl使用了NDK生成toolchain的方式编译

注：__暂不支持HTTP2__   
eg：`./build.sh ~/Library/Developer/Android/ndk/android-ndk-r16b`

## iOS

Copy from https://github.com/jasonacox/Build-OpenSSL-CURL  

如果不支持「HTTP2」请使用参数`-disable-http2`  
eg：`./build.sh -disable-http2`