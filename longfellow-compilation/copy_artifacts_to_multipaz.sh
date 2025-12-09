#!/bin/bash

cp output/longfellow-jni/android/arm64-v8a/lib/libzkp.so \
   ../../multipaz/multipaz-longfellow/src/androidMain/jniLibs/arm64-v8a/

cp output/longfellow-jni/linux/x86_64/lib/libzkp.so \
   ../../multipaz/multipaz-longfellow/src/jvmMain/resources/nativeLibs/linux-x86_64/

cp output/longfellow-jni/macos/arm64/lib/libzkp.dylib \
   ../../multipaz/multipaz-longfellow/src/jvmMain/resources/nativeLibs/macos-arm64/

mkdir -p ../../multipaz/multipaz-longfellow/src/iosMain/nativeLibs
cp -R output/longfellow-zk/ios/ \
    ../../multipaz/multipaz-longfellow/src/iosMain/nativeLibs

# Also copy libzstd.a which for some reason isn't statically linked into libmdoc_static.a
#
cp output/zstd/ios/arm64-iphoneos/lib/libzstd.a \
    ../../multipaz/multipaz-longfellow/src/iosMain/nativeLibs/arm64-iphoneos/lib
cp output/zstd/ios/arm64-iphonesimulator/lib/libzstd.a \
    ../../multipaz/multipaz-longfellow/src/iosMain/nativeLibs/arm64-iphonesimulator/lib
cp output/zstd/ios/x86_64-iphonesimulator/lib/libzstd.a \
    ../../multipaz/multipaz-longfellow/src/iosMain/nativeLibs/x86_64-iphonesimulator/lib
