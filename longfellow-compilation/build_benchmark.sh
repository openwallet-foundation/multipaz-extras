#!/bin/bash

#
# build_benchmark.sh
#
# This is a universal script to build the Google Benchmark library for
# iOS, Android, macOS, and Linux. It creates static libraries.
#
# Usage:
#   ./build_benchmark.sh <platform>
#
# Supported Platforms:
#   ios
#   android
#   macos
#   linux
#
# Prerequisites:
#   - General: cmake, git, and ninja (or make) must be installed.
#   - For Android: Android NDK must be installed and 'ANDROID_NDK_ROOT' must be set.
#   - For iOS/macOS: Xcode Command Line Tools must be installed.
#   - For Linux: A C/C++ compiler (like gcc/g++) and make are required. For cross-compiling
#     (e.g., arm64 on an x86_64 host), a toolchain like 'gcc-aarch64-linux-gnu'
#     must be installed (e.g., via 'sudo apt-get install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu').
#

# --- Configuration ---
set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # Return value of a pipeline is the value of the last command to exit with a non-zero status
set -x

BENCHMARK_VERSION="v1.8.3" # Use a specific git tag from the benchmark repository
ANDROID_API_LEVEL=21
MIN_IOS_SDK_VERSION="13.0"

# --- Script Setup ---
TARGET_PLATFORM=$1
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SOURCE_DIR="${SCRIPT_DIR}/source/benchmark"
OUTPUT_DIR="${SCRIPT_DIR}/output/benchmark/${TARGET_PLATFORM}"
BUILD_DIR="${SCRIPT_DIR}/build/benchmark/${TARGET_PLATFORM}"

# --- Helper Functions ---
log() {
    echo ""
    echo "================================================================="
    echo "=> $1"
    echo "================================================================="
    echo ""
}

clone_benchmark() {
    if [ ! -d "${SOURCE_DIR}" ]; then
        log "Cloning Google Benchmark source code (version ${BENCHMARK_VERSION})..."
        git clone --depth 1 --branch ${BENCHMARK_VERSION} https://github.com/google/benchmark.git "${SOURCE_DIR}"
    else
        log "Google Benchmark source directory found. Checking out version ${BENCHMARK_VERSION}..."
        cd "${SOURCE_DIR}"
        git fetch --all --tags
        git checkout ${BENCHMARK_VERSION}
        cd "${SCRIPT_DIR}"
    fi
}

# --- Platform Build Functions ---

##
# iOS Build Function
##
build_ios() {
    log "Starting Google Benchmark iOS build..."

    build_ios_arch() {
        local ARCH=$1
        local PLATFORM=$2
        local SDKROOT=$(xcrun --sdk ${PLATFORM} --show-sdk-path)
        local CMAKE_BUILD_DIR="${BUILD_DIR}/${ARCH}-${PLATFORM}"
        local INSTALL_DIR="${BUILD_DIR}/install/${ARCH}-${PLATFORM}"
        mkdir -p "${CMAKE_BUILD_DIR}"

        log "Building Google Benchmark for iOS: ${PLATFORM} (${ARCH})"

        cmake -S "${SOURCE_DIR}" -B "${CMAKE_BUILD_DIR}" -G "Unix Makefiles" \
            -DCMAKE_SYSTEM_NAME=iOS \
            -DCMAKE_OSX_ARCHITECTURES=${ARCH} \
            -DCMAKE_OSX_SYSROOT=${SDKROOT} \
            -DCMAKE_OSX_DEPLOYMENT_TARGET=${MIN_IOS_SDK_VERSION} \
            -DBENCHMARK_ENABLE_TESTING=OFF \
            -DBENCHMARK_ENABLE_GTEST_TESTS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"

        make -C "${CMAKE_BUILD_DIR}" -j
        make -C "${CMAKE_BUILD_DIR}" install

        # Copy final libs and headers to output
        mkdir -p "${OUTPUT_DIR}/${ARCH}-${PLATFORM}/lib"
        cp -r "${INSTALL_DIR}/lib"/* "${OUTPUT_DIR}/${ARCH}-${PLATFORM}/lib/"
        cp -r "${INSTALL_DIR}/include" "${OUTPUT_DIR}/${ARCH}-${PLATFORM}/"
    }

    build_ios_arch "arm64" "iphoneos"
    build_ios_arch "x86_64" "iphonesimulator"
    build_ios_arch "arm64" "iphonesimulator" # For Apple Silicon simulators

    #log "Creating combined library and header output for iOS..."
    #mkdir -p "${OUTPUT_DIR}/lib" "${OUTPUT_DIR}/include"
    #cp -r "${BUILD_DIR}/install/arm64-iphoneos/include/"* "${OUTPUT_DIR}/include/"

    # Create fat libraries for each benchmark component
    #lipo -create \
    #    "${BUILD_DIR}/install/arm64-iphoneos/lib/libbenchmark.a" \
    #    "${BUILD_DIR}/install/x86_64-iphonesimulator/lib/libbenchmark.a" \
    #    "${BUILD_DIR}/install/arm64-iphonesimulator/lib/libbenchmark.a" \
    #    -output "${OUTPUT_DIR}/lib/libbenchmark.a"
    #lipo -create \
    #    "${BUILD_DIR}/install/arm64-iphoneos/lib/libbenchmark_main.a" \
    #    "${BUILD_DIR}/install/x86_64-iphonesimulator/lib/libbenchmark_main.a" \
    #    "${BUILD_DIR}/install/arm64-iphonesimulator/lib/libbenchmark_main.a" \
    #    -output "${OUTPUT_DIR}/lib/libbenchmark_main.a"
}

##
# Android Build Function
##
build_android() {
    log "Starting Google Benchmark Android build..."

    if [ -z "$ANDROID_NDK_ROOT" ] || [ ! -d "$ANDROID_NDK_ROOT" ]; then
        echo "Error: ANDROID_NDK_ROOT is not set or is not a valid directory."
        exit 1
    fi

    build_android_arch() {
        local ARCH_NAME=$1
        local CMAKE_BUILD_DIR="${BUILD_DIR}/${ARCH_NAME}"
        local INSTALL_DIR="${OUTPUT_DIR}/${ARCH_NAME}"
        local TOOLCHAIN_FILE="${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake"

        log "Building Google Benchmark for Android: ${ARCH_NAME}"
        mkdir -p "${CMAKE_BUILD_DIR}"

        cmake -S "${SOURCE_DIR}" -B "${CMAKE_BUILD_DIR}" \
            -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_FILE} \
            -DANDROID_ABI=${ARCH_NAME} \
            -DANDROID_PLATFORM=android-${ANDROID_API_LEVEL} \
            -DANDROID_STL=c++_static \
            -DBENCHMARK_ENABLE_TESTING=OFF \
            -DBENCHMARK_ENABLE_GTEST_TESTS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"

        cmake --build "${CMAKE_BUILD_DIR}"
        cmake --install "${CMAKE_BUILD_DIR}"
    }

    build_android_arch "arm64-v8a"
    build_android_arch "armeabi-v7a"
    #build_android_arch "x86_64"
    #build_android_arch "x86"
}

##
# macOS Build Function
##
build_macos() {
    log "Starting Google Benchmark macOS build..."

    build_macos_arch() {
        local ARCH=$1
        local CMAKE_BUILD_DIR="${BUILD_DIR}/${ARCH}"
        local INSTALL_DIR="${BUILD_DIR}/install/${ARCH}"
        mkdir -p "${CMAKE_BUILD_DIR}"

        log "Building Google Benchmark for macOS: ${ARCH}"
        local SDKROOT=$(xcrun --sdk macosx --show-sdk-path)

        cmake -S "${SOURCE_DIR}" -B "${CMAKE_BUILD_DIR}" -G "Unix Makefiles" \
            -DCMAKE_OSX_ARCHITECTURES=${ARCH} \
            -DCMAKE_OSX_SYSROOT=${SDKROOT} \
            -DBENCHMARK_ENABLE_TESTING=OFF \
            -DBENCHMARK_ENABLE_GTEST_TESTS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"

        make -C "${CMAKE_BUILD_DIR}" -j
        make -C "${CMAKE_BUILD_DIR}" install

        # Copy final libs and headers to output
        mkdir -p "${OUTPUT_DIR}/${ARCH}/lib"
        cp -r "${INSTALL_DIR}/lib"/* "${OUTPUT_DIR}/${ARCH}/lib/"
        cp -r "${INSTALL_DIR}/include" "${OUTPUT_DIR}/${ARCH}/"
    }

    #build_macos_arch "x86_64"
    build_macos_arch "arm64"

    #log "Creating combined library and header output for macOS..."
    #mkdir -p "${OUTPUT_DIR}/lib" "${OUTPUT_DIR}/include"
    #cp -r "${BUILD_DIR}/install/arm64/include/"* "${OUTPUT_DIR}/include/"

    # Create universal "fat" libraries
    #lipo -create "${BUILD_DIR}/install/x86_64/lib/libbenchmark.a" "${BUILD_DIR}/install/arm64/lib/libbenchmark.a" -output "${OUTPUT_DIR}/lib/libbenchmark.a"
    #lipo -create "${BUILD_DIR}/install/x86_64/lib/libbenchmark_main.a" "${BUILD_DIR}/install/arm64/lib/libbenchmark_main.a" -output "${OUTPUT_DIR}/lib/libbenchmark_main.a"
}

##
# Linux Build Function
##
build_linux() {
    log "Starting Google Benchmark Linux build..."

    build_linux_arch() {
        local ARCH=$1
        local CMAKE_BUILD_DIR="${BUILD_DIR}/${ARCH}"
        local INSTALL_DIR="${OUTPUT_DIR}/${ARCH}"
        local CMAKE_EXTRA_FLAGS=""

        log "Building Google Benchmark for Linux: ${ARCH}"
        mkdir -p "${CMAKE_BUILD_DIR}"

        if [ "$(uname -m)" != "$ARCH" ]; then
            log "Cross-compiling for ${ARCH}..."
            if [ "$ARCH" = "arm64" ]; then
                CMAKE_EXTRA_FLAGS="-DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++"
            elif [ "$ARCH" = "x86_64" ]; then
                CMAKE_EXTRA_FLAGS="-DCMAKE_C_COMPILER=x86_64-linux-gnu-gcc -DCMAKE_CXX_COMPILER=x86_64-linux-gnu-g++"
            fi
        fi

        cmake -S "${SOURCE_DIR}" -B "${CMAKE_BUILD_DIR}" -G "Unix Makefiles" \
            -DCMAKE_BUILD_TYPE=Release \
            -DBENCHMARK_ENABLE_TESTING=OFF \
            -DBENCHMARK_ENABLE_GTEST_TESTS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
	    -DCMAKE_SYSTEM_NAME=Linux \
            ${CMAKE_EXTRA_FLAGS}

        make -C "${CMAKE_BUILD_DIR}" -j
        make -C "${CMAKE_BUILD_DIR}" install
    }

    build_linux_arch "x86_64"
    #build_linux_arch "arm64"
}

# --- Main Execution ---
if [ -z "$TARGET_PLATFORM" ]; then
    echo "Error: No platform specified."
    echo "Usage: $0 <ios|android|macos|linux>"
    exit 1
fi

clone_benchmark

# Clean and create directories
rm -rf "${BUILD_DIR}" "${OUTPUT_DIR}"
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"

case $TARGET_PLATFORM in
    ios)
        build_ios
        ;;
    android)
        build_android
        ;;
    macos)
        build_macos
        ;;
    linux)
        build_linux
        ;;
    *)
        echo "Error: Unsupported platform '$TARGET_PLATFORM'."
        echo "Supported platforms are: ios, android, macos, linux"
        exit 1
        ;;
esac

log "Cleaning up intermediate build directory..."
rm -rf "${BUILD_DIR}"

log "Build for ${TARGET_PLATFORM} complete. Output is in '${OUTPUT_DIR}'"

