#!/bin/bash

cp output/longfellow-jni/android/arm64-v8a/lib/libzkp.so \
   ../../multipaz/multipaz-longfellow/src/androidMain/jniLibs/arm64-v8a/

cp output/longfellow-jni/linux/x86_64/lib/libzkp.so \
   ../../multipaz/multipaz-longfellow/src/jvmMain/resources/nativeLibs/linux-x86_64/

cp output/longfellow-jni/macos/arm64/lib/libzkp.dylib \
   ../../multipaz/multipaz-longfellow/src/jvmMain/resources/nativeLibs/macos-arm64/


