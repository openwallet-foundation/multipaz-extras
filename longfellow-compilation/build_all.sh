#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SOURCE_DIR="${SCRIPT_DIR}/source/openssl"
OUTPUT_DIR="${SCRIPT_DIR}/output/"
cd "$SCRIPT_DIR"

export PATH=~/homebrew/Cellar/x86_64-unknown-linux-gnu/13.3.0/bin:$PATH
export PATH=~/homebrew/Cellar/aarch64-unknown-linux-gnu/13.3.0/bin:$PATH
export ANDROID_NDK_ROOT=~/Library/Android/sdk/ndk/27.0.12077973

build_openssl() {
    rm -rf "$OUTPUT_DIR/openssl"
    mkdir -p "$OUTPUT_DIR/openssl"
    ./build_openssl.sh linux
    ./build_openssl.sh macos
    #./build_openssl.sh ios
    ./build_openssl.sh android
}

build_zstd() {
    rm -rf "$OUTPUT_DIR/zstd"
    mkdir -p "$OUTPUT_DIR/zstd"
    ./build_zstd.sh linux
    ./build_zstd.sh macos
    #./build_zstd.sh ios
    ./build_zstd.sh android
}

build_googletest() {
    rm -rf "$OUTPUT_DIR/googletest"
    mkdir -p "$OUTPUT_DIR/googletest"
    ./build_googletest.sh linux
    ./build_googletest.sh macos
    #./build_googletest.sh ios
    ./build_googletest.sh android
}

build_benchmark() {
    rm -rf "$OUTPUT_DIR/benchmark"
    mkdir -p "$OUTPUT_DIR/benchmark"
    ./build_benchmark.sh linux
    ./build_benchmark.sh macos
    #./build_benchmark.sh ios
    ./build_benchmark.sh android
}

build_longfellow() {
    rm -rf "$OUTPUT_DIR/longfellow"
    mkdir -p "$OUTPUT_DIR/longfellow"
    ./build_longfellow.sh linux
    ./build_longfellow.sh macos
    #./build_longfellow.sh ios
    ./build_longfellow.sh android
}

build_longfellow_jni() {
    rm -rf "$OUTPUT_DIR/longfellow_jni"
    mkdir -p "$OUTPUT_DIR/longfellow_jni"
    ./build_longfellow_jni.sh linux
    ./build_longfellow_jni.sh macos
    ./build_longfellow_jni.sh android
}

build_openssl
build_zstd
build_googletest
build_benchmark
build_longfellow
build_longfellow_jni

