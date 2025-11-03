#!/bin/bash

#
# build_zstd.sh
#
# This is a universal script to build the Zstandard (zstd) library for
# iOS, Android, macOS, and Linux. It creates static libraries and, where
# appropriate, XCFrameworks.
#
# Usage:
#   ./build_zstd.sh <platform>
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
#   - For Linux: A C compiler (like gcc) and make are required. For cross-compiling
#     (e.g., arm64 on an x86_64 host), a toolchain like 'gcc-aarch64-linux-gnu'
#     must be installed (e.g., via 'sudo apt-get install gcc-aarch64-linux-gnu').
#

# --- Configuration ---
set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # Return value of a pipeline is the value of the last command to exit with a non-zero status
set -x

ZSTD_VERSION="v1.5.6" # Use a specific git tag from the zstd repository
ANDROID_API_LEVEL=21
MIN_IOS_SDK_VERSION="13.0"

# --- Script Setup ---
TARGET_PLATFORM=$1
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SOURCE_DIR="${SCRIPT_DIR}/source/zstd"
OUTPUT_DIR="${SCRIPT_DIR}/output/zstd/${TARGET_PLATFORM}"
BUILD_DIR="${SCRIPT_DIR}/build/zstd/${TARGET_PLATFORM}"

# --- Helper Functions ---
log() {
    echo ""
    echo "================================================================="
    echo "=> $1"
    echo "================================================================="
    echo ""
}

clone_zstd() {
    if [ ! -d "${SOURCE_DIR}" ]; then
        log "Cloning Zstandard source code (version ${ZSTD_VERSION})..."
        git clone --depth 1 --branch ${ZSTD_VERSION} https://github.com/facebook/zstd.git "${SOURCE_DIR}"
    else
        log "Zstandard source directory found. Checking out version ${ZSTD_VERSION}..."
        cd "${SOURCE_DIR}"
        git fetch --all --tags
        git checkout ${ZSTD_VERSION}
        cd ..
    fi
}

# --- Platform Build Functions ---

##
# iOS Build Function
##
build_ios() {
    log "Starting zstd iOS build..."

    build_ios_arch() {
        local ARCH=$1
        local PLATFORM=$2
        local SDKROOT=$(xcrun --sdk ${PLATFORM} --show-sdk-path)
        local CMAKE_BUILD_DIR="${BUILD_DIR}/zstd/${ARCH}-${PLATFORM}"
        local INSTALL_DIR="${BUILD_DIR}/install/${ARCH}-${PLATFORM}"
        mkdir -p "${CMAKE_BUILD_DIR}"

        log "Building zstd for iOS: ${PLATFORM} (${ARCH})"

        cmake -S "${SOURCE_DIR}/build/cmake" -B "${CMAKE_BUILD_DIR}" -G "Unix Makefiles" \
            -DIOS_PLATFORM=${PLATFORM} \
            -DCMAKE_OSX_ARCHITECTURES=${ARCH} \
            -DCMAKE_OSX_SYSROOT=${SDKROOT} \
            -DCMAKE_OSX_DEPLOYMENT_TARGET=${MIN_IOS_SDK_VERSION} \
            -DZSTD_BUILD_STATIC=ON \
            -DZSTD_BUILD_SHARED=OFF \
            -DZSTD_BUILD_PROGRAMS=OFF \
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
    build_ios_arch "arm64" "iphonesimulator"

    #log "Creating libzstd.xcframework for iOS..."
    #xcodebuild -create-xcframework \
    #    -library "${BUILD_DIR}/install/arm64-OS/lib/libzstd.a" -headers "${BUILD_DIR}/install/arm64-OS/include" \
    #    -library "${BUILD_DIR}/install/x86_64-SIMULATOR/lib/libzstd.a" -headers "${BUILD_DIR}/install/x86_64-SIMULATOR/include" \
    #    -library "${BUILD_DIR}/install/arm64-SIMULATOR64/lib/libzstd.a" -headers "${BUILD_DIR}/install/arm64-SIMULATOR64/include" \
    #    -output "${OUTPUT_DIR}/libzstd.xcframework"
}

##
# Android Build Function
##
build_android() {
    log "Starting zstd Android build..."

    if [ -z "$ANDROID_NDK_ROOT" ] || [ ! -d "$ANDROID_NDK_ROOT" ]; then
        echo "Error: ANDROID_NDK_ROOT is not set or is not a valid directory."
        exit 1
    fi

    build_android_arch() {
        local ARCH_NAME=$1
        local CMAKE_BUILD_DIR="${BUILD_DIR}/${ARCH_NAME}"
        local INSTALL_DIR="${OUTPUT_DIR}/${ARCH_NAME}"
        local TOOLCHAIN_FILE="${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake"

        log "Building zstd for Android: ${ARCH_NAME}"
        mkdir -p "${CMAKE_BUILD_DIR}"

        cmake -S "${SOURCE_DIR}/build/cmake" -B "${CMAKE_BUILD_DIR}" \
            -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_FILE} \
            -DANDROID_ABI=${ARCH_NAME} \
            -DANDROID_PLATFORM=android-${ANDROID_API_LEVEL} \
            -DANDROID_STL=c++_static \
            -DZSTD_BUILD_STATIC=ON \
            -DZSTD_BUILD_SHARED=OFF \
            -DZSTD_BUILD_PROGRAMS=OFF \
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
    log "Starting zstd macOS build..."

    build_macos_arch() {
        local ARCH=$1
        local CMAKE_BUILD_DIR="${BUILD_DIR}/${ARCH}"
        local INSTALL_DIR="${BUILD_DIR}/install/${ARCH}"
        mkdir -p "${CMAKE_BUILD_DIR}"

        log "Building zstd for macOS: ${ARCH}"
        local SDKROOT=$(xcrun --sdk macosx --show-sdk-path)

        cmake -S "${SOURCE_DIR}/build/cmake" -B "${CMAKE_BUILD_DIR}" -G "Unix Makefiles" \
            -DCMAKE_OSX_ARCHITECTURES=${ARCH} \
            -DCMAKE_OSX_SYSROOT=${SDKROOT} \
            -DZSTD_BUILD_STATIC=ON \
            -DZSTD_BUILD_SHARED=OFF \
            -DZSTD_BUILD_PROGRAMS=OFF \
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

    #log "Creating libzstd.xcframework for macOS..."
    #xcodebuild -create-xcframework \
    #    -library "${BUILD_DIR}/install/x86_64/lib/libzstd.a" -headers "${BUILD_DIR}/install/x86_64/include" \
    #    -library "${BUILD_DIR}/install/arm64/lib/libzstd.a" -headers "${BUILD_DIR}/install/arm64/include" \
    #    -output "${OUTPUT_DIR}/libzstd.xcframework"
}

##
# Linux Build Function
##
build_linux() {
    log "Starting zstd Linux build for x86_64 and arm64..."

    build_linux_arch() {
        local ARCH=$1
        local CMAKE_BUILD_DIR="${BUILD_DIR}/${ARCH}"
        local INSTALL_DIR="${OUTPUT_DIR}/${ARCH}"
        local CMAKE_EXTRA_FLAGS=""

        log "Building zstd for Linux: ${ARCH}"
        mkdir -p "${CMAKE_BUILD_DIR}"

        if [ "$(uname -m)" != "$ARCH" ]; then
            log "Cross-compiling for ${ARCH}..."
            if [ "$ARCH" = "arm64" ]; then
                CMAKE_EXTRA_FLAGS="-DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++"
            elif [ "$ARCH" = "x86_64" ]; then
                CMAKE_EXTRA_FLAGS="-DCMAKE_C_COMPILER=x86_64-linux-gnu-gcc -DCMAKE_CXX_COMPILER=x86_64-linux-gnu-g++"
            fi
        fi

        cmake -S "${SOURCE_DIR}/build/cmake" -B "${CMAKE_BUILD_DIR}" -G "Unix Makefiles" \
            -DZSTD_BUILD_STATIC=ON \
            -DZSTD_BUILD_SHARED=OFF \
            -DZSTD_BUILD_PROGRAMS=OFF \
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

clone_zstd

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
